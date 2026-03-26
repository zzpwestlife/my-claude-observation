//! Health check routes

use axum::{routing::get, Router};

use crate::handlers;
use crate::server::AppState;

/// Create health check routes
pub fn health_routes() -> Router<AppState> {
    Router::new().route("/health", get(handlers::health_check))
}
