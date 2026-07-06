use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VolumeKind {
    Disk,
    Phone,
}

/// A mounted real filesystem shown in the sidebar's Devices section
/// (roadmap round-2 item 24).
#[derive(Debug, Clone, PartialEq)]
pub struct Volume {
    pub label: String,
    pub mount_point: PathBuf,
    pub device: String,
    pub total_bytes: u64,
    pub avail_bytes: u64,
    pub kind: VolumeKind,
    pub mounted: bool,
}

/// Parses /proc/mounts-format text into (device, mount_point, fstype)
/// triples, decoding the octal escapes the kernel uses for spaces etc.
/// in mount points (`\040` → space).
pub fn parse_mounts(text: &str) -> Vec<(String, PathBuf, String)> {
    text.lines()
        .filter_map(|line| {
            let mut parts = line.split_whitespace();
            let device = parts.next()?.to_string();
            let mount = unescape_mount(parts.next()?);
            let fstype = parts.next()?.to_string();
            Some((device, PathBuf::from(mount), fstype))
        })
        .collect()
}

fn unescape_mount(raw: &str) -> String {
    let mut out = String::with_capacity(raw.len());
    let bytes = raw.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'\\' && i + 3 < bytes.len() {
            if let Ok(code) = u8::from_str_radix(&raw[i + 1..i + 4], 8) {
                out.push(code as char);
                i += 4;
                continue;
            }
        }
        out.push(bytes[i] as char);
        i += 1;
    }
    out
}

/// Whether a /proc/mounts entry is a real user-relevant volume: an
/// actual block device, not a loop mount (snaps) or an EFI/boot
/// partition nobody browses.
pub fn is_user_volume(device: &str, mount_point: &Path) -> bool {
    if !device.starts_with("/dev/") || device.starts_with("/dev/loop") {
        return false;
    }
    let mp = mount_point.to_string_lossy();
    !(mp.starts_with("/boot") || mp == "/efi" || mp.starts_with("/proc") || mp.starts_with("/sys"))
}

/// Display label: "/" is "System"; anything else uses the mount point's
/// last path segment (which is the filesystem label for udisks mounts
/// under /run/media/<user>/<LABEL>).
pub fn volume_label(mount_point: &Path) -> String {
    if mount_point == Path::new("/") {
        return "System".to_string();
    }
    mount_point
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| mount_point.display().to_string())
}

fn fs_usage(path: &Path) -> Option<(u64, u64)> {
    use std::os::unix::ffi::OsStrExt;
    let c_path = std::ffi::CString::new(path.as_os_str().as_bytes()).ok()?;
    let mut st: libc::statvfs = unsafe { std::mem::zeroed() };
    if unsafe { libc::statvfs(c_path.as_ptr(), &mut st) } != 0 {
        return None;
    }
    let total = st.f_blocks as u64 * st.f_frsize as u64;
    let avail = st.f_bavail as u64 * st.f_frsize as u64;
    Some((total, avail))
}

/// Currently mounted user-relevant volumes with capacity, deduped by
/// device (bind mounts keep only the first mount point). Synchronous —
/// /proc/mounts plus one statvfs per volume is microseconds.
pub fn list_volumes() -> Vec<Volume> {
    let Ok(text) = std::fs::read_to_string("/proc/mounts") else {
        return Vec::new();
    };
    let mut seen = std::collections::HashSet::new();
    parse_mounts(&text)
        .into_iter()
        .filter(|(device, mount, _)| is_user_volume(device, mount))
        .filter(|(device, _, _)| seen.insert(device.clone()))
        .filter_map(|(device, mount, _)| {
            let (total_bytes, avail_bytes) = fs_usage(&mount)?;
            Some(Volume {
                label: volume_label(&mount),
                mount_point: mount,
                device,
                total_bytes,
                avail_bytes,
                kind: VolumeKind::Disk,
                mounted: true,
            })
        })
        .collect()
}

