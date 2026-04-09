import argparse
import re
import datetime
import sys
import os
import unicodedata

def parse_arguments():
    parser = argparse.ArgumentParser(description="Issue Manager for fSnippet")

    subparsers = parser.add_subparsers(dest="command", required=True)

    # Register Command
    register_parser = subparsers.add_parser("register", help="Register a new issue")
    register_parser.add_argument("--title", required=True, help="Title of the issue")
    register_parser.add_argument("--type", choices=["candidate", "general", "important", "critical", "normal", "optional"], default="normal", help="Section to add the issue to")
    register_parser.add_argument("--file", default="Issue.md", help="Target issue file")
    register_parser.add_argument("--parent-id", help="Parent Issue ID for sub-issues (e.g., Issue392)")
    register_parser.add_argument("--purpose", default="", help="Purpose of the issue")
    register_parser.add_argument("--detail", default="", help="Detailed description of the issue")

    # Close Command
    close_parser = subparsers.add_parser("close", help="Close an issue")
    close_parser.add_argument("--id", required=True, help="Issue ID (e.g., Issue387 or CL090)")
    close_parser.add_argument("--hash", required=True, help="Commit hash")
    close_parser.add_argument("--file", default="Issue.md", help="Target issue file")

    # Link Command
    link_parser = subparsers.add_parser("link", help="Link an artifact to an issue")
    link_parser.add_argument("--id", required=True, help="Issue ID (e.g., Issue387)")
    link_parser.add_argument("--url", required=True, help="URL or Path to the artifact")
    link_parser.add_argument("--title", default="Walkthrough", help="Title of the link")
    link_parser.add_argument("--file", default="Issue.md", help="Target issue file")

    # Sync Command
    sync_parser = subparsers.add_parser("sync", help="Synchronize HWM and Issue structure")
    sync_parser.add_argument("--file", default="Issue.md", help="Target issue file")

    # Savepoint Command
    savepoint_parser = subparsers.add_parser("savepoint", help="Update Save Point")
    savepoint_parser.add_argument("--hash", required=True, help="Commit hash")
    savepoint_parser.add_argument("--msg", default="Update", help="Commit message or description")
    savepoint_parser.add_argument("--file", default="Issue.md", help="Target issue file")

    return parser.parse_args()

def update_save_point(args):
    lines = read_file(args.file)
    today = datetime.datetime.now().strftime("%Y.%m.%d")
    
    # 1. Find Save Point Header
    header_idx = -1
    for i, line in enumerate(lines):
        if line.strip().startswith("* Save Point :"):
            header_idx = i
            break
            
    if header_idx == -1:
        print(f"Error: 'Save Point' section not found in {args.file}.")
        sys.exit(1)
        
    # 2. Insert New Save Point
    # Format:       - 2026.02.14: 5b6608a5 (Docs: Update Issue Candidates and Status)
    new_line = f"      - {today}: {args.hash} ({args.msg})\n"
    
    lines.insert(header_idx + 1, new_line)
    
    write_file(args.file, lines)
    print(f"Successfully added save point: {today}: {args.hash} ({args.msg})")

def sync_issues(args):
    lines = read_file(args.file)
    prefix = determine_prefix(args.file)
    # get_hwm modifies lines in-place if auto-corrected
    true_hwm, hwm_line_idx, label = get_hwm(lines, prefix)
    
    if hwm_line_idx != -1:
        write_file(args.file, lines)
        print(f"Successfully synced {args.file}. HWM is now {true_hwm}.")
    else:
        print(f"Error: Could not find HWM in {args.file}.")

def read_file(filepath):
    if not os.path.exists(filepath):
        print(f"Error: File not found: {filepath}")
        sys.exit(1)
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.readlines()

def write_file(filepath, lines):
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(lines)

