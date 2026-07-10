use fm_core::thumbnails::{
    get_or_generate_in, is_thumbnailable, lookup_cached_in, ThumbnailOutcome, ThumbnailRequest,
};
use std::time::SystemTime;
use tempfile::tempdir;

fn write_fixture_png(path: &std::path::Path) {
    let image = image::RgbImage::from_pixel(32, 16, image::Rgb([200, 40, 40]));
    image.save(path).unwrap();
}

fn write_fixture_svg(path: &std::path::Path) {
    std::fs::write(
        path,
        br#"<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24">
                <rect width="24" height="24" fill="blue"/>
            </svg>"#,
    )
    .unwrap();
}

#[test]
fn lookup_cached_is_a_pure_probe_that_never_generates() {
    let source_dir = tempdir().unwrap();
    let cache_dir = tempdir().unwrap();
    let source_path = source_dir.path().join("photo.png");
    write_fixture_png(&source_path);

    let request = ThumbnailRequest {
        source_path: source_path.clone(),
        mime_type: "image/png".to_string(),
        size: std::fs::metadata(&source_path).unwrap().len(),
        modified: std::fs::metadata(&source_path).unwrap().modified().unwrap(),
    };

    // Nothing cached yet: the probe must miss AND must not create anything.
    assert_eq!(lookup_cached_in(&request, cache_dir.path()), None);
    assert!(!cache_dir.path().join("normal").exists());

    // After a real generation, the probe finds exactly that file.
    let ThumbnailOutcome::Ready(generated) = get_or_generate_in(&request, cache_dir.path()) else {
        panic!("expected generation to succeed");
    };
    assert_eq!(lookup_cached_in(&request, cache_dir.path()), Some(generated));
}

#[test]
fn recognizes_a_fresh_thumbnail_written_with_a_compressed_ztxt_uri_chunk() {
    // GNOME's own thumbnailer (gnome-desktop-thumbnail, the library behind
    // Nautilus) writes Thumb::URI as a compressed zTXt chunk, not a plain
    // tEXt one. Regression test for a bug where our freshness check only
    // looked at tEXt chunks, so it treated every thumbnail Nautilus (or any
    // other zTXt-writing thumbnailer) had already generated as "missing"
    // and fully redecoded the source image for no reason.
    let source_dir = tempdir().unwrap();
    let cache_dir = tempdir().unwrap();
    let source_path = source_dir.path().join("photo.png");
    write_fixture_png(&source_path);
    let modified = std::fs::metadata(&source_path).unwrap().modified().unwrap();
    let mtime = modified
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();

    let uri = format!("file://{}", source_path.display());
    let key = {
        use md5::{Digest, Md5};
        Md5::digest(uri.as_bytes())
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect::<String>()
    };
    let normal_dir = cache_dir.path().join("normal");
    std::fs::create_dir_all(&normal_dir).unwrap();
    let cached_path = normal_dir.join(format!("{key}.png"));

    let file = std::fs::File::create(&cached_path).unwrap();
    let mut encoder = png::Encoder::new(file, 1, 1);
    encoder.set_color(png::ColorType::Rgba);
    encoder.set_depth(png::BitDepth::Eight);
    encoder
        .add_ztxt_chunk("Thumb::URI".to_string(), uri)
        .unwrap();
    encoder
        .add_text_chunk("Thumb::MTime".to_string(), mtime.to_string())
        .unwrap();
    let mut writer = encoder.write_header().unwrap();
    writer.write_image_data(&[0, 0, 0, 0]).unwrap();
    drop(writer);
    let written_at = std::fs::metadata(&cached_path).unwrap().modified().unwrap();

    let request = ThumbnailRequest {
        source_path,
        mime_type: "image/png".to_string(),
        size: std::fs::metadata(&source_dir.path().join("photo.png"))
            .unwrap()
            .len(),
        modified,
    };

    std::thread::sleep(std::time::Duration::from_millis(10));
    let outcome = get_or_generate_in(&request, cache_dir.path());

    let ThumbnailOutcome::Ready(path) = outcome else {
        panic!("expected the externally-written thumbnail to be recognized as fresh");
    };
    assert_eq!(path, cached_path);
    let still_written_at = std::fs::metadata(&cached_path).unwrap().modified().unwrap();
    assert_eq!(
        written_at, still_written_at,
        "should not have regenerated an already-fresh thumbnail"
    );
}

