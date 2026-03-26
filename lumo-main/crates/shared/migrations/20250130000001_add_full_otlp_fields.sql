-- Events: add full OTLP storage fields
ALTER TABLE events ADD COLUMN user_id TEXT;
ALTER TABLE events ADD COLUMN user_email TEXT;
ALTER TABLE events ADD COLUMN event_sequence INTEGER;
ALTER TABLE events ADD COLUMN tool_result_size_bytes INTEGER;

-- Metrics: add full OTLP storage fields
ALTER TABLE metrics ADD COLUMN user_id TEXT;
ALTER TABLE metrics ADD COLUMN user_email TEXT;
ALTER TABLE metrics ADD COLUMN unit TEXT;
ALTER TABLE metrics ADD COLUMN description TEXT;