def get_hwm(lines, prefix="Issue"):
    # 1. Find the Header Line
    header_val = 0
    header_idx = -1
    header_label = "Issue HWM"
    
    for i, line in enumerate(lines):
        match = re.search(r'(Issue HWM|Max CL Issue Num):\s*(\d+)', line)
        if match:
            header_val = int(match.group(2))
            header_idx = i
            header_label = match.group(1)
            break
            
    # 2. Scan content for actual max ID
    # 2. Scan content for actual max ID
    max_id = 0
    # Pattern: Issue123 or CL123 (excluding sub-issues like Issue123_4)
    # Be careful not to match Issue123_4 as 123
    # Fix: Only scan HEADERS to avoid matching text in descriptions (e.g. "See Issue500")
    # Using (?!_) to ensure we don't match parents of sub-issues.
    pattern = re.compile(rf'^#{{2,3}}\s+{prefix}(\d+)(?!_)\b', re.MULTILINE)
    
    for line in lines:
        for match in pattern.finditer(line):
            val = int(match.group(1)) # Group 1 is the digits
            if val > max_id:
                max_id = val
                
    # 3. Determine True HWM (Max of Header and Scanned)
    true_hwm = max(header_val, max_id)
    
    # 4. Auto-Correction (Update line in memory if needed)
    if header_idx != -1 and true_hwm > header_val:
        print(f"Warning: Header HWM ({header_val}) is lower than actual Max ID ({max_id}). Auto-correcting to {true_hwm}.")
        lines[header_idx] = f"* {header_label}: {true_hwm}\n"
        
    return true_hwm, header_idx, header_label

def determine_prefix(filename):
    if "clipboard" in filename.lower():
        return "CL"
    return "Issue"

def find_section_index(lines, section_header):
    # section_header example: "# 🌱 이슈후보"
    for i, line in enumerate(lines):
        if line.strip().startswith(section_header):
            return i
    return -1

