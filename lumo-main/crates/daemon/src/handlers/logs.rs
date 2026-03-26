//! Logs handler
//!
//! Handles POST /v1/logs - OTLP logs/events endpoint

use axum::{extract::State, http::StatusCode, response::IntoResponse, Json};
use opentelemetry_proto::tonic::collector::logs::v1::ExportLogsServiceRequest;
use serde_json::json;
use shared::EventRepository;
use tracing::{error, info};

use crate::server::AppState;
use crate::services::parse_logs_to_events;

/// POST /v1/logs - OTLP logs/events endpoint
pub async fn export_logs(
    State(state): State<AppState>,
    Json(payload): Json<ExportLogsServiceRequest>,
) -> impl IntoResponse {
    info!("Received OTLP logs export request");

    // Parse OTLP logs into our event entities
    let events = parse_logs_to_events(&payload);
    let count = events.len();

    if count == 0 {
        return (
            StatusCode::OK,
            Json(json!({
                "status": "success",
                "message": "No events to process",
            })),
        );
    }

    info!("Parsed {} events", count);

    // Insert events into database
    if let Err(e) = EventRepository::insert_batch(&state.db, &events).await {
        error!("Failed to insert events: {}", e);
        return (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({
                "status": "error",
                "message": format!("Failed to store events: {}", e),
            })),
        );
    }

    info!("Stored {} events", count);

    (
        StatusCode::OK,
        Json(json!({
            "status": "success",
            "events_received": count,
        })),
    )
}
