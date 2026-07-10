//! Thumbnail generation and caching, following the freedesktop.org
//! "Thumbnail Managing Standard" so the on-disk cache is shared with
//! Nautilus, Dolphin, and other spec-compliant file managers instead of
//! duplicating work they've already done (or vice versa):
//! <https://specifications.freedesktop.org/thumbnail/latest-single/>
//!
//! All functions here do synchronous, potentially slow I/O and image
//! decoding — callers must invoke `get_or_generate` from a blocking-safe
//! context (e.g. `tokio::task::spawn_blocking`), never on a UI thread.

use percent_encoding::{AsciiSet, NON_ALPHANUMERIC};
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

/// Files larger than this are skipped entirely — decoding a huge image just
/// to shrink it to 128px is wasted work. Sized so real-world 4K wallpaper
/// PNGs (~20-25MB) still qualify; the pixel-count guard below is what
/// actually bounds decode memory, this only rules out absurd outliers.
const MAX_SOURCE_BYTES: u64 = 50 * 1024 * 1024;

/// A second, pixel-count-based guard on top of the byte-size cutoff above —
/// a small but highly-compressed file (e.g. a solid-color 10000x10000 PNG)
/// can still decode to hundreds of megabytes of raw RGBA. 24MP comfortably
/// covers typical phone/camera photos while capping a single decode's
/// worst-case buffer at under ~100MB.
const MAX_SOURCE_PIXELS: u64 = 24_000_000;

/// Matches the freedesktop spec's "normal" size tier — the only tier this
/// app needs, since even its largest icon size (the grid view's "large"
/// icon-size-level container) stays well under 128px.
const THUMBNAIL_SIZE: u32 = 128;

/// Subdirectory name under `thumbnails/fail/` — the spec requires
/// namespacing failure markers per-generator so one buggy thumbnailer
/// doesn't poison another's retries.
const APP_NAME: &str = "orbit";

/// RFC 3986 unreserved characters stay literal; everything else (including
/// non-ASCII bytes) is percent-encoded — matching how GLib's
/// `g_filename_to_uri()` builds the URI Nautilus hashes, which is what
/// lets our cache entries land on the same filenames as theirs.
const URI_UNSAFE: &AsciiSet = &NON_ALPHANUMERIC
    .remove(b'-')
    .remove(b'.')
    .remove(b'_')
    .remove(b'~')
    .remove(b'/');

#[derive(Debug, Clone, PartialEq)]
pub enum ThumbnailOutcome {
    Ready(PathBuf),
    Unavailable,
}

#[derive(Debug, Clone)]
pub struct ThumbnailRequest {
    pub source_path: PathBuf,
    pub mime_type: String,
    pub size: u64,
    pub modified: SystemTime,
}

/// The (uri, mtime-in-seconds, md5-cache-key) triple identifying `request`
/// in the cache — shared by the cheap lookup and the full generate paths so
/// they can never disagree about which file they're talking about.
fn request_identity(request: &ThumbnailRequest) -> Option<(String, u64, String)> {
    let uri = file_uri(&request.source_path)?;
    let mtime = request.modified.duration_since(UNIX_EPOCH).ok()?.as_secs();
    let key = cache_key(&uri);
    Some((uri, mtime, key))
}

/// Cache-only probe: returns the path of an existing fresh thumbnail, or
/// `None` without doing any decoding. Cheap enough to run outside whatever
/// concurrency limit gates real generation — this is what lets a folder of
/// already-thumbnailed images render instantly even while a long generation
/// backlog for other files is still being worked through.
///
/// Deliberately skips the size guards that `get_or_generate` applies: those
/// exist to bound *our* decode cost, but a fresh cached thumbnail is usable
/// no matter how big its source is (another tool with laxer limits, e.g.
/// GNOME's thumbnailer, may well have produced it).
pub fn lookup_cached(request: &ThumbnailRequest) -> Option<PathBuf> {
    lookup_cached_in(request, &cache_root()?)
}

pub fn lookup_cached_in(request: &ThumbnailRequest, cache_root: &Path) -> Option<PathBuf> {
    if !is_thumbnailable(&request.mime_type) {
        return None;
    }
    let (uri, mtime, key) = request_identity(request)?;
    let cached = cache_root.join("normal").join(format!("{key}.png"));
    is_fresh(&cached, &uri, mtime).then_some(cached)
}

