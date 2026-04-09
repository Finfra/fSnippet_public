#!/bin/bash

# .agent/skills/log-monitor/scripts/setup-log-monitor.sh

# Configuration
TMP_DIR="$HOME/.tmp"
# Get skill root directory (1 level up from scripts)
SKILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Resources are in ../resources relative to the script
KEY_LOGGER_SRC="$SKILL_ROOT/resources/key-code/KeyLogger"
LOG_SRC="$HOME/Documents/finfra/fSnippetData/logs/flog.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔍 Setting up fSnippet Log Monitor Environment...${NC}"

# 1. Create ~/.tmp
if [ ! -d "$TMP_DIR" ]; then
    echo "📂 Creating $TMP_DIR..."
    mkdir -p "$TMP_DIR"
else
    echo "✅ $TMP_DIR exists."
fi

# 2. Copy KeyLogger
if [ -f "$KEY_LOGGER_SRC" ]; then
    cp "$KEY_LOGGER_SRC" "$TMP_DIR/"
    echo "✅ KeyLogger copied to $TMP_DIR"
else
    echo -e "${RED}❌ KeyLogger not found at $KEY_LOGGER_SRC${NC}"
    exit 1
fi

# 3. Link flog.log
if [ -f "$LOG_SRC" ]; then
    ln -sf "$LOG_SRC" "$TMP_DIR/flog.log"
    echo "✅ flog.log symlinked to $TMP_DIR/flog.log"
else
    echo -e "${RED}❌ Source log not found at $LOG_SRC${NC}"
    # Create empty log file to prevent tail errors
    mkdir -p $(dirname "$LOG_SRC")
    touch "$LOG_SRC"
    ln -sf "$LOG_SRC" "$TMP_DIR/flog.log"
    echo -e "${YELLOW}⚠️ Created empty log file at $LOG_SRC and linked.${NC}"
fi

# 4. Check KeyLogger Process
if pgrep -x "KeyLogger" > /dev/null; then
    echo -e "${GREEN}✅ KeyLogger is already running.${NC}"
else
    echo -e "${YELLOW}⚠️ KeyLogger is NOT running.${NC}"
    echo "   Run this in a separate pane:  $TMP_DIR/KeyLogger --only-down"
fi

echo -e "\n${GREEN}🚀 Monitor Environment Ready!${NC}"
echo "---------------------------------------------------"
echo "run following command in new terminal tab:"
echo "---------------------------------------------------"
echo "tail -f ~/.tmp/flog.log"
echo "tail -f /tmp/fkey.log"
echo "---------------------------------------------------"
