//! Wrapped commands
//!
//! Tauri IPC commands for the personal report card feature.

use sqlx::SqlitePool;
use tauri::{command, AppHandle, Manager};

use crate::services::WrappedService;
use crate::types::{WrappedData, WrappedPeriod};

/// Get wrapped report data
#[command]
pub async fn get_wrapped_data(
    app_handle: AppHandle,
    period: WrappedPeriod,
) -> Result<WrappedData, String> {
    let pool = app_handle.state::<SqlitePool>();
    WrappedService::get_wrapped_data(&pool, period)
        .await
        .map_err(|e| e.to_string())
}