/// Whether `mime_type` is one this module knows how to thumbnail. Kept
/// public so callers (the QML-facing model) can skip even asking for a
/// thumbnail — e.g. only wiring up the request for entries whose icon key
/// is "image" or "video" in the first place.
pub fn is_thumbnailable(mime_type: &str) -> bool {
    is_image_mime(mime_type) || is_video_mime(mime_type)
}

fn is_image_mime(mime_type: &str) -> bool {
    matches!(
        mime_type,
        "image/png"
            | "image/jpeg"
            | "image/gif"
            | "image/bmp"
            | "image/x-icon"
            | "image/vnd.microsoft.icon"
            | "image/tiff"
            | "image/webp"
            | "image/svg+xml"
    )
}

fn is_video_mime(mime_type: &str) -> bool {
    matches!(
        mime_type,
        "video/mp4"
            | "video/x-matroska"
            | "video/webm"
            | "video/quicktime"
            | "video/x-msvideo"
            | "video/mpeg"
            | "video/ogg"
            | "video/x-m4v"
            | "video/3gpp"
            | "video/x-flv"
            | "video/x-ms-wmv"
    )
}

/// Looks up a cached thumbnail for `request`, generating and caching one if
/// none exists yet (or the cached one is stale). Uses the real
/// `$XDG_CACHE_HOME/thumbnails` directory — see `get_or_generate_in` for the
/// same logic against an arbitrary cache root (used by tests).
pub fn get_or_generate(request: &ThumbnailRequest) -> ThumbnailOutcome {
    match cache_root() {
        Some(root) => get_or_generate_in(request, &root),
        None => ThumbnailOutcome::Unavailable,
    }
}

pub fn get_or_generate_in(request: &ThumbnailRequest, cache_root: &Path) -> ThumbnailOutcome {
    // The byte cap bounds *decode* cost, which for images scales with file
    // size. Extracting one frame from a video doesn't, and videos routinely
    // exceed any sane image cap — so only images are size-gated.
    if !is_thumbnailable(&request.mime_type)
        || (is_image_mime(&request.mime_type) && request.size > MAX_SOURCE_BYTES)
    {
        return ThumbnailOutcome::Unavailable;
    }
    let Some((uri, mtime, key)) = request_identity(request) else {
        return ThumbnailOutcome::Unavailable;
    };

    let normal_dir = cache_root.join("normal");
    let cached = normal_dir.join(format!("{key}.png"));
    if is_fresh(&cached, &uri, mtime) {
        return ThumbnailOutcome::Ready(cached);
    }

    let fail_dir = cache_root.join("fail").join(APP_NAME);
    let failed = fail_dir.join(format!("{key}.png"));
    if is_fresh(&failed, &uri, mtime) {
        return ThumbnailOutcome::Unavailable;
    }

    match render_thumbnail(&request.source_path, &request.mime_type) {
        RenderOutcome::Rendered(rgba) => match write_atomic_png(&normal_dir, &key, &rgba, &uri, mtime) {
            Some(path) => ThumbnailOutcome::Ready(path),
            None => ThumbnailOutcome::Unavailable,
        },
        // No fail marker when the generator itself is absent (ffmpeg not
        // installed): installing it later should make thumbnails appear
        // without requiring every video's mtime to change first.
        RenderOutcome::GeneratorUnavailable => ThumbnailOutcome::Unavailable,
        RenderOutcome::Failed => {
            // 1x1 transparent marker — its presence (with a matching
            // Thumb::MTime) is what "fresh" means for a failure, so a
            // known-broken/unsupported file isn't re-decoded on every scan.
            let marker = RenderedRgba {
                width: 1,
                height: 1,
                pixels: vec![0, 0, 0, 0],
            };
            write_atomic_png(&fail_dir, &key, &marker, &uri, mtime);
            ThumbnailOutcome::Unavailable
        }
    }
}

fn cache_root() -> Option<PathBuf> {
    dirs::cache_dir().map(|dir| dir.join("thumbnails"))
}

/// The file:// URI the spec hashes to name the cache entry.
fn file_uri(path: &Path) -> Option<String> {
    let absolute = if path.is_absolute() {
        path.to_path_buf()
    } else {
        std::env::current_dir().ok()?.join(path)
    };
    let lossy = absolute.to_string_lossy();
    let encoded = percent_encoding::utf8_percent_encode(&lossy, URI_UNSAFE);
    Some(format!("file://{encoded}"))
}

fn cache_key(uri: &str) -> String {
    use md5::{Digest, Md5};
    Md5::digest(uri.as_bytes())
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}

