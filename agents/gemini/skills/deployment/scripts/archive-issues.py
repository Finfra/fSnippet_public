import argparse
import os
import sys
import re
from datetime import datetime

def read_file(filepath):
    if not os.path.exists(filepath):
        print(f"Error: File not found: {filepath}")
        sys.exit(1)
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.readlines()

def write_file(filepath, lines):
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(lines)

def archive_issues(args):
    issue_lines = read_file(args.issue_file)
    old_issue_lines = read_file(args.old_issue_file) if os.path.exists(args.old_issue_file) else []

    # Find "✅ 완료" section
    completed_section_idx = -1
    next_section_idx = -1
    
    for i, line in enumerate(issue_lines):
        if line.strip().startswith("# ✅ 완료"):
            completed_section_idx = i
            # Find next section (lines starting with # or ## but NOT sub-issues of completed ones if any... 
            # actually usually top level sections are #. 
            # The structure in Issue.md:
            # # ✅ 완료
            # ## Issue...
            # # ⏸️ 보류
            # So we look for next # 
            
            for j in range(i + 1, len(issue_lines)):
                if issue_lines[j].startswith("# "):
                    next_section_idx = j
                    break
            if next_section_idx == -1:
                next_section_idx = len(issue_lines)
            break
            
    if completed_section_idx == -1:
        print("Warning: '✅ 완료' section not found in Issue.md")
        return

    # Extract content
    # completed_section_idx points to the header line. Content starts after.
    content_start = completed_section_idx + 1
    content_end = next_section_idx
    
    issues_to_archive = issue_lines[content_start:content_end]
    
    # Filter out empty lines? No, keep format.
    # Check if there are actual issues
    has_issues = any(line.strip().startswith("##") for line in issues_to_archive)
    
    if not has_issues:
        print("No completed issues to archive.")
        return

    # Prepare Archive Block
    header = f"# v{args.version} Release\n"
    # Or maybe "# Version .72 (Date) (Released)" style?
    # User Issue.md example: "## Version .72 (2026.02.01) (Released)"
    # But issue_OLD.md example: "# v.72 Release" (H1)
    # Let's match issue_OLD.md existing style if possible, or establish a standard.
    # issue_OLD.md line 1: "# v.72 Release"
    # So I will use "# v.72 Release" format.
    
    archive_block = [f"# v{args.version} Release\n"] + issues_to_archive + ["\n"]
    
    # Prepend to issue_OLD.md
    # Assuming issue_OLD.md exists.
    new_old_lines = archive_block + old_issue_lines
    write_file(args.old_issue_file, new_old_lines)
    print(f"Archived issues to {args.old_issue_file}")

    # Remove from Issue.md
    del issue_lines[content_start:content_end]
    # Insert a blank line to keep spacing if needed, or leave empty
    issue_lines.insert(content_start, "\n")
    
    write_file(args.issue_file, issue_lines)
    print(f"Cleared completed issues from {args.issue_file}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Archive completed issues")
    parser.add_argument("--version", required=True, help="Release version (e.g. .73)")
    parser.add_argument("--date", required=True, help="Release date")
    parser.add_argument("--issue-file", required=True, help="Path to Issue.md")
    parser.add_argument("--old-issue-file", required=True, help="Path to Issue_OLD.md")
    
    args = parser.parse_args()
    archive_issues(args)
