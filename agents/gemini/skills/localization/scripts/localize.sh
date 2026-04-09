#!/bin/bash

# Configuration
SKILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON_DIR="$SKILL_ROOT/scripts/python"
PROJECT_ROOT="$(cd "$SKILL_ROOT/../../.." && pwd)"

# Colors
GREEN='\033[0;32m'
NC='\033[0m' # No Color

function show_help() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  extract            Convert xcstrings to .strings (xcstrings-to-strings.py)"
    echo "  translate          Translate general UI strings (translate-all-strings.py)"
    echo "  translate-settings Translate Settings UI strings (translate-settings-strings.py)"
    echo "  help               Show this help message"
    echo ""
}

if [ "$#" -eq 0 ]; then
    show_help
    exit 1
fi

COMMAND="$1"

cd "$PROJECT_ROOT" || exit 1

case "$COMMAND" in
    extract)
        echo -e "${GREEN}Running xcstrings extraction...${NC}"
        python3 "$PYTHON_DIR/xcstrings-to-strings.py"
        ;;
    translate)
        echo -e "${GREEN}Running general translation...${NC}"
        python3 "$PYTHON_DIR/translate-all-strings.py"
        ;;
    translate-settings)
        echo -e "${GREEN}Running settings translation...${NC}"
        python3 "$PYTHON_DIR/translate-settings-strings.py"
        ;;
    help)
        show_help
        ;;
    *)
        echo "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac
