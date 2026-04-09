#!/bin/bash
# monitor.sh
# fSnippet Log Monitoring Script
# Functions: Startup Log Extraction, Snippet Verification, Spam Analysis

LOG_FILE="$HOME/Documents/finfra/fSnippetData/logs/flog.log"

if [ ! -f "$LOG_FILE" ]; then
    echo "❌ Error: Log file not found at $LOG_FILE"
    exit 1
fi

echo "======================================================================"
echo "📊 fSnippet Log Monitor"
echo "======================================================================"
echo ""

# 1. Startup Log Extraction
echo "🚀 [Startup Sequence]"
echo "----------------------------------------------------------------------"
# Extract logs from the last "AppActivationMonitor" (which usually signals startup/activation)
# to "abbreviation 활성화됨" (snippet loading complete) or "AppInitializer"
# Using tac to find the LAST occurrence efficiently, then printing forward.

# Strategy: Find the line number of the last "AppActivationMonitor"
LAST_START_LINE=$(grep -n "AppActivationMonitor" "$LOG_FILE" | tail -n 1 | cut -d: -f1)

if [ -z "$LAST_START_LINE" ]; then
    echo "⚠️  No startup sequence found in current logs."
else
    # Read from that line to the end, but stop at "abbreviation 활성화됨" or print a reasonable chunk
    # We will print the next 20 lines or until explicit success message
    tail -n "+$LAST_START_LINE" "$LOG_FILE" | awk '
    /AppActivationMonitor/ { print; recording=1; next }
    recording == 1 { print }
    /abbreviation 활성화됨/ { exit }
    /setupInitialState/ { exit } 
    ' | head -n 30
fi
echo "----------------------------------------------------------------------"
echo ""

# 2. Snippet Verification
echo "✅ [Snippet Verification]"
echo "----------------------------------------------------------------------"
# Check for successful snippet triggers
SNIPPET_COUNT=$(grep -c -E "replaceTextSync|스니펫 매칭 성공" "$LOG_FILE")
LAST_SNIPPET=$(grep -E "replaceTextSync|스니펫 매칭 성공" "$LOG_FILE" | tail -n 1)

if [ "$SNIPPET_COUNT" -eq 0 ]; then
    echo "ℹ️  No snippets triggered yet."
else
    echo "🔢 Total Snippets Triggered: $SNIPPET_COUNT"
    echo "🕒 Last Trigger:"
    echo "$LAST_SNIPPET"
fi
echo "----------------------------------------------------------------------"
echo ""

# 3. Spam Analysis
echo "🧹 [Spam Analysis (Top 5 Repeated Lines in last 1000 logs)]"
echo "----------------------------------------------------------------------"
# Tail 1000 -> Remove Timestamp (usually [YYYY-MM-DD HH:mm:ss.SSS]) -> Sort -> Uniq Count -> Sort Desc -> Head
tail -n 1000 "$LOG_FILE" | \
sed -E 's/^\[[0-9-]{10} [0-9:.]+\].*INFO: //g' | \
sed -E 's/^\[[0-9-]{10} [0-9:.]+\].*DEBUG: //g' | \
sed -E 's/^\[[0-9-]{10} [0-9:.]+\].*WARNING: //g' | \
sort | uniq -c | sort -nr | head -n 5
echo "----------------------------------------------------------------------"

echo ""
echo "💡 Tip: Run 'tail -f $LOG_FILE' for real-time monitoring."
