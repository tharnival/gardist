// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod log;
use crate::log::*;

use std::fs::{self, OpenOptions};
use std::path::PathBuf;
use std::sync::mpsc;
use tauri::api;
use tauri::api::dialog::FileDialogBuilder;
use tauri::api::process::{Command, CommandEvent};
use tauri::AppHandle;
use tauri::{Manager, Window};

#[derive(Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct StatusOutput {
    info: String,
    path: String,
    is_dir: bool,
}

#[tauri::command]
fn svn_status(app: AppHandle, path: String) -> Vec<StatusOutput> {
    let cwd = PathBuf::from(path.clone());
    let (mut cmd, mut _child) = Command::new("svn")
        .current_dir(cwd.clone())
        .args(["status"])
        .spawn()
        .expect("Failed to spawn command");

    let (tx, rx) = mpsc::channel();
    tauri::async_runtime::spawn(async move {
        let mut output = Vec::new();
        let mut stdout = String::new();
        let mut stderr = String::new();
        let mut exit_code = None;
        while let Some(event) = cmd.recv().await {
            if let CommandEvent::Stdout(line) = event {
                stdout += &line;
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
            } else if let CommandEvent::Stdout(line) = event {
                stderr += &line;
            } else if let CommandEvent::Terminated(payload) = event {
                exit_code = payload.code;
            }
        }

        log_cmd(app, cwd, "svn status", &stdout, &stderr, exit_code);

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
fn svn_checkout(
    app: AppHandle,
    root: String,
    repo: String,
    username: String,
    password: String,
    os: String,
) -> Vec<StatusOutput> {
    let cwd = PathBuf::from(root.clone());

    let (rx, mut child) = Command::new("svn")
        .current_dir(cwd.clone())
        .args(["checkout", &repo, "."])
        .args([
            "--non-interactive",
            "--username",
            &username,
            "--password-from-stdin",
        ])
        .spawn()
        .expect("Failed to spawn command");

    let _ = child.write((password + &line_ending(os)).as_bytes());

    log_process(
        app.clone(),
        cwd,
        &format!(
            "svn checkout {} . --non-interactive --username {} --password-from-stdin",
            &repo, &username
        ),
        rx,
    );

    svn_status(app, root)
}

#[tauri::command]
fn svn_commit(
    app: AppHandle,
    root: String,
    msg: String,
    changes: Vec<(String, bool)>,
    username: String,
    password: String,
    os: String,
) -> Vec<StatusOutput> {
    let cwd = PathBuf::from(root.clone());

    // add files marked for adding
    let adds: Vec<_> = changes
        .clone()
        .into_iter()
        .filter(|(_path, add)| *add)
        .map(|(path, _add)| path)
        .collect();

    let add_output = Command::new("svn")
        .current_dir(cwd.clone())
        .args(["add", "--force", "--depth=empty"])
        .args(adds.clone())
        .output();

    log_output(
        app.clone(),
        cwd.clone(),
        &format!("{} {}", "svn add --force --depth=empty", adds.join(" ")),
        add_output,
    );

    // delete files marked for deletion
    let deletes: Vec<_> = changes
        .clone()
        .into_iter()
        .filter(|(_path, add)| !*add)
        .map(|(path, _add)| path)
        .collect();

    let delete_output = Command::new("svn")
        .current_dir(cwd.clone())
        .args(["delete", "--force"])
        .args(deletes.clone())
        .output();

    log_output(
        app.clone(),
        cwd.clone(),
        &format!("{} {}", "svn delete --force", deletes.join(" ")),
        delete_output,
    );

    // commit marked items
    let items: Vec<_> = changes
        .clone()
        .into_iter()
        .map(|(path, _add)| path)
        .collect();

    let (rx, mut child) = Command::new("svn")
        .current_dir(cwd.clone())
        .args(["commit", "--force-log", "-m", &msg])
        .args([
            "--non-interactive",
            "--username",
            &username,
            "--password-from-stdin",
        ])
        .args(items)
        .spawn()
        .expect("Failed to spawn command");

    let _ = child.write((password + &line_ending(os)).as_bytes());

    log_process(
        app.clone(),
        cwd,
        &format!(
            "svn commit --force-log -m '{}' --non-interactive --username {} --password-from-stdin",
            &msg, &username
        ),
        rx,
    );

    svn_status(app, root)
}

#[tauri::command]
fn svn_revert(app: AppHandle, root: String, changes: Vec<String>) -> Vec<StatusOutput> {
    let cwd = PathBuf::from(root.clone());

    let output = Command::new("svn")
        .current_dir(cwd.clone())
        .args(["revert"])
        .args(changes.clone())
        .output();

    log_output(
        app.clone(),
        cwd,
        &format!("{} {}", "svn revert", changes.join(" ")),
        output,
    );

    svn_status(app, root)
}

#[derive(Clone, serde::Serialize)]
struct ProjectPath {
    path: Option<String>,
    repo: Option<String>,
}

#[tauri::command]
fn set_path(window: Window) {
    FileDialogBuilder::new().pick_folder(move |path| {
        // get URL of selected directory if working copy
        let mut repo = Some("".to_string());
        if let Some(root) = path.clone() {
            let output = Command::new("svn")
                .current_dir(root)
                .args(["info"])
                .output()
                .expect("Failed to spawn command");

            let re = regex::Regex::new(r"URL: ([^\n]*)").unwrap();
            if let Some(captures) = re.clone().captures(&output.stdout) {
                if let Some(url) = captures.get(1) {
                    repo = Some(url.as_str().to_string());
                }
            }
        }

        let _ = window.emit_all(
            "path_change",
            ProjectPath {
                path: match path {
                    Some(ref x) => x.to_str().map(str::to_string),
                    None => None,
                },
                repo: match path {
                    Some(_) => repo,
                    None => None,
                },
            },
        );
    });
}

fn line_ending(os: String) -> String {
    if os == "Windows_NT" {
        "\r\n".to_string()
    } else {
        "\n".to_string()
    }
}

fn main() {
    tauri::Builder::default()
        .setup(|app| {
            let mut log_dir = app.path_resolver().app_log_dir().unwrap();

            println!(
                "creating new log file at {}/log.txt...",
                log_dir.to_str().unwrap_or("FAILED")
            );

            match fs::create_dir_all(log_dir.as_path()) {
                Ok(_) => {
                    log_dir.push("log.txt");
                    if let Err(e) = OpenOptions::new()
                        .write(true)
                        .truncate(true)
                        .create(true)
                        .open(log_dir.as_path())
                    {
                        println!("failed to create log file: {}", e)
                    } else {
                        println!("succesfully created log file")
                    }
                }
                Err(e) => println!("failed to create log file directory: {}", e),
            }

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            svn_status,
            svn_checkout,
            svn_commit,
            svn_revert,
            set_path
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
