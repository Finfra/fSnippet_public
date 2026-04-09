#!/bin/bash

# Configuration
SKILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SKILL_ROOT/../../.." && pwd)"
ISSUE_FILE="$PROJECT_ROOT/Issue.md"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

function show_help() {
    echo "Usage: $0 [command] [args]"
    echo ""
    echo "Commands:"
    echo "  status            Run git status"
    echo "  add [file]        Run git add (default: .)"
    echo "  commit \"msg\"      Run git commit -m \"msg\""
    echo "  pull              Run git pull"
    echo "  push              Run git push (verifies Save Point in Issue.md)"
    echo "  auto \"msg\"        Run status, add, commit, and push sequence"
    echo "  all \"msg\"         Same as auto (run all steps)"
    echo "  help              Show this help message"
    echo ""
}

function check_save_point() {
    echo -e "${YELLOW}🔍 Verifying Save Point...${NC}"
    
    # Get current commit hash (short)
    CURRENT_HASH=$(git rev-parse --short HEAD)
    
    # Check if hash exists in Issue.md
    if grep -q "$CURRENT_HASH" "$ISSUE_FILE"; then
        echo -e "${GREEN}✅ Save Point Verified: Commit $CURRENT_HASH check found in Issue.md${NC}"
        return 0
    else
        echo -e "${RED}❌ Save Point Missing!${NC}"
        echo -e "Current Commit: $CURRENT_HASH"
        echo -e "This commit hash was NOT found in Issue.md."
        echo -e "Please update Issue.md with the current commit hash before pushing."
        return 1
    fi
}

if [ "$#" -eq 0 ]; then
    show_help
    exit 1
fi

COMMAND="$1"

cd "$PROJECT_ROOT" || exit 1

case "$COMMAND" in
    status)
        echo -e "${GREEN}Running git status...${NC}"
        git status
        ;;
    add)
        TARGET="${2:-.}"
        echo -e "${GREEN}Running git add $TARGET...${NC}"
        git add "$TARGET"
        ;;
    commit)
        MSG="$2"
        if [ -z "$MSG" ]; then
            echo -e "${RED}Error: Commit message required.${NC}"
            echo "Usage: $0 commit \"message\""
            exit 1
        fi
        echo -e "${GREEN}Running git commit...${NC}"
        git commit -m "$MSG"
        git commit -m "$MSG"
        ;;
    pull)
        echo -e "${GREEN}Running git pull...${NC}"
        git pull
        ;;
    push)
        if check_save_point; then
            echo -e "${GREEN}Running git push...${NC}"
            git push
        else
            echo -e "${RED}Push aborted due to missing Save Point.${NC}"
            exit 1
        fi
        ;;
    auto|all)
        MSG="$2"
        if [ -z "$MSG" ]; then
            echo -e "${RED}Error: Commit message required for auto mode.${NC}"
            exit 1
        fi
        
        TARGET="${3:-.}"
        
        echo -e "${GREEN}[1/4] Status...${NC}"
        git status
        
        echo -e "${GREEN}[2/4] Add $TARGET...${NC}"
        git add $TARGET
        
        echo -e "${GREEN}[3/4] Commit...${NC}"
        git commit -m "$MSG"
        
        echo -e "${GREEN}[4/4] Push...${NC}"
        if check_save_point; then
            git push
        else
            echo -e "${RED}Push aborted due to missing Save Point.${NC}"
            exit 1
        fi
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
