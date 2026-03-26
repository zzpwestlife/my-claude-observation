use tauri::command;

use crate::daemon::check_daemon_health;

#[command]
pub async fn get_daemon_status() -> Result<bool, String> {
    Ok(check_daemon_health().await.is_some())
}
