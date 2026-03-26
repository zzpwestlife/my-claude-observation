#!/usr/bin/env python3
"""
Claude Code Session Viewer
A simple web UI to browse and view Claude Code session details.
"""

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Optional

import streamlit as st

# Configuration
CLAUDE_DIR = Path.home() / ".claude"
PROJECTS_DIR = CLAUDE_DIR / "projects"


def get_session_files(project_path: Optional[str] = None) -> list[dict]:
    """Get all session JSONL files."""
    sessions = []

    if not PROJECTS_DIR.exists():
        return sessions

    # Filter by project if specified
    if project_path:
        project_folder = project_path.replace("/", "-")
        if not project_folder.startswith("-"):
            project_folder = f"-{project_folder}"
        projects = [PROJECTS_DIR / project_folder]
    else:
        projects = [d for d in PROJECTS_DIR.iterdir() if d.is_dir()]

    for project_dir in projects:
        if not project_dir.exists():
            continue

        project_name = project_dir.name.replace("-", "/").lstrip("/")

        for jsonl_file in project_dir.glob("*.jsonl"):
            # Skip subagent files
            if jsonl_file.stem.startswith("agent-"):
                continue

            try:
                meta = parse_session_meta(jsonl_file)
                if meta:
                    meta["project"] = project_name
                    sessions.append(meta)
            except Exception as e:
                st.error(f"Error parsing {jsonl_file}: {e}")

    # Sort by mtime descending
    sessions.sort(key=lambda x: x.get("mtime_ms", 0), reverse=True)
    return sessions


