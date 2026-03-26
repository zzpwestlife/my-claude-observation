//! Health check handler

use axum::{extract::State, http::StatusCode, response::IntoResponse, Json};
use serde_json::json;

use crate::server::AppState;

/// GET /health - Health check endpoint
pub async fn health_check(State(state): State<AppState>) -> impl IntoResponse {
    // Try to ping the database
    let db_status = sqlx::query("SELECT 1")
        .execute(&state.db)
        .await
        .is_ok();

    let status = if db_status {
        StatusCode::OK
    } else {
        StatusCode::SERVICE_UNAVAILABLE
    };

    (
        status,
        Json(json!({
            "status": if db_status { "healthy" } else { "unhealthy" },
            "service": "lumo-daemon",
            "version": env!("CARGO_PKG_VERSION"),
            "database": if db_status { "connected" } else { "disconnected" },
        })),
    )
}
