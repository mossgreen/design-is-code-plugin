#!/bin/bash
# Token tracking hook for DisC skill.
# Handles both PreToolUse (bookmark) and Stop (report).

INPUT=$(cat)
EVENT=$(echo "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | head -1 | cut -d'"' -f4)
SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | cut -d'"' -f4)
TRANSCRIPT=$(echo "$INPUT" | grep -o '"transcript_path":"[^"]*"' | head -1 | cut -d'"' -f4)
BOOKMARK="/tmp/disc-token-bookmark-${SESSION_ID}"

if [ "$EVENT" = "PreToolUse" ]; then
  # Record bookmark on first tool call only
  if [ ! -f "$BOOKMARK" ]; then
    LINE_COUNT=$(wc -l < "$TRANSCRIPT" 2>/dev/null | tr -d ' ')
    if [ -n "$LINE_COUNT" ] && [ "$LINE_COUNT" -gt 0 ]; then
      printf '%s\n%s\n' "$TRANSCRIPT" "$LINE_COUNT" > "$BOOKMARK"
    fi
  fi
  exit 0

elif [ "$EVENT" = "Stop" ]; then
  if [ -f "$BOOKMARK" ]; then
    T_PATH=$(sed -n '1p' "$BOOKMARK")
    T_LINE=$(sed -n '2p' "$BOOKMARK")
    rm -f "$BOOKMARK"

    INPUT_T=$(tail -n +"$T_LINE" "$T_PATH" 2>/dev/null \
      | grep -o '"input_tokens":[0-9]*' | awk -F: '{s+=$2} END {print s+0}')
    OUTPUT_T=$(tail -n +"$T_LINE" "$T_PATH" 2>/dev/null \
      | grep -o '"output_tokens":[0-9]*' | awk -F: '{s+=$2} END {print s+0}')
    CACHE_T=$(tail -n +"$T_LINE" "$T_PATH" 2>/dev/null \
      | grep -o '"cache_read_input_tokens":[0-9]*' | awk -F: '{s+=$2} END {print s+0}')
    TOTAL=$((INPUT_T + OUTPUT_T + CACHE_T))

    cat >&2 <<EOF
Token usage (this skill execution only):
  Input tokens:       ${INPUT_T}
  Output tokens:      ${OUTPUT_T}
  Cache read tokens:  ${CACHE_T}
  Total tokens:       ${TOTAL}
Include this token usage in your final report.
EOF
    exit 2  # Prevent stop — Claude sees stderr, presents report, then stops on next attempt
  fi
  exit 0  # No bookmark = post-report stop, allow it
fi

exit 0