#[test]
fn is_thumbnailable_accepts_known_image_formats_and_rejects_others() {
    assert!(is_thumbnailable("image/png"));
    assert!(is_thumbnailable("image/svg+xml"));
    assert!(is_thumbnailable("image/jpeg"));
    assert!(!is_thumbnailable("text/plain"));
    assert!(!is_thumbnailable("inode/directory"));
}

#[test]
fn generates_and_caches_a_png_thumbnail() {
    let source_dir = tempdir().unwrap();
    let cache_dir = tempdir().unwrap();
    let source_path = source_dir.path().join("photo.png");
    write_fixture_png(&source_path);

    let request = ThumbnailRequest {
        source_path: source_path.clone(),
        mime_type: "image/png".to_string(),
        size: std::fs::metadata(&source_path).unwrap().len(),
        modified: std::fs::metadata(&source_path).unwrap().modified().unwrap(),
    };

    let outcome = get_or_generate_in(&request, cache_dir.path());

    let ThumbnailOutcome::Ready(thumb_path) = outcome else {
        panic!("expected a generated thumbnail");
    };
    assert!(thumb_path.starts_with(cache_dir.path().join("normal")));
    assert!(thumb_path.exists());
    let decoded = image::open(&thumb_path).unwrap();
    // Fixture is 32x16 (2:1) — the thumbnail should preserve that aspect
    // ratio while fitting within the 128px normal-size box.
    assert_eq!(decoded.width(), 128);
    assert_eq!(decoded.height(), 64);
}

#[test]
fn reuses_a_fresh_cached_thumbnail_instead_of_regenerating() {
    let source_dir = tempdir().unwrap();
    let cache_dir = tempdir().unwrap();
    let source_path = source_dir.path().join("photo.png");
    write_fixture_png(&source_path);

    let request = ThumbnailRequest {
        source_path: source_path.clone(),
        mime_type: "image/png".to_string(),
        size: std::fs::metadata(&source_path).unwrap().len(),
        modified: std::fs::metadata(&source_path).unwrap().modified().unwrap(),
    };

    let first = get_or_generate_in(&request, cache_dir.path());
    let ThumbnailOutcome::Ready(first_path) = first else {
        panic!("expected a generated thumbnail");
    };
    let first_written_at = std::fs::metadata(&first_path).unwrap().modified().unwrap();

    std::thread::sleep(std::time::Duration::from_millis(10));
    let second = get_or_generate_in(&request, cache_dir.path());

    let ThumbnailOutcome::Ready(second_path) = second else {
        panic!("expected the cached thumbnail to still be ready");
    };
    assert_eq!(first_path, second_path);
    let second_written_at = std::fs::metadata(&second_path).unwrap().modified().unwrap();
    assert_eq!(
        first_written_at, second_written_at,
        "cached thumbnail should not have been rewritten"
    );
}

#[test]
fn generates_a_thumbnail_for_svg_upscaling_to_the_normal_size_box() {
    let source_dir = tempdir().unwrap();
    let cache_dir = tempdir().unwrap();
    let source_path = source_dir.path().join("icon.svg");
    write_fixture_svg(&source_path);

    let request = ThumbnailRequest {
        source_path: source_path.clone(),
        mime_type: "image/svg+xml".to_string(),
        size: std::fs::metadata(&source_path).unwrap().len(),
        modified: std::fs::metadata(&source_path).unwrap().modified().unwrap(),
    };

    let outcome = get_or_generate_in(&request, cache_dir.path());

    let ThumbnailOutcome::Ready(thumb_path) = outcome else {
        panic!("expected a generated svg thumbnail");
    };
    let decoded = image::open(&thumb_path).unwrap();
    // The fixture's 24x24 viewBox is square, so it should be upscaled to
    // fill the full 128x128 normal-size box.
    assert_eq!(decoded.width(), 128);
    assert_eq!(decoded.height(), 128);
}

