import os
import re

# Configuration
WORKFLOW_DIR = ".agent/workflows"
NOTE_FOR_HUMAN_PATH = "../fSnippet_doc/noteForHuman.md"  # Relative to project root if script run from root
GEMINI_MD_PATH = "GEMINI.md"

def get_workflows():
    workflows = []
    if not os.path.exists(WORKFLOW_DIR):
        print(f"Error: {WORKFLOW_DIR} not found.")
        return []

    for filename in sorted(os.listdir(WORKFLOW_DIR)):
        if filename.endswith(".md"):
            filepath = os.path.join(WORKFLOW_DIR, filename)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # Extract description using regex
            match = re.search(r'description:\s*(.+)', content)
            description = match.group(1).strip() if match else "설명 없음"
            
            # Clean description (remove [ ] etc if needed, but keeping simple for now)
            
            cmd_name = "/" + filename.replace(".md", "")
            workflows.append({"cmd": cmd_name, "desc": description})
            
    return workflows

def update_note_for_human(workflows):
    if not os.path.exists(NOTE_FOR_HUMAN_PATH):
        # Try finding it relative to current script if run from root
        # Adjust path logic as needed. Assuming running from project root.
        pass

    # Read file
    try:
        with open(NOTE_FOR_HUMAN_PATH, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"Warning: {NOTE_FOR_HUMAN_PATH} not found. Skipping.")
        return

    # Find Start/End of Table
    start_idx = -1
    end_idx = -1
    
    header_pattern = "## Agent Workflows"
    
    for i, line in enumerate(lines):
        if header_pattern in line:
            start_idx = i
            break
            
    if start_idx != -1:
        # Find the header separator line |---|---|
        sep_idx = -1
        for i in range(start_idx, min(start_idx + 5, len(lines))):
            if "| :--" in lines[i] or "| ---" in lines[i]:
                sep_idx = i
                break
        
        if sep_idx != -1:
            # Table starts after separator
            table_start = sep_idx + 1
            
            # Find end of table (empty line or new header)
            for i in range(table_start, len(lines)):
                if not lines[i].strip() or lines[i].startswith("#"):
                    end_idx = i
                    break
            if end_idx == -1: end_idx = len(lines)

            # Construct new table content
            new_rows = []
            for wf in workflows:
                new_rows.append(f"| `{wf['cmd']}` | {wf['desc']} |\n")
            
            # Replace
            lines[table_start:end_idx] = new_rows
            
            with open(NOTE_FOR_HUMAN_PATH, 'w', encoding='utf-8') as f:
                f.writelines(lines)
            print(f"Updated {NOTE_FOR_HUMAN_PATH}")

def update_gemini_md(workflows):
    try:
        with open(GEMINI_MD_PATH, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"Warning: {GEMINI_MD_PATH} not found. Skipping.")
        return

    # Look for **⚡️ Available Workflows (`.agent/workflows/`)**:
    start_marker = "**⚡️ Available Workflows (`.agent/workflows/`)**:"
    start_idx = -1
    
    for i, line in enumerate(lines):
        if start_marker in line:
            start_idx = i
            break
            
    if start_idx != -1:
        # End is next empty line or header
        end_idx = -1
        for i in range(start_idx + 1, len(lines)):
            if lines[i].strip() == "" and i > start_idx + 1: # Allow one empty line maybe? No, usually tight list
                 pass # keep going till empty line
            if lines[i].startswith("#") or (lines[i].strip() == "" and i > start_idx + 1):
                 end_idx = i
                 break
        if end_idx == -1: end_idx = len(lines)

        # Construct new list
        new_lines = []
        for wf in workflows:
            new_lines.append(f"  - `{wf['cmd']}`: {wf['desc']}\n")
            
        # Optimization: Don't replace if identical? (Optional)
        
        lines[start_idx + 1 : end_idx] = new_lines
        
        with open(GEMINI_MD_PATH, 'w', encoding='utf-8') as f:
            f.writelines(lines)
        print(f"Updated {GEMINI_MD_PATH}")

if __name__ == "__main__":
    workflows = get_workflows()
    if workflows:
        print(f"Found {len(workflows)} workflows.")
        update_note_for_human(workflows)
        update_gemini_md(workflows)
    else:
        print("No workflows found.")
