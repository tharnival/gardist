// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::path::PathBuf;
use std::sync::mpsc;
use tauri::api::dialog::FileDialogBuilder;
use tauri::api::process::{Command, CommandEvent};
use tauri::{AppHandle, Manager, State};

#[derive(Clone, serde::Serialize)]
struct Path {
    path: Option<String>,
}

#[tauri::command]
fn svn_status(path: String) -> Vec<(String, String)> {
    let cwd = PathBuf::from(path.clone());
    let (mut cmd, mut _child) = Command::new("svn")
        .current_dir(cwd)
        .args(["status"])
        .spawn()
        .expect("Failed to spawn command");

    let (tx, rx) = mpsc::channel();
    tauri::async_runtime::spawn(async move {
        let mut output = Vec::new();
        while let Some(event) = cmd.recv().await {
            if let CommandEvent::Stdout(line) = event {
                let status = line[..7].to_string();
                let path = line[8..].trim().to_string();
                output.push((status, path));
            }
        }
        tx.send(output)
    });

    rx.recv().unwrap()
}

#[tauri::command]
fn svn_commit(root: String, msg: String, changes: Vec<String>) -> Vec<(String, String)> {
    println!("commit");
    let cwd = PathBuf::from(root.clone());
    let _ = Command::new("svn")
        .current_dir(cwd.clone())
        .args(["add", "--force"])
        .args(changes.clone())
        .status()
        .expect("Failed to spawn command");

    let _ = Command::new("svn")
        .current_dir(cwd)
        .args(["commit", "-m", &msg])
        .args(changes)
        .status()
        .expect("Failed to spawn command");

    svn_status(root)
}

#[tauri::command]
fn set_path(store: State<Store>) {
    let app_handle = store.app_handle.clone();
    FileDialogBuilder::new().pick_folder(move |path| {
        let _ = app_handle.emit_all(
            "path_change",
            Path {
                path: match path {
                    Some(x) => x.to_str().map(str::to_string),
                    None => None,
                },
            },
        );
    });
}

struct Store {
    app_handle: AppHandle,
}

fn main() {
    tauri::Builder::default()
        .setup(|app| {
            app.manage(Store {
                app_handle: app.app_handle(),
            });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![svn_status, svn_commit, set_path])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
