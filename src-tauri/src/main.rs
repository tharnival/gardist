// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::sync::mpsc;
use tauri::api::dialog::FileDialogBuilder;
use tauri::api::process::{Command, CommandEvent};
use tauri::{AppHandle, Manager, State};

#[derive(Clone, serde::Serialize)]
struct Payload {
    msg: String,
}

#[tauri::command]
fn svn(path: String) -> String {
    let (mut scrx, mut _child) = Command::new("svn")
        .args(["status", &path])
        .spawn()
        .expect("Failed to spawn command");

    let (tx, rx) = mpsc::channel();
    tauri::async_runtime::spawn(async move {
        let mut output = "".to_string();
        while let Some(event) = scrx.recv().await {
            if let CommandEvent::Stdout(line) = event {
                output.push_str(&line);
            } else if let CommandEvent::Stderr(line) = event {
                output.push_str(&line);
            }
        }
        tx.send(output)
    });

    rx.recv().unwrap_or("".to_string())
}

#[tauri::command]
fn set_path(store: State<Store>) {
    let app_handle = store.app_handle.clone();
    FileDialogBuilder::new().pick_folder(move |path| {
        let _ = app_handle.emit_all(
            "path_change",
            Payload {
                // TODO: crashes when cancelling
                msg: path.unwrap().to_str().unwrap_or("").into(),
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
        .invoke_handler(tauri::generate_handler![svn, set_path])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
