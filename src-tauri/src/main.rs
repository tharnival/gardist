// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::path::PathBuf;
use std::sync::mpsc;
use tauri::api;
use tauri::api::dialog::FileDialogBuilder;
use tauri::api::process::{Command, CommandEvent};
use tauri::{Manager, Window};

#[derive(Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct StatusOutput {
    info: String,
    path: String,
    is_dir: bool,
}

#[tauri::command]
fn svn_status(path: String) -> Vec<StatusOutput> {
    let cwd = PathBuf::from(path.clone());
    let (mut cmd, mut _child) = Command::new("svn")
        .current_dir(cwd.clone())
        .args(["status"])
        .spawn()
        .expect("Failed to spawn command");

    let (tx, rx) = mpsc::channel();
    tauri::async_runtime::spawn(async move {
        let mut output = Vec::new();
        while let Some(event) = cmd.recv().await {
            if let CommandEvent::Stdout(line) = event {
                let info = line[..7].to_string();
                let path = line[8..].trim().to_string();

                let suffix = PathBuf::from(path.clone());
                let full_path = cwd.clone().join(suffix);

                if info.starts_with('?') {
                    for (entry, is_dir) in recursive_fs_read(&full_path) {
                        if let Ok(Some(relative_path)) =
                            entry.strip_prefix(&cwd).map(std::path::Path::to_str)
                        {
                            output.push(StatusOutput {
                                info: info.clone(),
                                path: relative_path.to_string(),
                                is_dir,
                            })
                        }
                    }
                } else {
                    output.push(StatusOutput {
                        info: info.clone(),
                        path,
                        is_dir: api::dir::is_dir(full_path).unwrap_or(false),
                    });
                }
            }
        }
        tx.send(output)
    });

    rx.recv().unwrap()
}

fn recursive_fs_read(path: &PathBuf) -> Vec<(PathBuf, bool)> {
    match api::dir::read_dir(&path, true) {
        Ok(entries) => {
            let mut contents = entries
                .iter()
                .map(|entry| recursive_fs_read(&entry.path))
                .collect::<Vec<_>>()
                .concat();
            contents.push((path.clone(), true));
            contents
        }
        Err(_) => vec![(path.to_path_buf(), false)],
    }
}

#[tauri::command]
fn svn_commit(root: String, msg: String, changes: Vec<(String, bool)>) -> Vec<StatusOutput> {
    let cwd = PathBuf::from(root.clone());

    let adds: Vec<_> = changes
        .clone()
        .into_iter()
        .filter(|(_path, add)| *add)
        .map(|(path, _add)| path)
        .collect();

    let _ = Command::new("svn")
        .current_dir(cwd.clone())
        .args(["add", "--force", "--depth=empty"])
        .args(adds)
        .status()
        .expect("Failed to spawn command");

    let deletes: Vec<_> = changes
        .clone()
        .into_iter()
        .filter(|(_path, add)| !*add)
        .map(|(path, _add)| path)
        .collect();

    let _ = Command::new("svn")
        .current_dir(cwd.clone())
        .args(["delete", "--force"])
        .args(deletes)
        .status()
        .expect("Failed to spawn command");

    let items: Vec<_> = changes
        .clone()
        .into_iter()
        .map(|(path, _add)| path)
        .collect();

    let _ = Command::new("svn")
        .current_dir(cwd)
        .args(["commit", "--force-log", "-m", &msg])
        .args(items)
        .status()
        .expect("Failed to spawn command");

    svn_status(root)
}

#[tauri::command]
fn svn_revert(root: String, changes: Vec<String>) -> Vec<StatusOutput> {
    let cwd = PathBuf::from(root.clone());

    let _ = Command::new("svn")
        .current_dir(cwd)
        .args(["revert"])
        .args(changes)
        .status()
        .expect("Failed to spawn command");

    svn_status(root)
}

#[derive(Clone, serde::Serialize)]
struct ProjectPath {
    path: Option<String>,
}

#[tauri::command]
fn set_path(window: Window) {
    FileDialogBuilder::new().pick_folder(move |path| {
        let _ = window.emit_all(
            "path_change",
            ProjectPath {
                path: match path {
                    Some(x) => x.to_str().map(str::to_string),
                    None => None,
                },
            },
        );
    });
}

fn main() {
    tauri::Builder::default()
        .setup(|app| {
            // nicer for development
            let _ = app.get_window("main").unwrap().minimize();
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            svn_status, svn_commit, svn_revert, set_path
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