#[test]
fn unsupported_mime_type_never_touches_the_cache() {
    let source_dir = tempdir().unwrap();
    let cache_dir = tempdir().unwrap();
    let source_path = source_dir.path().join("notes.txt");
    std::fs::write(&source_path, b"hello").unwrap();

    let request = ThumbnailRequest {
        source_path,
        mime_type: "text/plain".to_string(),
        size: 5,
        modified: SystemTime::now(),
    };

    let outcome = get_or_generate_in(&request, cache_dir.path());

    assert_eq!(outcome, ThumbnailOutcome::Unavailable);
    assert!(!cache_dir.path().join("normal").exists());
    assert!(!cache_dir.path().join("fail").exists());
}

#[test]
fn oversized_file_is_skipped_without_decoding() {
    let source_dir = tempdir().unwrap();
    let cache_dir = tempdir().unwrap();
    let source_path = source_dir.path().join("huge.png");
    write_fixture_png(&source_path);

    let request = ThumbnailRequest {
        source_path,
        mime_type: "image/png".to_string(),
        size: 100 * 1024 * 1024, // reported size over the cutoff, real file is tiny
        modified: SystemTime::now(),
    };

    let outcome = get_or_generate_in(&request, cache_dir.path());

    assert_eq!(outcome, ThumbnailOutcome::Unavailable);
}

#[test]
fn corrupt_image_is_marked_failed_and_not_retried() {
    let source_dir = tempdir().unwrap();
    let cache_dir = tempdir().unwrap();
    let source_path = source_dir.path().join("broken.png");
    std::fs::write(&source_path, b"not actually a png").unwrap();
    let modified = std::fs::metadata(&source_path).unwrap().modified().unwrap();

    let request = ThumbnailRequest {
        source_path: source_path.clone(),
        mime_type: "image/png".to_string(),
        size: std::fs::metadata(&source_path).unwrap().len(),
        modified,
    };

    let first = get_or_generate_in(&request, cache_dir.path());
    assert_eq!(first, ThumbnailOutcome::Unavailable);
    let fail_dir = cache_dir.path().join("fail").join("orbit");
    assert!(fail_dir.exists(), "should have written a fail marker");
    let marker_written_at = std::fs::read_dir(&fail_dir)
        .unwrap()
        .next()
        .unwrap()
        .unwrap()
        .metadata()
        .unwrap()
        .modified()
        .unwrap();

    // A second attempt with the same source mtime should hit the fail
    // marker and skip re-decoding entirely (marker file untouched).
    std::thread::sleep(std::time::Duration::from_millis(10));
    let second = get_or_generate_in(&request, cache_dir.path());
    assert_eq!(second, ThumbnailOutcome::Unavailable);
    let marker_still_written_at = std::fs::read_dir(&fail_dir)
        .unwrap()
        .next()
        .unwrap()
        .unwrap()
        .metadata()
        .unwrap()
        .modified()
        .unwrap();
    assert_eq!(marker_written_at, marker_still_written_at);
}

static FFMPEG_ENV_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

