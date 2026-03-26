//! OTLP routes
//!
//! Routes for receiving OpenTelemetry data.

use axum::{routing::post, Router};

use crate::handlers;
use crate::server::AppState;

/// Create OTLP routes
pub fn otlp_routes() -> Router<AppState> {
    Router::new()
        .route("/v1/metrics", post(handlers::export_metrics))
        .route("/v1/logs", post(handlers::export_logs))
}