/// A cached (or fail-marker) PNG is fresh when it exists and its embedded
/// `Thumb::URI`/`Thumb::MTime` text chunks match the source file exactly —
/// this is what lets a changed file (same name, newer mtime) invalidate a
/// stale thumbnail instead of showing outdated content forever.
fn is_fresh(png_path: &Path, expected_uri: &str, expected_mtime: u64) -> bool {
    let Ok(file) = std::fs::File::open(png_path) else {
        return false;
    };
    let Ok(reader) = png::Decoder::new(file).read_info() else {
        return false;
    };
    let info = reader.info();
    let mut uri = None;
    let mut mtime = None;
    for chunk in &info.uncompressed_latin1_text {
        match chunk.keyword.as_str() {
            "Thumb::URI" => uri = Some(chunk.text.clone()),
            "Thumb::MTime" => mtime = chunk.text.parse::<u64>().ok(),
            _ => {}
        }
    }
    // GNOME's own thumbnailer (gnome-desktop-thumbnail, the library behind
    // Nautilus) writes Thumb::URI as a compressed zTXt chunk rather than a
    // plain tEXt one — without also checking here, every thumbnail Nautilus
    // (or another zTXt-writing thumbnailer) had already generated looked
    // "stale" to us and got fully redecoded for no reason, even though the
    // cache key matched and a perfectly good thumbnail already existed.
    if uri.is_none() || mtime.is_none() {
        for chunk in &info.compressed_latin1_text {
            let Ok(text) = chunk.get_text() else {
                continue;
            };
            match chunk.keyword.as_str() {
                "Thumb::URI" if uri.is_none() => uri = Some(text),
                "Thumb::MTime" if mtime.is_none() => mtime = text.parse::<u64>().ok(),
                _ => {}
            }
        }
    }
    if uri.is_none() || mtime.is_none() {
        for chunk in &info.utf8_text {
            let Ok(text) = chunk.get_text() else {
                continue;
            };
            match chunk.keyword.as_str() {
                "Thumb::URI" if uri.is_none() => uri = Some(text),
                "Thumb::MTime" if mtime.is_none() => mtime = text.parse::<u64>().ok(),
                _ => {}
            }
        }
    }
    uri.as_deref() == Some(expected_uri) && mtime == Some(expected_mtime)
}

struct RenderedRgba {
    width: u32,
    height: u32,
    /// Straight (non-premultiplied) RGBA8, `width * height * 4` bytes.
    pixels: Vec<u8>,
}

enum RenderOutcome {
    Rendered(RenderedRgba),
    Failed,
    /// The external generator (ffmpeg) isn't installed — distinct from
    /// `Failed` so no fail marker poisons the retry after it's installed.
    GeneratorUnavailable,
}

fn render_thumbnail(path: &Path, mime_type: &str) -> RenderOutcome {
    if is_video_mime(mime_type) {
        return render_video(path);
    }
    let rendered = if mime_type == "image/svg+xml" {
        render_svg(path)
    } else {
        render_raster(path)
    };
    match rendered {
        Some(rgba) => RenderOutcome::Rendered(rgba),
        None => RenderOutcome::Failed,
    }
}

