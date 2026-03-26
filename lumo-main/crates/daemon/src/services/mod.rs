//! Business logic services

mod otlp_parser;

pub use otlp_parser::{parse_logs_to_events, parse_metrics};
