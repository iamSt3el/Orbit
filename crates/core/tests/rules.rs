use fm_core::rules;
use fm_core::settings::Rule;
use std::fs;
use tempfile::tempdir;

#[test]
fn glob_matches_star_and_question() {
    assert!(rules::glob_match("*.pdf", "report.pdf"));
    assert!(rules::glob_match("*.PDF", "report.pdf"));
    assert!(rules::glob_match("IMG_????.jpg", "IMG_1234.jpg"));
    assert!(rules::glob_match("*", "anything"));
    assert!(!rules::glob_match("*.pdf", "report.pdfx"));
    assert!(!rules::glob_match("IMG_????.jpg", "IMG_12345.jpg"));
}

#[tokio::test]
async fn apply_rule_moves_matching_files_with_conflict_naming() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("downloads");
    let dest = dir.path().join("docs");
    fs::create_dir_all(&src).unwrap();
    fs::create_dir_all(&dest).unwrap();
    fs::write(src.join("a.pdf"), b"a").unwrap();
    fs::write(src.join("b.pdf"), b"b").unwrap();
    fs::write(src.join("keep.txt"), b"k").unwrap();
    fs::write(dest.join("a.pdf"), b"existing").unwrap();
    fs::create_dir(src.join("folder.pdf")).unwrap();

    let rule = Rule {
        dir: src.display().to_string(),
        pattern: "*.pdf".to_string(),
        dest: dest.display().to_string(),
    };
    let moved = rules::apply_rule(&rule).await;

    assert_eq!(moved.len(), 2);
    assert!(src.join("keep.txt").exists());
    assert!(src.join("folder.pdf").is_dir());
    assert!(dest.join("a (2).pdf").exists());
    assert!(dest.join("b.pdf").exists());
    assert_eq!(fs::read(dest.join("a.pdf")).unwrap(), b"existing");
}

#[tokio::test]
async fn apply_rule_refuses_same_source_and_dest() {
    let dir = tempdir().unwrap();
    fs::write(dir.path().join("a.pdf"), b"a").unwrap();

    let rule = Rule {
        dir: dir.path().display().to_string(),
        pattern: "*.pdf".to_string(),
        dest: dir.path().display().to_string(),
    };
    let moved = rules::apply_rule(&rule).await;

    assert!(moved.is_empty());
    assert!(dir.path().join("a.pdf").exists());
}