def parse_session_meta(jsonl_path: Path) -> dict:
    """Parse session metadata from JSONL file."""
    meta = {
        "session_id": jsonl_path.stem,
        "file_path": str(jsonl_path),
        "message_count": 0,
        "first_prompt": None,
        "first_timestamp": None,
        "cwd": None,
        "git_branch": None,
        "mtime_ms": 0,
        "model_counts": {},
        "tool_counts": {},
    }

    try:
        meta["mtime_ms"] = int(jsonl_path.stat().st_mtime * 1000)
    except Exception:
        pass

    try:
        with open(jsonl_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue

                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue

                entry_type = record.get("type", "")

                # Skip non-conversational types
                if entry_type in ("file-history-snapshot", "summary", "queue-operation", "last-prompt", "progress", "system"):
                    continue

                meta["message_count"] += 1

                # Extract metadata from first few messages
                if meta["first_timestamp"] is None and "timestamp" in record:
                    meta["first_timestamp"] = record["timestamp"]

                if meta["cwd"] is None and "cwd" in record:
                    meta["cwd"] = record["cwd"]

                if meta["git_branch"] is None and record.get("gitBranch"):
                    meta["git_branch"] = record["gitBranch"]

                # Extract first user prompt
                if entry_type == "user" and meta["first_prompt"] is None:
                    content = record.get("message", {}).get("content", "")
                    if isinstance(content, list):
                        text_parts = [b.get("text", "") for b in content if b.get("type") == "text"]
                        meta["first_prompt"] = " ".join(text_parts)[:200]
                    elif isinstance(content, str):
                        meta["first_prompt"] = content[:200]

                # Count models
                if entry_type == "assistant":
                    model = record.get("model", "unknown")
                    meta["model_counts"][model] = meta["model_counts"].get(model, 0) + 1

                # Count tools
                if entry_type == "tool_use":
                    tool_name = record.get("name", "unknown")
                    meta["tool_counts"][tool_name] = meta["tool_counts"].get(tool_name, 0) + 1

                # Stop after first 20 messages for meta
                if meta["message_count"] >= 20:
                    break
    except Exception as e:
        st.error(f"Error reading {jsonl_path}: {e}")

    return meta


def load_session_detail(jsonl_path: str) -> dict:
    """Load full session details from JSONL file."""
    messages = []

    try:
        with open(jsonl_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue

                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue

                entry_type = record.get("type", "")

                # Skip non-conversational types
                if entry_type in ("file-history-snapshot", "summary", "queue-operation", "last-prompt"):
                    continue

                # Skip progress/system messages for cleaner view
                if entry_type in ("progress", "system"):
                    continue

                messages.append(record)
    except Exception as e:
        st.error(f"Error reading {jsonl_path}: {e}")

    return {"messages": messages, "message_count": len(messages)}


def format_timestamp(ts: str) -> str:
    """Format ISO timestamp to readable string."""
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        return dt.strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        return ts


def render_message(record: dict):
    """Render a single message record."""
    entry_type = record.get("type", "unknown")

    # User message
    if entry_type == "user":
        content = record.get("message", {}).get("content", "")
        if isinstance(content, list):
            text = " ".join([b.get("text", "") for b in content if b.get("type") == "text"])
        elif isinstance(content, str):
            text = content
        else:
            text = str(content)

        with st.chat_message("user"):
            st.write(text or "_(User message)_")
            if record.get("cwd"):
                st.caption(f"📁 {record.get('cwd')} | {format_timestamp(record.get('timestamp', ''))}")

    # Assistant message
    elif entry_type == "assistant":
        content = record.get("message", {}).get("content", [])
        model = record.get("model", "unknown")

        with st.chat_message("assistant", avatar="🤖"):
            for block in content:
                block_type = block.get("type", "text")

                if block_type == "text":
                    st.markdown(block.get("text", ""))

                elif block_type == "thinking":
                    with st.expander("🤔 Assistant's Thinking"):
                        st.code(block.get("thinking", ""), language="text")

                elif block_type == "tool_use":
                    tool_name = block.get("name", "unknown")
                    tool_input = block.get("input", {})
                    tool_id = block.get("id", "")

                    with st.expander(f"🔧 Tool: {tool_name}"):
                        st.json(tool_input)
                        st.caption(f"Tool ID: {tool_id}")

            # Show token usage if available
            usage = record.get("message", {}).get("usage", {})
            if usage:
                cols = st.columns(4)
                cols[0].metric("Input Tokens", f"{usage.get('input_tokens', 0):,}")
                cols[1].metric("Output Tokens", f"{usage.get('output_tokens', 0):,}")
                cols[2].metric("Cache Read", f"{usage.get('cache_read_input_tokens', 0):,}")
                cols[3].metric("Cache Create", f"{usage.get('cache_creation_input_tokens', 0):,}")

            st.caption(f"Model: {model} | {format_timestamp(record.get('timestamp', ''))}")

    # Tool use result
    elif entry_type == "tool_use":
        tool_name = record.get("name", "unknown")
        result = record.get("result", {})

        with st.expander(f"🛠️ Tool Result: {tool_name}", expanded=False):
            st.json(result)

    # Hook progress
    elif entry_type == "progress":
        hook_event = record.get("data", {}).get("hookEvent", "unknown")
        hook_name = record.get("data", {}).get("hookName", "unknown")

        with st.container():
            st.caption(f"⚙️ Hook: {hook_name} ({hook_event}) | {format_timestamp(record.get('timestamp', ''))}")

    # System messages
    elif entry_type == "system":
        subtype = record.get("subtype", "system")
        with st.container():
            st.caption(f"ℹ️ System: {subtype} | {format_timestamp(record.get('timestamp', ''))}")


def main():
    st.set_page_config(
        page_title="Claude Code Session Viewer",
        page_icon="📝",
        layout="wide",
    )

    st.title("📝 Claude Code Session Viewer")

    # Sidebar for session selection
    with st.sidebar:
        st.header("Select Session")

        # Project filter
        projects = ["All Projects"]
        if PROJECTS_DIR.exists():
            projects.extend([d.name.replace("-", "/").lstrip("/") for d in PROJECTS_DIR.iterdir() if d.is_dir()])

        selected_project = st.selectbox("Project", projects)
        project_filter = None if selected_project == "All Projects" else selected_project

        # Load sessions
        sessions = get_session_files(project_filter)

        if not sessions:
            st.warning("No sessions found")
            return

        # Session selector
        session_options = [
            f"{s.get('first_prompt', 'Untitled')[:50]}... ({s.get('message_count', 0)} msgs)"
            for s in sessions
        ]
        selected_idx = st.selectbox("Session", session_options)

        if not selected_idx:
            return

        selected_session = sessions[session_options.index(selected_idx)]

        # Show session preview
        with st.expander("📊 Session Preview", expanded=True):
            st.write(f"**Project:** {selected_session.get('project', 'Unknown')}")
            st.write(f"**Session ID:** `{selected_session.get('session_id')}`")
            st.write(f"**Messages:** {selected_session.get('message_count', 0)}")
            st.write(f"**Started:** {format_timestamp(selected_session.get('first_timestamp', ''))}")
            st.write(f"**CWD:** {selected_session.get('cwd', 'Unknown')}")
            st.write(f"**Branch:** {selected_session.get('git_branch', 'N/A')}")

            if selected_session.get("model_counts"):
                st.write("**Models:**")
                for model, count in selected_session.get("model_counts", {}).items():
                    st.write(f"- {model}: {count}")

    # Main content area
    if selected_session:
        # Header
        st.header(selected_session.get("first_prompt", "Untitled Session") or "Untitled Session")

        # Stats row
        cols = st.columns(4)
        cols[0].metric("Messages", selected_session.get("message_count", 0))
        cols[1].metric("Project", selected_session.get("project", "Unknown")[:20] + "...")
        cols[2].metric("Git Branch", selected_session.get("git_branch", "N/A"))
        cols[3].metric("Started", format_timestamp(selected_session.get("first_timestamp", ""))[:16])

        # Load and display full session
        st.divider()
        st.subheader("💬 Conversation")

        session_data = load_session_detail(selected_session.get("file_path", ""))

        for msg in session_data.get("messages", []):
            render_message(msg)


if __name__ == "__main__":
    main()
