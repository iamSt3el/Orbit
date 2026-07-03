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
    if let Some(guess) = mime_guess::from_path(path).first() {
        return MimeInfo {
            icon_key: icon_key_for(guess.as_ref()),
            mime_type: guess.essence_str().to_string(),
        };
    }

    if let Ok(bytes) = fs::read(path) {
        let sniff_len = bytes.len().min(8192);
        if let Some(kind) = infer::get(&bytes[..sniff_len]) {
            let mime = kind.mime_type();
            return MimeInfo {
                icon_key: icon_key_for(mime),
                mime_type: mime.to_string(),
            };
        }
    }

    MimeInfo {
        mime_type: "application/octet-stream".to_string(),
        icon_key: "file".to_string(),
    }
}

fn icon_key_for(mime: &str) -> String {
    if mime == "application/pdf" {
        return "pdf".to_string();
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
