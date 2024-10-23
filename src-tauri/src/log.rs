use std::fs::OpenOptions;
use std::io::Write;
use std::path::PathBuf;
use tauri::api::process::{CommandEvent, Output};
use tauri::async_runtime::Receiver;
use tauri::AppHandle;

pub fn log_output(app: AppHandle, cwd: PathBuf, cmd: &str, output: tauri::api::Result<Output>) {
    match output {
        Ok(out) => log_cmd(app, cwd, cmd, &out.stdout, &out.stderr, out.status.code()),
        Err(e) => println!("failed to run '{}' because {}", cmd, e),
    }
}

pub fn log_process(app: AppHandle, cwd: PathBuf, cmd: &str, mut rx: Receiver<CommandEvent>) {
    let cmd_clone = cmd.to_string();
    tauri::async_runtime::spawn(async move {
        let mut stdout = String::new();
        let mut stderr = String::new();
        let mut exit_code = None;
        while let Some(event) = rx.recv().await {
            if let CommandEvent::Stdout(line) = event {
                stdout += &line;
            } else if let CommandEvent::Stderr(line) = event {
                stderr += &line;
            } else if let CommandEvent::Terminated(payload) = event {
                exit_code = payload.code;
            }
        }
        log_cmd(app, cwd, &cmd_clone, &stdout, &stderr, exit_code);
    });
}

pub fn log_cmd(
    app: AppHandle,
    cwd: PathBuf,
    cmd: &str,
    stdout: &str,
    stderr: &str,
    exit_code: Option<i32>,
) {
    let mut log = "in ".to_string();
    log += cwd.to_str().unwrap_or("FAILED");
    log += &format!("\n$ {cmd}\n");
    log += "\nSTDOUT:\n";
    log += stdout;
    log += "\nSTDERR:\n";
    log += stderr;
    if let Some(exit) = exit_code {
        log += "\nwith exit code: ";
        log += &exit.to_string();
    }
    log += "\n\n";

    log_text(app, &log);
}

pub fn log_text(app: AppHandle, text: &str) {
    let mut log_dir = app.path_resolver().app_log_dir().unwrap();
    log_dir.push("log.txt");
    let opening = OpenOptions::new()
        .append(true)
        .create(true)
        .open(log_dir.as_path());
    if let Ok(mut file) = opening {
        let _ = file.write(text.as_bytes());
    } else if let Err(e) = opening {
        println!("log file opening error: {}", e);
    }
}