pub fn parse_gio_volumes(text: &str) -> Vec<(String, String)> {
    let mut out = Vec::new();
    let mut name: Option<String> = None;
    let mut is_mtp = false;
    let mut root: Option<String> = None;
    let mut flush = |name: &mut Option<String>, is_mtp: &mut bool, root: &mut Option<String>| {
        if let (Some(n), true, Some(r)) = (name.take(), *is_mtp, root.take()) {
            out.push((n, r));
        }
        *is_mtp = false;
        *root = None;
    };
    for line in text.lines() {
        let trimmed = line.trim_start();
        if trimmed.starts_with("Volume(") {
            flush(&mut name, &mut is_mtp, &mut root);
            name = trimmed.split_once(": ").map(|(_, n)| n.to_string());
        } else if trimmed.starts_with("Drive(") || trimmed.starts_with("Mount(") {
            flush(&mut name, &mut is_mtp, &mut root);
        } else if trimmed.contains("GProxyVolumeMonitorMTP") {
            is_mtp = true;
        } else if let Some(value) = trimmed.strip_prefix("activation_root=") {
            root = Some(value.to_string());
        }
    }
    flush(&mut name, &mut is_mtp, &mut root);
    out
}

pub fn mtp_fuse_path(uri: &str, uid: u32) -> PathBuf {
    let host = uri
        .strip_prefix("mtp://")
        .unwrap_or(uri)
        .trim_end_matches('/');
    PathBuf::from(format!("/run/user/{uid}/gvfs/mtp:host={host}"))
}

pub fn current_gvfs_dir() -> PathBuf {
    PathBuf::from(format!("/run/user/{}/gvfs", unsafe { libc::getuid() }))
}

pub async fn list_phone_volumes() -> Vec<Volume> {
    let Ok(output) = tokio::process::Command::new("gio")
        .args(["mount", "-li"])
        .output()
        .await
    else {
        return Vec::new();
    };
    let text = String::from_utf8_lossy(&output.stdout);
    let uid = unsafe { libc::getuid() };
    parse_gio_volumes(&text)
        .into_iter()
        .map(|(label, uri)| {
            let mount_point = mtp_fuse_path(&uri, uid);
            let mounted = mount_point.is_dir();
            Volume {
                label,
                mount_point,
                device: uri,
                total_bytes: 0,
                avail_bytes: 0,
                kind: VolumeKind::Phone,
                mounted,
            }
        })
        .collect()
}

pub async fn mount_uri(uri: &str) -> std::io::Result<()> {
    let output = tokio::process::Command::new("gio")
        .args(["mount", uri])
        .output()
        .await?;
    if output.status.success() {
        Ok(())
    } else {
        Err(std::io::Error::other(
            String::from_utf8_lossy(&output.stderr).trim().to_string(),
        ))
    }
}

pub fn spawn_mounts_watcher(on_change: impl Fn() + Send + 'static) -> std::io::Result<()> {
    use std::io::{Read, Seek, SeekFrom};
    use std::os::fd::AsRawFd;

    let mut file = std::fs::File::open("/proc/self/mounts")?;
    let mut buf = String::new();
    let _ = file.read_to_string(&mut buf);
    std::thread::spawn(move || loop {
        let mut fds = libc::pollfd {
            fd: file.as_raw_fd(),
            events: libc::POLLPRI,
            revents: 0,
        };
        let r = unsafe { libc::poll(&mut fds, 1, -1) };
        if r < 0 {
            if std::io::Error::last_os_error().kind() == std::io::ErrorKind::Interrupted {
                continue;
            }
            return;
        }
        if fds.revents & (libc::POLLPRI | libc::POLLERR) != 0 {
            buf.clear();
            let _ = file.seek(SeekFrom::Start(0));
            let _ = file.read_to_string(&mut buf);
            on_change();
            std::thread::sleep(std::time::Duration::from_millis(200));
        }
    });
    Ok(())
}

/// Unmounts a device via udisks (the polkit-integrated path a desktop
/// session expects). Returns an error with udisksctl's stderr when the
/// unmount is refused (busy, not permitted).
pub async fn eject(device: &str) -> std::io::Result<()> {
    let output = if device.starts_with("mtp://") {
        tokio::process::Command::new("gio")
            .args(["mount", "-u", device])
            .output()
            .await?
    } else {
        tokio::process::Command::new("udisksctl")
            .args(["unmount", "-b", device])
            .output()
            .await?
    };
    if output.status.success() {
        Ok(())
    } else {
        Err(std::io::Error::other(
            String::from_utf8_lossy(&output.stderr).trim().to_string(),
        ))
    }
}
