//! Tools commands
//!
//! Tauri IPC commands for tool usage analysis.

use sqlx::SqlitePool;
use tauri::{command, AppHandle, Manager};

use crate::services::ToolsService;
use crate::types::{CodeEditLanguageStats, TimeRange, ToolTrend, ToolUsageStats};

/// Get tool usage statistics
#[command]
pub async fn get_tool_usage_stats(
    app_handle: AppHandle,
    time_range: TimeRange,
) -> Result<Vec<ToolUsageStats>, String> {
    let pool = app_handle.state::<SqlitePool>();
    ToolsService::get_tool_usage_stats(&pool, time_range)
        .await
        .map_err(|e| e.to_string())
}

/// Get code edit decisions by language
#[command]
pub async fn get_code_edit_by_language(
    app_handle: AppHandle,
    time_range: TimeRange,
) -> Result<Vec<CodeEditLanguageStats>, String> {
    let pool = app_handle.state::<SqlitePool>();
    ToolsService::get_code_edit_by_language(&pool, time_range)
        .await
        .map_err(|e| e.to_string())
}

/// Get tool usage trends (top 5 tools daily)
#[command]
pub async fn get_tool_trends(
    app_handle: AppHandle,
    time_range: TimeRange,
) -> Result<Vec<ToolTrend>, String> {
    let pool = app_handle.state::<SqlitePool>();
    ToolsService::get_tool_trends(&pool, time_range)
        .await
        .map_err(|e| e.to_string())
}
