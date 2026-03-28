#!/bin/bash
# OpenPet hook script for Claude Code
# Installed in ~/.claude/settings.json to forward events to OpenPet
#
# Usage: openpet-hook.sh <event_type>
# Reads JSON context from stdin (provided by Claude Code hooks)

EVENT_TYPE="$1"
EVENT_DIR="/tmp/openpet-events"
mkdir -p "$EVENT_DIR"

# Read hook JSON from stdin
INPUT=""
if [ ! -t 0 ]; then
    INPUT=$(cat)
fi

# Default to empty object if no input
if [ -z "$INPUT" ]; then
    INPUT="{}"
fi

# Write event file with timestamp-based unique name
TIMESTAMP=$(date +%s%N 2>/dev/null || date +%s)
EVENT_FILE="$EVENT_DIR/${TIMESTAMP}_${EVENT_TYPE}.json"

cat > "$EVENT_FILE" << EVENTEOF
{"source":"claude","type":"${EVENT_TYPE}","data":${INPUT},"ts":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EVENTEOF

exit 0
