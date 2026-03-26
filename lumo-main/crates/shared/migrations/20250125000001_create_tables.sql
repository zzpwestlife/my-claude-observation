-- Lumo Database Schema
-- Stores Claude Code telemetry data (metrics and events)

-- ============================================
-- metrics: Stores OTLP metrics from Claude Code
-- These are already aggregated by Claude Code (sent every 60s)
-- ============================================
CREATE TABLE IF NOT EXISTS metrics (
    id TEXT PRIMARY KEY,

    -- Session identifier (from session.id attribute)
    session_id TEXT NOT NULL,

    -- Metric identification
    name TEXT NOT NULL,                  -- e.g., "claude_code.token.usage"

    -- Timestamp (Unix milliseconds)
    timestamp INTEGER NOT NULL,

    -- Metric value
    value REAL NOT NULL,

    -- Dimension attributes (varies by metric type)
    metric_type TEXT,                    -- e.g., "input", "output", "added", "removed"
    model TEXT,                          -- e.g., "claude-sonnet-4-5-20250929"
    tool TEXT,                           -- e.g., "Edit", "Write"
    decision TEXT,                       -- e.g., "accept", "reject"
    language TEXT,                       -- e.g., "TypeScript", "Python"

    -- Standard attributes
    account_uuid TEXT,
    organization_id TEXT,
    terminal_type TEXT,
    app_version TEXT,

    -- Resource attributes (JSON)
    resource TEXT,

    -- Metadata
    received_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_metrics_session_id ON metrics(session_id);
CREATE INDEX IF NOT EXISTS idx_metrics_name ON metrics(name);
CREATE INDEX IF NOT EXISTS idx_metrics_timestamp ON metrics(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_metrics_model ON metrics(model);


-- ============================================
-- events: Stores OTLP log events from Claude Code
-- Events include: user_prompt, tool_result, api_request, api_error, tool_decision
-- ============================================
CREATE TABLE IF NOT EXISTS events (
    id TEXT PRIMARY KEY,

    -- Session identifier
    session_id TEXT NOT NULL,

    -- Event identification
    name TEXT NOT NULL,                  -- e.g., "claude_code.api_request"

    -- Timestamp (Unix milliseconds)
    timestamp INTEGER NOT NULL,

    -- Common fields
    duration_ms INTEGER,
    success INTEGER,                     -- 0 or 1
    error TEXT,

    -- API request/error fields
    model TEXT,
    cost_usd REAL,
    input_tokens INTEGER,
    output_tokens INTEGER,
    cache_read_tokens INTEGER,
    cache_creation_tokens INTEGER,
    status_code INTEGER,
    attempt INTEGER,

    -- Tool fields
    tool_name TEXT,
    tool_decision TEXT,                  -- "accept" or "reject"
    decision_source TEXT,                -- "config", "user_permanent", etc.
    tool_parameters TEXT,                -- JSON string

    -- Prompt fields
    prompt_length INTEGER,
    prompt TEXT,                         -- Usually redacted

    -- Standard attributes
    account_uuid TEXT,
    organization_id TEXT,
    terminal_type TEXT,
    app_version TEXT,

    -- Resource attributes (JSON)
    resource TEXT,

    -- Metadata
    received_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_events_session_id ON events(session_id);
CREATE INDEX IF NOT EXISTS idx_events_name ON events(name);
CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_events_tool_name ON events(tool_name);
CREATE INDEX IF NOT EXISTS idx_events_model ON events(model);


-- ============================================
-- sessions: Aggregated view of sessions from events
-- ============================================
CREATE VIEW IF NOT EXISTS sessions AS
SELECT
    session_id AS id,

    -- Time range
    MIN(timestamp) AS start_time,
    MAX(timestamp) AS end_time,
    MAX(timestamp) - MIN(timestamp) AS duration_ms,

    -- Counts
    COUNT(*) AS event_count,
    COUNT(CASE WHEN name = 'claude_code.api_request' THEN 1 END) AS api_request_count,
    COUNT(CASE WHEN name = 'claude_code.api_error' THEN 1 END) AS error_count,
    COUNT(CASE WHEN name = 'claude_code.tool_result' THEN 1 END) AS tool_use_count,
    COUNT(CASE WHEN name = 'claude_code.user_prompt' THEN 1 END) AS prompt_count,

    -- Totals from api_request events
    COALESCE(SUM(CASE WHEN name = 'claude_code.api_request' THEN cost_usd ELSE 0 END), 0) AS total_cost_usd,
    COALESCE(SUM(CASE WHEN name = 'claude_code.api_request' THEN input_tokens ELSE 0 END), 0) AS total_input_tokens,
    COALESCE(SUM(CASE WHEN name = 'claude_code.api_request' THEN output_tokens ELSE 0 END), 0) AS total_output_tokens,
    COALESCE(SUM(CASE WHEN name = 'claude_code.api_request' THEN cache_read_tokens ELSE 0 END), 0) AS total_cache_read_tokens,

    -- Metadata (take the most recent non-null value)
    MAX(account_uuid) AS account_uuid,
    MAX(organization_id) AS organization_id,
    MAX(terminal_type) AS terminal_type,
    MAX(app_version) AS app_version

FROM events
GROUP BY session_id;
