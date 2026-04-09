import argparse
import datetime
import sys
import os

def parse_arguments():
    parser = argparse.ArgumentParser(description="Save Point Update Tool")
    parser.add_argument("--hash", required=True, help="Commit hash")
    parser.add_argument("--msg", default="Update", help="Commit message or description")
    parser.add_argument("--file", default="Issue.md", help="Target issue file")
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
    # Indentation: 6 spaces
    new_line = f"      - {today}: {args.hash} ({args.msg})\n"
    
    # Insert after the header
    lines.insert(header_idx + 1, new_line)
    
    write_file(args.file, lines)
    print(f"Successfully added save point: {today}: {args.hash} ({args.msg})")

if __name__ == "__main__":
    args = parse_arguments()
    update_save_point(args)
