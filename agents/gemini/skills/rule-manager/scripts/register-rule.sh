#!/bin/bash
# register_rule.sh
# Usage: ./register_rule.sh [source_file] [rule_name]
# Example: ./register_rule.sh _doc/new_rule.md my_new_rule

SOURCE_FILE=$1
RULE_NAME=$2
RULES_DIR=".agent/rules"
README_FILE="$RULES_DIR/README.md"

if [ -z "$SOURCE_FILE" ] || [ -z "$RULE_NAME" ]; then
  echo "Usage: $0 [source_file] [rule_name_without_extension]"
  exit 1
fi

if [ ! -f "$SOURCE_FILE" ]; then
  echo "Error: Source file '$SOURCE_FILE' not found."
  exit 1
fi

TARGET_FILE="$RULES_DIR/${RULE_NAME}.md"

# Copy file
cp "$SOURCE_FILE" "$TARGET_FILE"
echo "Registered rule: $TARGET_FILE"

# Update README if not exists
if ! grep -q "\[${RULE_NAME}.md\]" "$README_FILE"; then
  echo "- **[${RULE_NAME}.md](${RULE_NAME}.md)**: Rule from $SOURCE_FILE" >> "$README_FILE"
  echo "Updated $README_FILE"
else
  echo "Rule already listed in README."
fi