def register_issue(args):
    lines = read_file(args.file)
    prefix = determine_prefix(args.file)
    current_hwm, hwm_line_idx, label = get_hwm(lines, prefix)
    
    if hwm_line_idx == -1:
        print("Error: Could not find HWM header in file.")
        sys.exit(1)

    # ---------------------------------------------------------
    # Rule Enforcement: Korean Language Check (Rule 1)
    # ---------------------------------------------------------
    def has_korean(text):
        # Check for Hangul characters (Syllables, Jamo, Compatibility Jamo)
        return bool(re.search(r'[\uAC00-\uD7A3\u1100-\u11FF\u3130-\u318F]', text))

    # Validate Title
    if not has_korean(args.title):
        print(f"❌ [Rule Violation] Title must contain Korean characters.")
        print(f"   Input: {args.title}")
        print("   Reason: Project language rule requires Korean for Issue Titles.")
        sys.exit(1)

    # Validate Purpose (if provided)
    if args.purpose and not has_korean(args.purpose):
        print(f"❌ [Rule Violation] Purpose must contain Korean characters.")
        print(f"   Input: {args.purpose}")
        sys.exit(1)

    # Validate Detail (if provided)
    if args.detail and not has_korean(args.detail):
        print(f"❌ [Rule Violation] Detail must contain Korean characters.")
        print(f"   Input: {args.detail}")
        sys.exit(1)
    # ---------------------------------------------------------

    new_issue_id = ""

    # Check for Duplicate Title
    for line in lines:
        if args.title in line:
            # Check if it's an issue line (starts with #)
            if re.match(rf'^#{{2,3}}\s+{prefix}\d+', line.strip()) and args.title in line:
                 print(f"⚠️  Warning: Issue with title '{args.title}' already exists.")
                 print(f"   Found: {line.strip()}")
                 print("   Aborting registration to prevent duplicates. Use a different title if intended.")
                 sys.exit(1)
    
    if args.parent_id:
        parent_id = args.parent_id
        max_suffix = 0
        # Support both ## and ### for sub-issues, and be flexible with spaces
        pattern = re.compile(rf'^#{{2,3}}\s+{re.escape(parent_id)}_(\d+)', re.MULTILINE)
        
        for line in lines:
            match = pattern.search(line)
            if match:
                suffix = int(match.group(1))
                if suffix > max_suffix:
                    max_suffix = suffix
        
        new_suffix = max_suffix + 1
        new_issue_id = f"{parent_id}_{new_suffix}"
        # Do NOT update HWM for sub-issues
        
    else:
        new_id_num = current_hwm + 1
        new_issue_id = f"{prefix}{new_id_num:02d}" if prefix == "CL" else f"{prefix}{new_id_num}"
        
        # Update HWM
        lines[hwm_line_idx] = f"* {label}: {new_id_num}\n"

    # Determine Insertion Point and Header Level
    insertion_idx = -1
    header_level = "##"
    
    if args.parent_id:
        parent_id = args.parent_id
        
        # Check if Parent is Closed (Optimized Check)
        parent_is_closed = False
        done_section_idx = find_section_index(lines, "# ✅ 완료")
        
        # Locate Parent Index
        parent_idx = -1
        for i, line in enumerate(lines):
             if line.strip().startswith(f"## {parent_id}"):
                 parent_idx = i
                 break
        
        if parent_idx == -1:
            print(f"Error: Parent issue {parent_id} not found.")
            sys.exit(1)
            
        if done_section_idx != -1 and parent_idx > done_section_idx:
            parent_is_closed = True
            
        if parent_is_closed:
            print(f"Info: Parent {parent_id} is Closed. Registering sub-issue as active standalone.")
            # Treat as Normal Issue Insertion (Target Section)
            section_map = {
                "candidate": "# 🌱 이슈후보",
                "general": "# 📙 일반",
                "important": "# 📕 중요",
                "critical": "# 📕 중요",
                "normal": "# 📙 일반",
                "optional": "# 📘 선택"
            }
            target_section = section_map.get(args.type)
            section_idx = find_section_index(lines, target_section)

            if section_idx == -1:
                print(f"Error: Section '{target_section}' not found.")
                sys.exit(1)
                
            insertion_idx = section_idx + 1
            header_level = "##"
        else:
            # Parent is Active: Insert after it (and its current sub-issues)
            header_level = "###"
            # Start scanning from parent_idx to find the end of this issue block
            scan_idx = parent_idx + 1
            while scan_idx < len(lines):
                s_line = lines[scan_idx].strip()
                if s_line.startswith("# ") or s_line.startswith("## "):
                    insertion_idx = scan_idx
                    break
                scan_idx += 1
            
            if insertion_idx == -1: # End of file case
                insertion_idx = len(lines)
    else:
        # Normal Issue Insertion
        section_map = {
            "candidate": "# 🌱 이슈후보",
            "general": "# 📙 일반",
            "important": "# 📕 중요",
            "critical": "# 📕 중요",
            "normal": "# 📙 일반",
            "optional": "# 📘 선택"
        }
        target_section = section_map.get(args.type)
        section_idx = find_section_index(lines, target_section)

        if section_idx == -1:
            print(f"Error: Section '{target_section}' not found.")
            sys.exit(1)
            
        insertion_idx = section_idx + 1
        header_level = "##"

    # Prepare Entry
    today = datetime.datetime.now().strftime("%Y.%m.%d")
    entry = []
    entry.append(f"{header_level} {new_issue_id}: {args.title} (등록: {today})\n")
    
    purpose_content = args.purpose.replace("\\n", "\n") if args.purpose else ""
    detail_content = args.detail.replace("\\n", "\n") if args.detail else ""

    if purpose_content:
        entry.append(f"* 목적: {purpose_content}\n")
    else:
        entry.append(f"* 목적: \n")
        
    if detail_content:
        # Check if detail content starts with a newline or indentation, otherwise ensure it looks good
        if not detail_content.startswith("\n") and not detail_content.startswith(" "):
             pass
        if "\n" in detail_content or detail_content.startswith("-"):
             entry.append(f"* 상세: \n{detail_content}\n")
        else:
             entry.append(f"* 상세: {detail_content}\n")
    else:
        entry.append(f"* 상세: \n")

    entry.append(f"\n")


    for line in reversed(entry):
        lines.insert(insertion_idx, line)

    write_file(args.file, lines)
    print(f"Successfully registered {new_issue_id} in {args.file}")

