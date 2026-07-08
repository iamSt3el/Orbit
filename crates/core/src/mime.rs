use std::fs;
use std::path::Path;

#[derive(Debug, Clone, PartialEq)]
pub struct MimeInfo {
    pub mime_type: String,
    pub icon_key: String,
}

pub fn detect_dir() -> MimeInfo {
    MimeInfo {
        mime_type: "inode/directory".to_string(),
        icon_key: "folder".to_string(),
    }
}

pub fn detect(path: &Path) -> MimeInfo {
    let ext_key = path
        .extension()
        .and_then(|e| e.to_str())
        .and_then(|e| icon_key_for_extension(&e.to_ascii_lowercase()));

    if let Some(guess) = mime_guess::from_path(path).first() {
        return MimeInfo {
            icon_key: ext_key
                .map(str::to_string)
                .unwrap_or_else(|| icon_key_for(guess.as_ref())),
            mime_type: guess.essence_str().to_string(),
        };
    }

    if let Some(key) = ext_key {
        return MimeInfo {
            mime_type: "application/octet-stream".to_string(),
            icon_key: key.to_string(),
        };
    }

    // Bounded read: only the first 8KB ever leaves the disk. fs::read()
    // here would load the ENTIRE file into memory just to sniff its magic
    // bytes — for an extension-less multi-GB file that meant a multi-GB
    // allocation during a plain directory listing.
    if let Ok(file) = fs::File::open(path) {
        use std::io::Read;
        let mut bytes = Vec::with_capacity(8192);
        if file.take(8192).read_to_end(&mut bytes).is_ok() {
            if let Some(kind) = infer::get(&bytes) {
                let mime = kind.mime_type();
                return MimeInfo {
                    icon_key: icon_key_for(mime),
                    mime_type: mime.to_string(),
                };
            }
        }
    }

    MimeInfo {
        mime_type: "application/octet-stream".to_string(),
        icon_key: "file".to_string(),
    }
}

fn icon_key_for_extension(ext: &str) -> Option<&'static str> {
    let key = match ext {
        "rs" | "py" | "js" | "mjs" | "cjs" | "ts" | "tsx" | "jsx" | "c" | "h" | "cpp" | "cxx"
        | "cc" | "hpp" | "hh" | "java" | "kt" | "kts" | "go" | "rb" | "php" | "swift" | "cs"
        | "sh" | "bash" | "zsh" | "fish" | "lua" | "pl" | "pm" | "r" | "scala" | "dart"
        | "vue" | "svelte" | "qml" | "sql" | "html" | "htm" | "css" | "scss" | "sass" | "less"
        | "json" | "yaml" | "yml" | "toml" | "xml" | "ini" | "cmake" | "gradle" | "hs" | "ex"
        | "exs" | "erl" | "zig" | "nim" | "vim" | "asm" | "ps1" | "bat" | "cmd" => "code",
        "doc" | "docx" | "odt" | "rtf" => "doc",
        "xls" | "xlsx" | "ods" | "csv" | "tsv" => "spreadsheet",
        "ppt" | "pptx" | "odp" => "presentation",
        "ttf" | "otf" | "woff" | "woff2" => "font",
        "db" | "sqlite" | "sqlite3" => "database",
        "epub" | "mobi" | "azw" | "azw3" => "ebook",
        "exe" | "msi" | "appimage" | "run" => "executable",
        "deb" | "rpm" | "apk" | "iso" => "archive",
        _ => return None,
    };
    Some(key)
}

fn icon_key_for(mime: &str) -> String {
    if mime == "application/pdf" {
        return "pdf".to_string();
    }
    if mime.starts_with("font/") {
        return "font".to_string();
    }
    if mime == "application/msword"
        || mime.ends_with("wordprocessingml.document")
        || mime == "application/vnd.oasis.opendocument.text"
    {
        return "doc".to_string();
    }
    if mime == "application/vnd.ms-excel"
        || mime.ends_with("spreadsheetml.sheet")
        || mime == "application/vnd.oasis.opendocument.spreadsheet"
    {
        return "spreadsheet".to_string();
    }
    if mime == "application/vnd.ms-powerpoint"
        || mime.ends_with("presentationml.presentation")
        || mime == "application/vnd.oasis.opendocument.presentation"
    {
        return "presentation".to_string();
    }
    if mime == "application/epub+zip" {
        return "ebook".to_string();
    }
    if mime == "application/x-executable" || mime == "application/vnd.microsoft.portable-executable"
    {
        return "executable".to_string();
    }
    if mime.starts_with("image/") {
        return "image".to_string();
    }
    if mime.starts_with("video/") {
        return "video".to_string();
    }
    if mime.starts_with("audio/") {
        return "audio".to_string();
    }
    if mime.starts_with("text/") {
        return "text".to_string();
    }
    if matches!(
        mime,
        "application/zip"
            | "application/x-tar"
            | "application/gzip"
            | "application/x-7z-compressed"
            | "application/x-rar-compressed"
    ) {
        return "archive".to_string();
    }
    "file".to_string()
}
