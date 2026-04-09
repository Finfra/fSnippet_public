import argparse
import re
import sys
import os

def parse_arguments():
    parser = argparse.ArgumentParser(description="Issue HWM Manager for fSnippet")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Sync Command
    sync_parser = subparsers.add_parser("sync", help="Synchronize HWM and Issue structure")
    sync_parser.add_argument("--file", default="Issue.md", help="Target issue file")

    return parser.parse_args()

def read_file(filepath):
    if not os.path.exists(filepath):
        print(f"Error: File not found: {filepath}")
        sys.exit(1)
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.readlines()

def write_file(filepath, lines):
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(lines)

def determine_prefix(filename):
    if "clipboard" in filename.lower():
        return "CL"
    return "Issue"

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
    max_id = 0
    # Pattern: Issue123 or CL123 (excluding sub-issues like Issue123_4)
    # Fix: Only scan HEADERS to avoid matching text in descriptions
    pattern = re.compile(rf'^#{{2,3}}\s+{prefix}(\d+)(?!_)\b', re.MULTILINE)
    
    for line in lines:
        for match in pattern.finditer(line):
            val = int(match.group(1))
            if val > max_id:
                max_id = val
                
    # 3. Determine True HWM (Max of Header and Scanned)
    true_hwm = max(header_val, max_id)
    
    # 4. Auto-Correction (Update line in memory if needed)
    if header_idx != -1 and true_hwm > header_val:
        print(f"Warning: Header HWM ({header_val}) is lower than actual Max ID ({max_id}). Auto-correcting to {true_hwm}.")
        lines[header_idx] = f"* {header_label}: {true_hwm}\n"
        
    return true_hwm, header_idx, header_label

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

if __name__ == "__main__":
    args = parse_arguments()
    if args.command == "sync":
        sync_issues(args)