def close_issue(args):
    print(f"DEBUG: Starting close_issue for {args.id}")
    lines = read_file(args.file)
    issue_id = args.id
    commit_hash = args.hash

    # Determine if it's a sub-issue
    sub_match = re.search(r'^(Issue|CL)(\d+)_(\d+)$', issue_id)
    is_sub_issue = bool(sub_match)
    
    # Find the issue block logic
    start_idx = -1
    for i, line in enumerate(lines):
        # Support both ## and ### for finding the issue
        if line.strip().startswith(f"## {issue_id}") or line.strip().startswith(f"### {issue_id}"):
            start_idx = i
            break
            
    if start_idx == -1:
        print(f"Error: Issue {issue_id} not found.")
        sys.exit(1)

    # Validate Content before Closing
    # Check if '목적' and '상세' are filled
    # We need to find the block first to validate it
    end_idx = -1
    for k in range(start_idx + 1, len(lines)):
        if lines[k].startswith("# ") or lines[k].startswith("## "):
            end_idx = k
            break
    if end_idx == -1: end_idx = len(lines)
    
    block_lines = lines[start_idx:end_idx]
    full_text = "".join(block_lines)

    print(f"DEBUG: Block lines count: {len(block_lines)}")

    has_purpose = False
    has_detail = False


    for i, line in enumerate(block_lines):
        stripped = unicodedata.normalize('NFC', line.strip())
        
        if stripped.startswith("* 목적:"):
            if len(stripped) > 5:
                has_purpose = True
            # Check next line for content if current line is empty
            elif i + 1 < len(block_lines) and block_lines[i+1].strip() and not block_lines[i+1].strip().startswith("*"):
                has_purpose = True
                
        if stripped.startswith("* 상세:"):
            if len(stripped) > 5:
                has_detail = True
            # Check next line for content if current line is empty
            elif i + 1 < len(block_lines) and block_lines[i+1].strip() and not block_lines[i+1].strip().startswith("*"):
                has_detail = True
        # Strict check? Users might hate it.
        # But the user specifically asked for it. 
        # "이슈 516내용 비어 있음. 다음 부터 이런일 없도록 워크플로우 업데이트."
    
    if not has_purpose or not has_detail:
        print(f"⚠️  Warning: Issue {issue_id} seems to have empty 'Purpose' or 'Detail'.")
        if not has_purpose: print("   - Missing '목적' (Purpose)")
        if not has_detail: print("   - Missing '상세' (Detail)")
        print("   Aborting close operation. Please fill in the issue details first.")

        sys.exit(1)

    # Update title line in-place first
    title_line = lines[start_idx].strip()
    if "✅" not in title_line:
        lines[start_idx] = f"{title_line} (✅ 완료, {commit_hash}) ✅\n"
    else:
        # Check if hash is already there to avoid dup
        if commit_hash not in title_line:
             lines[start_idx] = title_line.replace("✅\n", "").replace("✅", "") + f"({commit_hash}) ✅\n"

    # Save immediately to reflect title change
    write_file(args.file, lines)
    
    # Logic Change: Issue466+
    # Sub-issues are marked done in-place. They are NOT moved individually.
    # They move to "Completed" ONLY when the Parent is closed.
    if is_sub_issue:
        print(f"Successfully marked sub-issue {issue_id} as complete.")
        print("Note: Sub-issues remain in place until the Parent Issue is closed.")
        return

    # Parent Issue (Top Level): Move the entire block (including children)
    
    # Calculate end_idx for the normal issue block
    # Calculate end_idx for the normal issue block
    end_idx = -1
    
    # Pre-calculate parent base ID for comparison
    # e.g. Issue502 -> Issue502, CL90 -> CL90
    parent_base_match = re.match(r'^(Issue|CL)(\d+)', issue_id)
    parent_base = parent_base_match.group(0) if parent_base_match else issue_id

    for k in range(start_idx + 1, len(lines)):
        line = lines[k]
        stripped = line.strip()
        
        # Stop at main sections (H1)
        if stripped.startswith("# "):
            end_idx = k
            break
            
        # Check H2 headers
        if stripped.startswith("## "):
            # We found another issue. Check if it is a sub-issue of the current parent.
            # Regex to capture ID from line: ## Issue502_1: ...
            match = re.search(r'^##\s+((Issue|CL)(\d+)(_(\d+))?)', stripped)
            if match:
                found_full_id = match.group(1) # Issue502_1
                found_base_id = match.group(2) + match.group(3) # Issue502
                
                # If the base ID matches, it's a sub-issue (e.g. Issue502_1 is sub of Issue502)
                # So we continue (include this line)
                if found_base_id == parent_base:
                    continue
                
                # If base ID differs (e.g. Issue503), it's a new issue. Stop.
                end_idx = k
                break
            else:
                 # '## ' but not a recognzied issue format? Treat as new section/issue to be safe
                 end_idx = k
                 break

    if end_idx == -1: end_idx = len(lines)

    block = lines[start_idx:end_idx]
    
    del lines[start_idx:end_idx]
    
    done_idx = find_section_index(lines, "# ✅ 완료")
    if done_idx == -1:
        print("Error: Completed section not found.")
        sys.exit(1)

    # Insert at top of Completed section
    for line in reversed(block):
        lines.insert(done_idx + 1, line)

    write_file(args.file, lines)
    print(f"Successfully closed {issue_id} and moved it to Completed section.")

