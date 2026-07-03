use notify::{Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::path::{Path, PathBuf};
use tokio::sync::mpsc;

#[derive(Debug, Clone, PartialEq)]
pub enum WatchEvent {
    Created(PathBuf),
    Removed(PathBuf),
    Modified(PathBuf),
    Renamed { from: PathBuf, to: PathBuf },
}

pub struct DirWatcher {
    _watcher: RecommendedWatcher,
}

impl DirWatcher {
    pub fn new(path: &Path, tx: mpsc::UnboundedSender<WatchEvent>) -> notify::Result<Self> {
        let mut watcher = notify::recommended_watcher(move |result: notify::Result<Event>| {
            let Ok(event) = result else { return };
            for mapped in map_event(event) {
                let _ = tx.send(mapped);
            }
        })?;
        watcher.watch(path, RecursiveMode::NonRecursive)?;
        Ok(Self { _watcher: watcher })
    }
}

fn map_event(event: Event) -> Vec<WatchEvent> {
    match event.kind {
        EventKind::Create(_) => event.paths.into_iter().map(WatchEvent::Created).collect(),
        EventKind::Remove(_) => event.paths.into_iter().map(WatchEvent::Removed).collect(),
        EventKind::Modify(notify::event::ModifyKind::Name(notify::event::RenameMode::Both)) => {
            if event.paths.len() == 2 {
                vec![WatchEvent::Renamed {
                    from: event.paths[0].clone(),
                    to: event.paths[1].clone(),
                }]
            } else {
                vec![]
            }
        }
        EventKind::Modify(_) => event.paths.into_iter().map(WatchEvent::Modified).collect(),
        _ => vec![],
    }
}
