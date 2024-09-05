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

                let mut is_dir = false;
                if info.starts_with('?') {
                    let suffix = PathBuf::from(path.clone());
                    let full_path = cwd.join(suffix);
                    is_dir = match api::dir::is_dir(full_path) {
                        Ok(true) => true,
                        _ => false,
                    };
                }

                output.push(StatusOutput { info, path, is_dir });
            }
        }
        tx.send(output)
    });

    rx.recv().unwrap()
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
        .args(["commit", "-m", &msg])
        .args(items)
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
        .invoke_handler(tauri::generate_handler![svn_status, svn_commit, set_path])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
