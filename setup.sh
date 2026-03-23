#!/usr/bin/env bash

# Interactive Setup Script for Claude Code Observation Project

# Color codes
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to render an interactive menu using arrow keys
function prompt_menu() {
    local prompt="$1"
    shift
    local options=("$@")
    local cur=0
    local count=${#options[@]}
    local index=0
    
    # Hide cursor
    tput civis
    
    echo -e "${CYAN}${prompt}${NC}"
    
    while true; do
        index=0
        for o in "${options[@]}"; do
            if [ "$index" == "$cur" ]; then
                echo -e " ${GREEN}❯ $o${NC}"
            else
                echo -e "   $o"
            fi
            ((index++))
        done

        # Read key (works on macOS and Linux)
        read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key
            if [[ $key == '[A' ]]; then
                ((cur--))
                if [ $cur -lt 0 ]; then cur=$((count-1)); fi
            elif [[ $key == '[B' ]]; then
                ((cur++))
                if [ $cur -ge $count ]; then cur=0; fi
            fi
        elif [[ $key == "" ]]; then
            break
        fi

        # Clear previous lines
        for ((i=0; i<count; i++)); do
            tput cuu1
            tput el
        done
    done
    
    # Show cursor
    tput cnorm
    return $cur
}

echo -e "${YELLOW}======================================================${NC}"
echo -e "${GREEN}    Claude Code OTel Monitoring - Setup Wizard        ${NC}"
echo -e "${YELLOW}======================================================${NC}"
echo ""

# Check prerequisites
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH.${NC}"
    exit 1
fi

# Step 1: Port Configuration
OTEL_PORT=4319
VM_PORT=8428
GRAFANA_PORT=3001

prompt_menu "How would you like to configure the ports?" "Use Defaults (OTel: 4319, VM: 8428, Grafana: 3001)" "Customize Ports"
CHOICE=$?

if [ $CHOICE -eq 1 ]; then
    echo ""
    read -p "Enter OTel Collector port [$OTEL_PORT]: " input_otel
    OTEL_PORT=${input_otel:-$OTEL_PORT}
    
    read -p "Enter VictoriaMetrics port [$VM_PORT]: " input_vm
    VM_PORT=${input_vm:-$VM_PORT}
    
    read -p "Enter Grafana port [$GRAFANA_PORT]: " input_grafana
    GRAFANA_PORT=${input_grafana:-$GRAFANA_PORT}
fi

# Write to .env
cat <<EOF > .env
OTEL_PORT=$OTEL_PORT
VM_PORT=$VM_PORT
GRAFANA_PORT=$GRAFANA_PORT
EOF

echo -e "\n${GREEN}✔ Ports configured and saved to .env${NC}"

# Step 2: Patch Claude Settings
echo ""
prompt_menu "Do you want to automatically patch ~/.claude/settings.json to send telemetry to localhost:$OTEL_PORT?" "Yes (Recommended)" "No, I'll do it manually"
PATCH_CHOICE=$?

if [ $PATCH_CHOICE -eq 0 ]; then
    SETTINGS_FILE="$HOME/.claude/settings.json"
    
    if [ ! -f "$SETTINGS_FILE" ]; then
        mkdir -p "$HOME/.claude"
        echo "{}" > "$SETTINGS_FILE"
    fi
    
    # Using python to safely update the JSON file
    python3 -c "
import json
import os

filepath = os.path.expanduser('~/.claude/settings.json')
try:
    with open(filepath, 'r') as f:
        data = json.load(f)
except Exception:
    data = {}

if 'env' not in data:
    data['env'] = {}

data['env'].update({
    'CLAUDE_CODE_ENABLE_TELEMETRY': '1',
    'OTEL_EXPORTER_OTLP_ENDPOINT': 'http://localhost:${OTEL_PORT}',
    'OTEL_EXPORTER_OTLP_PROTOCOL': 'http/json',
    'OTEL_METRICS_EXPORTER': 'otlp',
    'OTEL_LOGS_EXPORTER': 'otlp',
    'OTEL_METRICS_EXPORTER_TEMPORALITY_PREFERENCE': 'cumulative',
    'OTEL_METRIC_EXPORT_INTERVAL': '10000',
    'OTEL_LOGS_EXPORT_INTERVAL': '5000'
})

with open(filepath, 'w') as f:
    json.dump(data, f, indent=4)
"
    echo -e "${GREEN}✔ Successfully updated $SETTINGS_FILE${NC}"
    echo -e "${YELLOW}Note: Please restart any active Claude Code sessions for changes to take effect.${NC}"
fi

echo ""
echo -e "${YELLOW}======================================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "To start the monitoring stack, run: ${CYAN}make start${NC}"
echo -e "Grafana will be available at: ${CYAN}http://localhost:$GRAFANA_PORT${NC}"
echo -e "${YELLOW}======================================================${NC}"
