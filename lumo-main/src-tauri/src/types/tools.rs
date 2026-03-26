//! Tools types
//!
//! Types for tool usage statistics and analysis.

use serde::{Deserialize, Serialize};
use typeshare::typeshare;

/// Tool usage statistics (frequency, success rate, duration)
#[typeshare]
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ToolUsageStats {
    pub tool_name: String,
    pub count: i32,
    pub successes: i32,
    pub failures: i32,
    pub avg_duration_ms: Option<f32>,
}

/// Code edit decisions grouped by language
#[typeshare]
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CodeEditLanguageStats {
    pub language: String,
    pub accepts: i32,
    pub rejects: i32,
}

/// Tool usage trend (daily counts for top tools)
#[typeshare]
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ToolTrend {
    pub tool_name: String,
    pub date: String,
    pub count: i32,
}