fn ffmpeg_available() -> bool {
    std::process::Command::new("ffmpeg")
        .arg("-version")
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn write_fixture_video(path: &std::path::Path) {
    let status = std::process::Command::new("ffmpeg")
        .args(["-v", "error", "-f", "lavfi", "-i", "color=c=red:s=64x48:d=1"])
        .args(["-pix_fmt", "yuv420p", "-y"])
        .arg(path)
        .status()
        .unwrap();
    assert!(status.success());
}

fn video_request(source_path: &std::path::Path) -> ThumbnailRequest {
    ThumbnailRequest {
        source_path: source_path.to_path_buf(),
        mime_type: "video/mp4".to_string(),
        size: std::fs::metadata(source_path).unwrap().len(),
        modified: std::fs::metadata(source_path).unwrap().modified().unwrap(),
    }
}

#[test]
fn is_thumbnailable_accepts_common_video_formats() {
    assert!(is_thumbnailable("video/mp4"));
    assert!(is_thumbnailable("video/x-matroska"));
    assert!(is_thumbnailable("video/webm"));
    assert!(is_thumbnailable("video/quicktime"));
    assert!(is_thumbnailable("video/x-msvideo"));
    assert!(!is_thumbnailable("audio/mpeg"));
    assert!(!is_thumbnailable("application/pdf"));
}

#[test]
fn generates_and_caches_a_thumbnail_for_a_short_video() {
    // The 1s fixture is shorter than the 3s seek point, so this also
    // exercises the retry-at-start fallback.
    let _guard = FFMPEG_ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    if !ffmpeg_available() {
        eprintln!("skipping: ffmpeg not on PATH");
        return;
    }
    let source_dir = tempdir().unwrap();
    let cache_dir = tempdir().unwrap();
    let source_path = source_dir.path().join("clip.mp4");
    write_fixture_video(&source_path);

    let request = video_request(&source_path);
    let ThumbnailOutcome::Ready(generated) = get_or_generate_in(&request, cache_dir.path()) else {
        panic!("expected video generation to succeed");
    };
    assert!(generated.exists());
    assert_eq!(lookup_cached_in(&request, cache_dir.path()), Some(generated));
    assert!(!cache_dir.path().join("fail").exists());
}

#[test]
fn video_larger_than_the_image_byte_cap_still_gets_a_thumbnail() {
    let _guard = FFMPEG_ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    if !ffmpeg_available() {
        eprintln!("skipping: ffmpeg not on PATH");
        return;
    }
    let source_dir = tempdir().unwrap();
    let cache_dir = tempdir().unwrap();
    let source_path = source_dir.path().join("clip.mp4");
    write_fixture_video(&source_path);

    let mut request = video_request(&source_path);
    request.size = 60 * 1024 * 1024;
    assert!(matches!(
        get_or_generate_in(&request, cache_dir.path()),
        ThumbnailOutcome::Ready(_)
    ));
}

#[test]
fn oversized_image_is_still_skipped_by_the_byte_cap() {
    let source_dir = tempdir().unwrap();
    let cache_dir = tempdir().unwrap();
    let source_path = source_dir.path().join("photo.png");
    write_fixture_png(&source_path);

    let mut request = ThumbnailRequest {
        source_path: source_path.clone(),
        mime_type: "image/png".to_string(),
        size: 0,
        modified: std::fs::metadata(&source_path).unwrap().modified().unwrap(),
    };
    request.size = 60 * 1024 * 1024;
    assert_eq!(
        get_or_generate_in(&request, cache_dir.path()),
        ThumbnailOutcome::Unavailable
    );
}

#[test]
fn missing_ffmpeg_reports_unavailable_without_writing_a_fail_marker() {
    let _guard = FFMPEG_ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let source_dir = tempdir().unwrap();
    let cache_dir = tempdir().unwrap();
    let source_path = source_dir.path().join("clip.mp4");
    std::fs::write(&source_path, b"not really a video").unwrap();

    std::env::set_var("FM_FFMPEG", "/nonexistent/ffmpeg-for-test");
    let request = video_request(&source_path);
    let outcome = get_or_generate_in(&request, cache_dir.path());
    std::env::remove_var("FM_FFMPEG");

    assert_eq!(outcome, ThumbnailOutcome::Unavailable);
    assert!(!cache_dir.path().join("fail").exists());
}

#[test]
fn corrupt_video_is_marked_failed_and_not_retried() {
    let _guard = FFMPEG_ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    if !ffmpeg_available() {
        eprintln!("skipping: ffmpeg not on PATH");
        return;
    }
    let source_dir = tempdir().unwrap();
    let cache_dir = tempdir().unwrap();
    let source_path = source_dir.path().join("broken.mp4");
    std::fs::write(&source_path, b"garbage bytes, not a video").unwrap();

    let request = video_request(&source_path);
    assert_eq!(
        get_or_generate_in(&request, cache_dir.path()),
        ThumbnailOutcome::Unavailable
    );
    assert!(cache_dir.path().join("fail").join("orbit").exists());
}
