//! Metrics handler
//!
//! Handles POST /v1/metrics - OTLP metrics endpoint

use axum::{extract::State, http::StatusCode, response::IntoResponse, Json};
use opentelemetry_proto::tonic::collector::metrics::v1::ExportMetricsServiceRequest;
use serde_json::json;
use shared::MetricRepository;
use tracing::{error, info};

use crate::server::AppState;
use crate::services::parse_metrics;

/// POST /v1/metrics - OTLP metrics endpoint
pub async fn export_metrics(
    State(state): State<AppState>,
    Json(payload): Json<ExportMetricsServiceRequest>,
) -> impl IntoResponse {
    info!("Received OTLP metrics export request");

    // Parse OTLP metrics into our entities
    let metrics = parse_metrics(&payload);
    let count = metrics.len();

    if count == 0 {
        return (
            StatusCode::OK,
            Json(json!({
                "status": "success",
                "message": "No metrics to process",
            })),
        );
    }

    info!("Parsed {} metrics", count);

    // Insert metrics into database
    if let Err(e) = MetricRepository::insert_batch(&state.db, &metrics).await {
        error!("Failed to insert metrics: {}", e);
        return (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({
                "status": "error",
                "message": format!("Failed to store metrics: {}", e),
            })),
        );
    }

    info!("Stored {} metrics", count);

    (
        StatusCode::OK,
        Json(json!({
            "status": "success",
            "metrics_received": count,
        })),
    )
}
