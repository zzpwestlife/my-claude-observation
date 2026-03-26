use anyhow::{Context, Result};
use std::env;

#[derive(Debug, Clone)]
pub struct Config {
    /// Server listening address (e.g., "127.0.0.1:4318")
    pub server_address: String,

    /// Log level (e.g., "info", "debug", "trace")
    pub log_level: String,
}

impl Config {
    /// Load configuration from environment variables
    pub fn from_env() -> Result<Self> {
        let server_address = env::var("LUMO_SERVER_ADDRESS")
            .unwrap_or_else(|_| "127.0.0.1:4318".to_string());

        let log_level =
            env::var("RUST_LOG").unwrap_or_else(|_| "lumo_daemon=info,tower_http=info".to_string());

        Ok(Config {
            server_address,
            log_level,
        })
    }

    /// Validate configuration
    pub fn validate(&self) -> Result<()> {
        // Parse address to ensure it's valid
        self.server_address
            .parse::<std::net::SocketAddr>()
            .context("Invalid server address")?;

        Ok(())
    }
}
