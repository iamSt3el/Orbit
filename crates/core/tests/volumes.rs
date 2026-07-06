use fm_core::volumes::{is_user_volume, parse_mounts, volume_label};
use std::path::Path;

#[test]
fn parse_mounts_extracts_triples_and_unescapes_octal() {
    let text = "\
/dev/nvme0n1p2 / ext4 rw,relatime 0 0
tmpfs /tmp tmpfs rw 0 0
/dev/sda1 /run/media/steel/My\\040Disk ext4 rw 0 0
";
    let mounts = parse_mounts(text);
    assert_eq!(mounts.len(), 3);
    assert_eq!(mounts[0].0, "/dev/nvme0n1p2");
    assert_eq!(mounts[0].1, Path::new("/"));
    assert_eq!(mounts[0].2, "ext4");
    assert_eq!(mounts[2].1, Path::new("/run/media/steel/My Disk"));
}

#[test]
fn is_user_volume_filters_pseudo_loop_and_boot() {
    assert!(is_user_volume("/dev/sda1", Path::new("/run/media/steel/USB")));
    assert!(is_user_volume("/dev/nvme0n1p2", Path::new("/")));
    assert!(!is_user_volume("tmpfs", Path::new("/tmp")));
    assert!(!is_user_volume("/dev/loop3", Path::new("/snap/foo/1")));
    assert!(!is_user_volume("/dev/nvme0n1p1", Path::new("/boot")));
}

#[test]
fn volume_label_uses_system_for_root_and_leaf_otherwise() {
    assert_eq!(volume_label(Path::new("/")), "System");
    assert_eq!(volume_label(Path::new("/run/media/steel/My Disk")), "My Disk");
    assert_eq!(volume_label(Path::new("/mnt/data")), "data");
}

#[test]
fn parse_gio_volumes_finds_mtp_volumes_and_skips_disks() {
    let text = "\
Drive(0): HFM512GDJTNG-8310A
  Type: GProxyDrive (GProxyVolumeMonitorUDisks2)
  ids:
   unix-device: '/dev/nvme0n1'
  is_removable=0
  Volume(0): DESKTOP-7JELUEU C: 12-12-2024
    Type: GProxyVolume (GProxyVolumeMonitorUDisks2)
    ids:
     unix-device: '/dev/nvme0n1p3'
    can_mount=1
Volume(0): M2102J20SI
  Type: GProxyVolume (GProxyVolumeMonitorMTP)
  ids:
   unix-device: '/dev/bus/usb/003/008'
  activation_root=mtp://Xiaomi_M2102J20SI_c248c7f2/
  themed icons:  [phone]
  can_mount=1
";
    let phones = fm_core::volumes::parse_gio_volumes(text);
    assert_eq!(phones.len(), 1);
    assert_eq!(phones[0].0, "M2102J20SI");
    assert_eq!(phones[0].1, "mtp://Xiaomi_M2102J20SI_c248c7f2/");
}

#[test]
fn parse_gio_volumes_returns_empty_when_no_mtp_present() {
    let text = "\
Volume(0): USB Stick
  Type: GProxyVolume (GProxyVolumeMonitorUDisks2)
  activation_root=file:///run/media/steel/USB
";
    assert!(fm_core::volumes::parse_gio_volumes(text).is_empty());
}

#[test]
fn mtp_fuse_path_maps_uri_host_to_gvfs_dir() {
    assert_eq!(
        fm_core::volumes::mtp_fuse_path("mtp://Xiaomi_M2102J20SI_c248c7f2/", 1000),
        Path::new("/run/user/1000/gvfs/mtp:host=Xiaomi_M2102J20SI_c248c7f2")
    );
    assert_eq!(
        fm_core::volumes::mtp_fuse_path("mtp://Pixel_8_ABC123", 1001),
        Path::new("/run/user/1001/gvfs/mtp:host=Pixel_8_ABC123")
    );
}
