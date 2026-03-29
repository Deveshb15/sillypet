#!/bin/bash
# SillyPet hook script for Claude Code
# Installed in ~/.claude/settings.json to forward events to SillyPet
#
# Usage: sillypet-hook.sh <event_type>
# Reads JSON context from stdin (provided by Claude Code hooks)

EVENT_TYPE="$1"
EVENT_DIR="/tmp/sillypet-events"
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

# Write the payload to a temp file, then rename it into place so the app never
# reads a partially-written JSON document.
TIMESTAMP=$(date +%s%N 2>/dev/null || date +%s)
TEMP_FILE="$EVENT_DIR/.${TIMESTAMP}_${EVENT_TYPE}.json.tmp"
EVENT_FILE="$EVENT_DIR/${TIMESTAMP}_${EVENT_TYPE}.json"
printf '{"source":"claude","type":"%s","data":%s,"ts":"%s"}' \
  "$EVENT_TYPE" \
  "$INPUT" \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TEMP_FILE"
mv "$TEMP_FILE" "$EVENT_FILE"

exit 0