/// One frame from a few seconds in (past intros/black leaders), falling
/// back to the very first frame for clips shorter than the seek point.
fn render_video(path: &Path) -> RenderOutcome {
    let binary = std::env::var("FM_FFMPEG").unwrap_or_else(|_| "ffmpeg".to_string());
    for seek in ["3", "0"] {
        let output = std::process::Command::new(&binary)
            .args(["-v", "error", "-ss", seek, "-i"])
            .arg(path)
            .args(["-frames:v", "1", "-f", "image2pipe", "-c:v", "png", "-"])
            .stdin(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .output();
        let output = match output {
            Ok(output) => output,
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => {
                return RenderOutcome::GeneratorUnavailable;
            }
            Err(_) => return RenderOutcome::Failed,
        };
        if output.stdout.is_empty() {
            continue;
        }
        let Ok(frame) = image::load_from_memory_with_format(&output.stdout, image::ImageFormat::Png)
        else {
            return RenderOutcome::Failed;
        };
        if (frame.width() as u64) * (frame.height() as u64) > MAX_SOURCE_PIXELS {
            return RenderOutcome::Failed;
        }
        let thumbnail = frame.thumbnail(THUMBNAIL_SIZE, THUMBNAIL_SIZE).to_rgba8();
        let (width, height) = thumbnail.dimensions();
        return RenderOutcome::Rendered(RenderedRgba {
            width,
            height,
            pixels: thumbnail.into_raw(),
        });
    }
    RenderOutcome::Failed
}

fn render_raster(path: &Path) -> Option<RenderedRgba> {
    let (width, height) = image::image_dimensions(path).ok()?;
    if (width as u64) * (height as u64) > MAX_SOURCE_PIXELS {
        return None;
    }
    let image = image::ImageReader::open(path).ok()?.decode().ok()?;
    let thumbnail = image.thumbnail(THUMBNAIL_SIZE, THUMBNAIL_SIZE).to_rgba8();
    let (width, height) = thumbnail.dimensions();
    Some(RenderedRgba {
        width,
        height,
        pixels: thumbnail.into_raw(),
    })
}

fn render_svg(path: &Path) -> Option<RenderedRgba> {
    let data = std::fs::read(path).ok()?;
    let tree = resvg::usvg::Tree::from_data(&data, &resvg::usvg::Options::default()).ok()?;
    let size = tree.size();
    let (natural_width, natural_height) = (size.width(), size.height());
    if natural_width <= 0.0 || natural_height <= 0.0 {
        return None;
    }
    // Scale to fit within THUMBNAIL_SIZE on the larger axis, upscaling
    // small icon-sized SVGs (many declare a 16x16 or 24x24 viewBox) up to
    // thumbnail resolution rather than leaving them tiny.
    let scale = (THUMBNAIL_SIZE as f32 / natural_width).min(THUMBNAIL_SIZE as f32 / natural_height);
    let width = (natural_width * scale).round().max(1.0) as u32;
    let height = (natural_height * scale).round().max(1.0) as u32;

    let mut pixmap = resvg::tiny_skia::Pixmap::new(width, height)?;
    resvg::render(
        &tree,
        resvg::tiny_skia::Transform::from_scale(scale, scale),
        &mut pixmap.as_mut(),
    );
    Some(RenderedRgba {
        width,
        height,
        pixels: unpremultiply(pixmap.data().to_vec()),
    })
}

/// tiny-skia stores premultiplied alpha; PNG expects straight alpha —
/// without this, semi-transparent edges (common on icon-style SVGs) come
/// out with a visible dark fringe.
fn unpremultiply(mut rgba: Vec<u8>) -> Vec<u8> {
    for pixel in rgba.chunks_exact_mut(4) {
        let alpha = pixel[3] as u32;
        if alpha != 0 && alpha != 255 {
            for channel in &mut pixel[0..3] {
                *channel = ((*channel as u32 * 255) / alpha) as u8;
            }
        }
    }
    rgba
}

/// Writes `rgba` to `dir/key.png` (creating `dir` if needed) with the
/// Thumb::URI/Thumb::MTime text chunks the spec requires, via a
/// write-to-temp-then-rename so a concurrent reader never observes a
/// partially-written file.
fn write_atomic_png(
    dir: &Path,
    key: &str,
    rgba: &RenderedRgba,
    uri: &str,
    mtime: u64,
) -> Option<PathBuf> {
    std::fs::create_dir_all(dir).ok()?;
    let final_path = dir.join(format!("{key}.png"));
    let tmp_path = dir.join(format!(".{key}.tmp-{}", std::process::id()));

    let result = (|| -> std::io::Result<()> {
        let file = std::fs::File::create(&tmp_path)?;
        let mut encoder = png::Encoder::new(file, rgba.width, rgba.height);
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);
        encoder
            .add_text_chunk("Thumb::URI".to_string(), uri.to_string())
            .map_err(std::io::Error::other)?;
        encoder
            .add_text_chunk("Thumb::MTime".to_string(), mtime.to_string())
            .map_err(std::io::Error::other)?;
        let mut writer = encoder.write_header().map_err(std::io::Error::other)?;
        writer
            .write_image_data(&rgba.pixels)
            .map_err(std::io::Error::other)?;
        Ok(())
    })();

    if result.is_err() {
        let _ = std::fs::remove_file(&tmp_path);
        return None;
    }

    // Thumbnails can reveal the content of files the user might not want
    // world-readable (spec recommendation: mode 0600).
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = std::fs::set_permissions(&tmp_path, std::fs::Permissions::from_mode(0o600));
    }

    std::fs::rename(&tmp_path, &final_path).ok()?;
    Some(final_path)
}
