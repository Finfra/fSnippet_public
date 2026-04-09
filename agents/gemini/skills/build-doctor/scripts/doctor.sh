#!/bin/bash

# Configuration
LOG_FILE="$HOME/Documents/finfra/fSnippet/logs/flog.log"

echo "🩺 [Build Doctor] Starting Diagnosis..."

# 1. Check for lingering processes
echo "🔍 Checking for lingering processes..."
PIDS=$(pgrep -f "MacOS/fSnippet")
if [ -n "$PIDS" ]; then
    echo "⚠️  Found lingering fSnippet processes: $PIDS"
    echo "   -> Recommendation: Run 'pkill -f MacOS/fSnippet'"
else
    echo "✅ No lingering processes found."
fi

# 2. Check DerivedData
echo "🔍 Checking DerivedData..."
DD_COUNT=$(find ~/Library/Developer/Xcode/DerivedData -name "fSnippet-*" -maxdepth 1 | wc -l)
if [ "$DD_COUNT" -gt 0 ]; then
    echo "ℹ️  Found $DD_COUNT DerivedData folder(s)."
    echo "   -> If build fails continuously, try removing them: 'rm -rf ~/Library/Developer/Xcode/DerivedData/fSnippet-*'"
else
    echo "✅ No fSnippet DerivedData found (Clean state)."
fi

# 3. Check recent logs (Error detection)
if [ -f "$LOG_FILE" ]; then
    echo "🔍 Checking recent logs (Last 20 lines)..."
    echo "--- LOG START ---"
    tail -n 20 "$LOG_FILE"
    echo "--- LOG END ---"
else
    echo "⚠️  Log file not found at $LOG_FILE"
fi

echo "🩺 [Build Doctor] Diagnosis Complete."