def link_issue(args):
    lines = read_file(args.file)
    issue_id = args.id
    url = args.url
    title = args.title

    # Find the issue block logic
    start_idx = -1
    for i, line in enumerate(lines):
        # Support both ## and ### for finding the issue
        if line.strip().startswith(f"## {issue_id}") or line.strip().startswith(f"### {issue_id}"):
            start_idx = i
            break
            
    if start_idx == -1:
        print(f"Error: Issue {issue_id} not found.")
        sys.exit(1)

    # find end of block
    end_idx = -1
    for k in range(start_idx + 1, len(lines)):
        # Stop at # or ##
        if lines[k].startswith("# ") or lines[k].startswith("## "):
            end_idx = k
            break
    if end_idx == -1: end_idx = len(lines)

    block = lines[start_idx:end_idx]
    
    # Check if link already exists
    link_line = f"- [{title}]({url})\n"
    found = False
    for line in block:
        if url in line:
            found = True
            break
            
    if not found:
        # Append to the end of the block, but before the next section
        # We need to insert into 'lines' at end_idx
        # But wait, usually there is a newline at the end of the block.
        # Let's insert just before the end_idx.
        
        # Ensure there is a newline before if the last line is not empty
        if block and block[-1].strip() != "":
             lines.insert(end_idx, "\n")
             end_idx += 1
             
        lines.insert(end_idx, link_line)
        write_file(args.file, lines)
        print(f"Successfully linked {url} to {issue_id}")
    else:
        print(f"Link already exists for {issue_id}")

if __name__ == "__main__":
    args = parse_arguments()
    if args.command == "register":
        register_issue(args)
    elif args.command == "close":
        close_issue(args)
    elif args.command == "link":
        link_issue(args)
    elif args.command == "savepoint":
        update_save_point(args)
    elif args.command == "sync":
        sync_issues(args)
