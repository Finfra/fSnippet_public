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
                if len(row) >= 5:
                    emoji = row[0].strip()
                    filename = row[1].strip()
                    filepath = row[4].strip()
                    if emoji:
                        # 1. 파일명 (AbbreviationMatcher)
                        if filename:
                            mapping[filename] = emoji
                            mapping[f"{filename}.swift"] = emoji
                        
                        if filepath:
                            mapping[filepath] = emoji
                            mapping[filepath.replace("fSnippet/fSnippet/", "fSnippet/")] = emoji
                            clean_path = filepath.replace("fSnippet/fSnippet/", "")
                            mapping[clean_path] = emoji
                            
                            base = os.path.basename(filepath)
                            mapping[base] = emoji
                            mapping[os.path.splitext(base)[0]] = emoji
        print(f"DEBUG: Sample mapping: {list(mapping.items())[:5]}")
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

        # Sort mapping by key length descending to avoid partial matches
        sorted_keys = sorted(mapping.keys(), key=len, reverse=True)
        
        new_content = content
        
        # We'll use a set to keep track of what we've replaced in this file to avoid double processing
        # Actually, if we use re.sub with a callback that handles context, it's safer.
        # But looping keys is easier for "Any mention of X should have Emoji X".
        
        for key in sorted_keys:
            emoji = mapping[key]
            
            # This regex finds:
            # 1. Potential emoji before (optional)
            # 2. Potential spaces (optional)
            # 3. Potential backtick (optional)
            # 4. The KEY (word boundary)
            # 5. Potential backtick (optional)
            
            # Match only if it's not already correct.
            # But regex replacement is easier if we just match everything and re-format it.
            
            escaped_key = re.escape(key)
            # Look for [Emoji]? [Spaces]? [`]? [KEY] [`]?
            # We use (?<!`) to ensure we don't start matching in the middle of a backticked string?
            # Actually, we WANT to match inside backticks if they are there.
            
            # Regex: match optional emoji + optional space + optional tick + KEY + optional tick
            pattern = re.compile(r'((?P<emoji>[^\s\w\d]{1,2})\s*)?(`)?\b(' + escaped_key + r')\b(`)?')
            
            def replace_func(match):
                found_emoji = match.group('emoji')
                has_opening_tick = match.group(3) == '`'
                val = match.group(4)
                has_closing_tick = match.group(5) == '`'
                
                # If it's already properly formatted: FoundEmoji `Path`
                # (Ignore space difference for now)
                
                target_emoji = found_emoji if found_emoji else emoji
                
                # Re-format to: Emoji `Path`
                # We use a space between emoji and backtick for clarity
                return f"{target_emoji} `{val}`"

            # To prevent infinite recursion or replacing our own replacements:
            # We'll only replace if the key isn't already preceded by ALREADY FIXED pattern.
            # This is tricky with simple re.sub.
            
            # Alternative: Match all and replace in one go using a combined regex.
            pass

        # Pass 1: Handle all backticked items
        def sub_tick(m):
            opening_tick = m.group(1)
            path_val = m.group(2)
            closing_tick = m.group(3)
            
            emoji = mapping.get(path_val)
            if not emoji:
                base = os.path.basename(path_val)
                name_no_ext = os.path.splitext(base)[0]
                emoji = mapping.get(base) or mapping.get(name_no_ext)
            
            if not emoji:
                return m.group(0)
            
            # Check if an emoji already exists before this match in the content
            start_pos = m.start()
            preceding_text = content[max(0, start_pos-5):start_pos]
            
            # Look for ANY emoji-like character in preceding text
            # (We'll be conservative and just look for our target emoji or common ones)
            if emoji in preceding_text:
                return m.group(0)
            
            # If not there, add it. 
            # If the preceding character is a colon, add a space.
            prefix = ""
            if start_pos > 0:
                last_char = content[start_pos-1]
                if last_char == ":":
                    prefix = " "
                elif not last_char.isspace() and last_char not in ['*', '-', '>', '(']:
                    prefix = " "

            return f"{prefix}{emoji} `{path_val}`"

        # Regex for strictly backticked items: `path`
        new_content = re.sub(r'(`)([^`\s]+)(`)', sub_tick, content)

        # Pass 2: Cleanup - If we have "Emoji`path`" (attached), add space: "Emoji `path`"
        # Also move emoji outside if it somehow got inside (though Pass 1 avoids this)
        def sub_cleanup(m):
            emoji_char = m.group(1)
            path_val = m.group(2)
            return f"{emoji_char} `{path_val}`"
            
        # Match Emoji`path` or Emoji `path`
        # We use a broad emoji range or just non-ascii non-markdown
        new_content = re.sub(r'([^a-zA-Z0-9\s`*:#\(\)\[\]]{1,2})\s*`([^`\s]+)`', sub_cleanup, new_content)

        if new_content != content:
            if dry_run:
                print(f"  [DRY RUN] Would update {file_path}")
            else:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"  > Updated {file_path}")
        else:
            print(f"  > No changes needed for {file_path}")

    except Exception as e:
        print(f"Error processing {file_path}: {e}")

def main():
    parser = argparse.ArgumentParser(description='Apply emojis to file paths in markdown files.')
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
