//! Server module
//!
//! Contains the HTTP server setup, application state, and graceful shutdown.

mod app;
mod shutdown;
mod state;

pub use app::create_app;
pub use shutdown::shutdown_signal;
pub use state::AppState;
