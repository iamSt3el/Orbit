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
