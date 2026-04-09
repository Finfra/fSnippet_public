#!/usr/bin/env python3
import csv
import re
import os
import sys
import argparse

def load_mapping(csv_path):
    mapping = {}
    if not os.path.exists(csv_path):
        print(f"Error: Mapping file not found at {csv_path}")
        return {}
        
    try:
        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            next(reader, None) # Skip header
            for row in reader:
                if len(row) >= 2:
                    emoji = row[0].strip()
                    classname = row[1].strip()
                    if classname and emoji:
                        mapping[classname] = emoji
        return mapping
    except Exception as e:
        print(f"Error loading mapping: {e}")
        return {}

def process_file(file_path, mapping, dry_run=False):
    if not os.path.exists(file_path):
        print(f"Skipping {file_path} (Not Found)")
        return

    print(f"Processing {file_path}...")
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Separate Frontmatter
        frontmatter = ""
        body = content
        
        if content.startswith('---'):
            parts = content.split('---', 2)
            if len(parts) >= 3:
                frontmatter = '---' + parts[1] + '---'
                body = parts[2]
        
        # Sort keys to prioritize longer matches
        sorted_keys = sorted(mapping.keys(), key=len, reverse=True)
        
        original_body = body
        changes_count = 0
        
        for classname in sorted_keys:
            emoji = mapping[classname]
            # Use a slightly different approach: just find occurrences of ClassName
            # and only replace if it's not immediately preceded by the emoji (ignoring spaces)
            
            # Escape emoji and classname
            e_esc = re.escape(emoji)
            c_esc = re.escape(classname)
            
            # Pattern: look for ClassName not preceded by emoji
            # A negative lookbehind is tricky with variable length emojis+spaces,
            # so we'll match (emoji)?\s*ClassName and then replace it with emoji ClassName
            
            # Pattern matches optional emoji, optional whitespace, then ClassName as a whole word
            pattern = re.compile(f'(?:{e_esc})?\\s*\\b({c_esc})\\b')
            
            def replace_func(m):
                word = m.group(1)
                # Ensure we have just one emoji and a space before the word
                return f'{emoji} {word}'

            new_body, count = pattern.subn(replace_func, body)
            if count > 0 and new_body != body:
                body = new_body
                changes_count += count

        new_content = frontmatter + body
        
        if new_content != content:
            if dry_run:
                print(f"  [DRY RUN] Would update {file_path} ({changes_count} changes)")
            else:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"  > Updated {file_path} ({changes_count} changes applied)")
        else:
            print(f"  > No changes needed for {file_path}")

    except Exception as e:
        print(f"Error processing {file_path}: {e}")

def main():
    parser = argparse.ArgumentParser(description='Apply emojis to files based on CSV mapping.')
    parser.add_argument('files', metavar='F', type=str, nargs='+', help='Files to process')
    parser.add_argument('--mapping', default='_doc_design/EmojiForFile.csv', help='Path to CSV mapping file')
    parser.add_argument('--dry-run', action='store_true', help='Preview changes without modifying files')
    
    args = parser.parse_args()
    
    print(f"Loading mapping from {args.mapping}...")
    mapping = load_mapping(args.mapping)
    if not mapping:
        sys.exit(1)
        
    print(f"Loaded {len(mapping)} mappings.")
    
    for file_path in args.files:
        process_file(file_path, mapping, args.dry_run)

if __name__ == "__main__":
    main()
