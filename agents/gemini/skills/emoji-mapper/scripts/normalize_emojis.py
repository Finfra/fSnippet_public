#!/usr/bin/env python3
import csv
import re
import os
import sys

def load_mapping(csv_path):
    mapping = {}
    if not os.path.exists(csv_path):
        return {}
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        next(reader, None)
        for row in reader:
            if len(row) >= 2:
                emoji = row[0].strip()
                classname = row[1].strip()
                if classname and emoji:
                    mapping[classname] = emoji
    return mapping

def normalize_file(file_path, mapping):
    if not os.path.exists(file_path):
        return
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    sorted_classes = sorted(mapping.keys(), key=len, reverse=True)
    
    # Process the entire content at once but with careful regex
    # We want to catch: (Context)(ExistingJunk)ClassName
    # Context: Start of line, Spaces, Bullets(*+-), Headers(#), Brackets([], (), {})
    # ExistingJunk: Any symbols (emojis, etc.) that are NOT part of the context
    
    new_content = content
    
    for classname in sorted_classes:
        emoji = mapping[classname]
        
        # Context pattern: matches things like "### ", "* ", " [", "(", or even just " " or START
        # Junk pattern: matches any non-word, non-digit, non-space characters EXCEPT structural ones
        junk_char = r'[^\w\d\s\[\]\(\)\{\}\|\<\>\\#*+-]'
        
        # Regex breakdown:
        # Group 1 (Context): Start of line or any structural/whitespace char, 
        #                   followed by optional markdown bullet/header and then spaces
        # Group 2 (Junk): Zero or more repetitions of (one or more junk chars followed by optional spacing)
        # Final: The classname as a whole word
        
        pattern = r'(^|[\s\[\(\>])((?:[*+-]|#{1,6})?[ \t]*)?(?:' + junk_char + r'[ \t]*)*\b' + re.escape(classname) + r'\b'
        
        def replace_func(m):
            base_prefix = m.group(1) or ""
            struct_prefix = m.group(2) or ""
            # We standardize to: base_prefix + struct_prefix + emoji + " " + classname
            # If base_prefix is part of the classname word boundary, we must be careful, 
            # but \b handles it.
            return f"{base_prefix}{struct_prefix}{emoji} {classname}"
            
        new_content = re.sub(pattern, replace_func, new_content)

    if new_content != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Normalized: {file_path}")

if __name__ == "__main__":
    csv_url = '_doc_design/EmojiForFile.csv'
    mapping = load_mapping(csv_url)
    files = sys.argv[1:]
    for f in files:
        normalize_file(f, mapping)
