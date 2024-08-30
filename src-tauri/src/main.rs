// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::sync::mpsc;
use tauri::api::process::{Command, CommandEvent};

#[tauri::command]
fn svn() -> String {
  let (mut scrx, mut _child) = Command::new("svn")
    .args(["status"])
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

fn main() {
  tauri::Builder::default()
    .invoke_handler(tauri::generate_handler![
      svn
    ])
    .run(tauri::generate_context!())
    .expect("error while running tauri application");
}
