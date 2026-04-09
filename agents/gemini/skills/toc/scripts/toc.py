import argparse
import re
import sys
import os

def generate_anchor(title):
    # Convert to lowercase
    anchor = title.lower()
    # Remove special characters (keep alphanumerics, hyphens, spaces, Korean)
    # Regex: Keep [a-z0-9\s-] and any non-ascii (for Korean/Unicode)
    # Actually, GitHub usually removes punctuation like ., ?, !
    anchor = re.sub(r'[^\w\s\-\u3131-\uD79D]', '', anchor)
    # Replace spaces with hyphens
    anchor = re.sub(r'\s+', '-', anchor)
    # Remove leading/trailing hyphens (if any, though uncommon)
    anchor = anchor.strip('-')
    return anchor

def process_file(file_path, apply_changes):
    if not os.path.exists(file_path):
        print(f"Error: File not found: {file_path}")
        sys.exit(1)

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    lines = content.split('\n')
    
    # 1. Collect Headers
    headers = []
    first_h1_skipped = False
    
    in_code_block = False
    
    for line in lines:
        if line.strip().startswith('```'):
            in_code_block = not in_code_block
            continue
            
        if in_code_block:
            continue
            
        if line.startswith('# '):
            title = line[2:].strip()
            if not first_h1_skipped:
                # Assuming first H1 is the document title
                # But we should verify if it's the TOC header itself? No, TOC is H2.
                # If first line of file is H1, skip it.
                first_h1_skipped = True
                continue
            
            headers.append(title)

    if not headers:
        print("No headers found to generate TOC.")
        return

    # 2. Generate new TOC Content
    toc_lines = []
    toc_lines.append("## 📋 목차")
    toc_lines.append("")
    
    for idx, title in enumerate(headers, 1):
        anchor = generate_anchor(title)
        toc_lines.append(f"{idx}. [{title}](#{anchor})")
    
    toc_lines.append("")
    toc_lines.append("") # Extra padding
    
    new_toc_block = '\n'.join(toc_lines)

    # 3. Find and Replace existing TOC
    # Locate "## 📋 목차"
    start_pattern = r'^## 📋 목차'
    
    # We look for the start
    match = re.search(start_pattern, content, re.MULTILINE)
    
    if not match:
        print("Error: Target header '## 📋 목차' not found in file.")
        print("Please add '## 📋 목차' to the file where you want the TOC to appear.")
        return

    start_idx = match.start()
    
    # Logic to find the END of the current TOC block.
    # We assume the TOC block ends at the next Header (# or ##) or Horizontal Rule (---)
    # We scan from start_idx + length of header.
    
    rest_of_content = content[start_idx:]
    # Split rest by lines to find the standard boundary
    # We want to keep replacing until we hit `^#` or `^---` 
    # BUT we must skip the `## 📋 목차` line itself (which we just found).
    
    header_line_end = rest_of_content.find('\n')
    if header_line_end == -1:
        # File ends dealing with TOC header?
        end_idx = len(content)
    else:
        # Scan forward for next boundary
        relative_content = rest_of_content[header_line_end+1:]
        
        # Regex for boundary: ^# or ^---
        boundary_match = re.search(r'^(#|---)', relative_content, re.MULTILINE)
        
        if boundary_match:
            # Found boundary
            # The end index in `content` is start_idx + header_line_end + 1 + boundary_match.start()
            # BUT we want to preserve the newline before the boundary if possible?
            # Or just replace everything up to boundary start.
            end_idx = start_idx + header_line_end + 1 + boundary_match.start()
        else:
            # End of file
            end_idx = len(content)
            
    # Construct new content
    # content[:start_idx] is everything before TOC header
    # But new_toc_block INCLUDES the header "## 📋 목차"
    # So we replace from `start_idx` to `end_idx`
    
    final_content = content[:start_idx] + new_toc_block + content[end_idx:]
    
    if apply_changes:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(final_content)
        print(f"Successfully updated TOC in {file_path}")
    else:
        print("--- Preview of New TOC Block ---")
        print(new_toc_block)
        print("--- End Preview ---")
        print("(Run with --apply to update file)")

def main():
    parser = argparse.ArgumentParser(description='TOC Generator')
    parser.add_argument('--file', required=True, help='Markdown file path')
    parser.add_argument('--apply', action='store_true', help='Apply changes to file')
    
    args = parser.parse_args()
    process_file(args.file, args.apply)

if __name__ == '__main__':
    main()
