import os
import sys
import re

# Configuration: Map of old pattern to new path (Relative to project root)
# This script assumes it's run from project root or handles paths accordingly.
# For simplicity, we'll scan .md files in specific directories.

PROJECT_ROOT = "."
RULES_DIR = ".agent/rules"

scan_extensions = ['.md']
ignore_dirs = ['.git', '.gemini', 'derived_data', 'build']
target_dirs = ['.', '_doc_design', '_doc_work', '.agent/workflows', '.agent/skills']

def get_active_rules():
    rules = {}
    if not os.path.exists(RULES_DIR):
        print(f"Error: {RULES_DIR} does not exist.")
        return rules
    
    for filename in os.listdir(RULES_DIR):
        if filename.endswith(".md") and filename != "README.md":
            # Assume old file name might be contained in the file content or we map by knowledge
            # For this MVP, we will use a predefined mapping for known legacy files
            # and generic mapping for the rule filename itself.
            rules[filename] = f"{RULES_DIR}/{filename}"
            
    return rules

# Known legacy mappings (FileName -> New Path)
LEGACY_MAPPING = {
    "Issue_RULE.md": ".agent/rules/issue_rules.md",
    "design_SNIPPET.md": ".agent/rules/snippet_rules.md",
    "rule_IMPORT.md": ".agent/rules/import_rules.md",
    "rule_LOGGING.md": ".agent/rules/logging_rules.md",
    "rule_PLACEHOLDER.md": ".agent/rules/placeholder_rules.md"
}

def sync_references():
    print("Starting Rule Reference Sync...")
    
    for root_dir in target_dirs:
        for root, dirs, files in os.walk(os.path.join(PROJECT_ROOT, root_dir)):
            # Filter ignore dirs
            dirs[:] = [d for d in dirs if d not in ignore_dirs]
            
            for file in files:
                if any(file.endswith(ext) for ext in scan_extensions):
                    filepath = os.path.join(root, file)
                    # Skip the rules directory itself to avoid self-reference mess
                    if RULES_DIR in filepath:
                        continue
                        
                    process_file(filepath)

def process_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        new_content = content
        modified = False
        
        # 1. Replace Legacy References
        for old_name, new_path in LEGACY_MAPPING.items():
            # Check for various link formats
            # [text](path/old_name) -> [text](new_path)
            # `path/old_name` -> `new_path`
            
            # Simple text replacement for exact filenames (naive but effective for doc references)
            if old_name in new_content:
                # We need to be careful not to replace if it's already updated, but legacy names are distinct.
                # Regex to match the filename bounded by / or whitespace or quotes
                # Pattern: (Start or / or " or `)(old_name)(End or / or " or `)
                
                # Strategy: Look for instances of old_name that are NOT already part of new_path
                # But since new_path filenames are different (issue_rules vs Issue_RULE), simple replacement works.
                
                replacement = new_path
                
                # Check consistency of relative paths? 
                # For now, we use the root-relative path `.agent/rules/...` which works in most MD viewers if root is set,
                # or we accept that updating to a standard path is better than broken link.
                
                if old_name in new_content:
                     # Avoid replacing if it's just mentioning the old name in a "formerly known as" context?
                     # No, we want to update references.
                     
                     # Special check: If we are in AGENTS.md or similar, we might want absolute or relative.
                     # Defaulting to `.agent/rules/...` style.
                     
                     # Execute replacement
                     # We replace "path/to/old_name" with "new_path" if possible, otherwise just "old_name" -> "new_path"
                     
                     # We will do a generic replace of the filename, aimed at `_doc_design/design_SNIPPET.md` etc.
                     # If the path included directories, replace the whole thing.
                     
                     # Regex for common patterns
                     # 1. _doc_design/design_SNIPPET.md
                     # 2. _doc_work/Issue_RULE.md
                     # 3. just design_SNIPPET.md
                     
                     patterns = [
                        r"(_doc_[a-z]+/)" + re.escape(old_name),
                        re.escape(old_name)
                     ]
                     
                     for pattern in patterns:
                        new_content, count = re.subn(pattern, new_path, new_content)
                        if count > 0:
                            modified = True

        if modified:
            print(f"Updating references in {filepath}")
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
                
    except Exception as e:
        print(f"Error processing {filepath}: {e}")

if __name__ == "__main__":
    sync_references()
