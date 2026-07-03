use std::path::PathBuf;
use std::time::SystemTime;

#[derive(Debug, Clone, PartialEq)]
pub struct FileEntry {
    pub name: String,
    pub path: PathBuf,
    pub is_dir: bool,
    pub size: u64,
    pub modified: SystemTime,
    pub mime_type: String,
    pub icon_key: String,
    pub permissions: String,
}

/// Formats a Unix permission mode as a 9-character `rwxr-xr-x` style string
/// (owner/group/other), matching `ls -l` without the leading file-type char.
pub fn format_permissions(mode: u32) -> String {
    const BITS: [(u32, char); 9] = [
        (0o400, 'r'),
        (0o200, 'w'),
        (0o100, 'x'),
        (0o040, 'r'),
        (0o020, 'w'),
        (0o010, 'x'),
        (0o004, 'r'),
        (0o002, 'w'),
        (0o001, 'x'),
    ];
    BITS.iter()
        .map(|&(bit, c)| if mode & bit != 0 { c } else { '-' })
        .collect()
}
