#!/usr/bin/env python3
import csv
import sys
import os
import random
import re
import argparse
from pathlib import Path

# Paths
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent.parent.parent
CSV_PATH = PROJECT_ROOT / "_doc_design" / "EmojiForFile.csv"

# Emoji Pool for fallback (using mostly distinct objects/symbols)
EMOJI_POOL = [
    "🚀", "🛸", "🛰️", "⚓", "🚧", "🚦", "🚩", "🏁", "🎌", "🏴‍☠️",
    "🏳️‍🌈", "📅", "📆", "🗓️", "📇", "📈", "📉", "📊", "📋", "📌",
    "📍", "📎", "📏", "📐", "✂️", "🗂️", "🗃️", "🗄️", "🗑️", "🔒",
    "🔓", "🔏", "🔐", "🔑", "🗝️", "🔨", "🪓", "⛏️", "⚒️", "🛠️",
    "🗡️", "⚔️", "🔫", "🛡️", "🔧", "🔩", "⚙️", "🗜️", "⚖️", "🦯",
    "🔗", "⛓️", "🧰", "🧲", "⚗️", "🧪", "🧫", "🧬", "🔬", "🔭",
    "📡", "💉", "💊", "🩸", "🩹", "🩺", "🚪", "🛏️", "🛋️", "🪑",
    "🚽", "🚿", "🛁", "🪒", "🧴", "🧷", "🧹", "🧺", "🧻", "🧼",
    "🧽", "🧯", "🛒", "🚬", "⚰️", "⚱️", "🗿"
]

# Heuristic Mapping (Keyword -> Emoji)
HEURISTIC_MAP = {
    "Manager": "⚙️",
    "Service": "🛠️",
    "Controller": "🎮",
    "View": "🖼️",
    "Model": "🧠",
    "Data": "💾",
    "Network": "🌐",
    "API": "☁️",
    "Helper": "🤝",
    "Util": "🔧",
    "Config": "📝",
    "Settings": "⚙️",
    "Test": "🧪",
    "Debug": "🐛",
    "Log": "📜",
    "Monitor": "👁️‍🗨️",
    "User": "👤",
    "Auth": "🔐",
    "Payment": "💳",
    "Notification": "🔔",
    "Event": "⚡",
    "Queue": "🔄",
    "Cache": "📦",
    "Database": "🗄️",
    "File": "📁",
    "Image": "🖼️",
    "Video": "📹",
    "Audio": "🔊",
    "Text": "📝",
    "String": "🧵",
    "Date": "📅",
    "Time": "⏰",
    "Color": "🎨",
    "Font": "🔤",
    "Style": "💅",
    "Layout": "📐",
    "Window": "🪟",
    "Screen": "🖥️",
    "Button": "🔘",
    "Input": "⌨️",
    "List": "📜",
    "Grid": "▦",
    "Table": "📊",
    "Chart": "📈",
    "Graph": "📉",
    "Map": "🗺️",
    "Location": "📍",
    "Search": "🔍",
    "Filter": "🌪️",
    "Sort": "🔃",
    "Group": "👥",
    "Tag": "🏷️",
    "Category": "📂",
    "Label": "🏷️",
    "Icon": "🎭",
    "Badge": "📛",
    "Menu": "☰",
    "Tab": "📑",
    "Card": "🃏",
    "Dialog": "💬",
    "Toast": "🍞",
    "Tooltip": "💡",
    "Loader": "⏳",
    "Spinner": "🔄",
    "Progress": "📊",
    "Slider": "🎚️",
    "Switch": "🔌",
    "Checkbox": "☑️",
    "Radio": "🔘",
    "Form": "📝",
    "Field": "🔡",
    "Validation": "✅",
    "Error": "❌",
    "Success": "🎉",
    "Warning": "⚠️",
    "Info": "ℹ️",
    "Question": "❓",
    "Answer": "❗",
    "Help": "🆘",
    "Support": "🎧",
    "Feedback": "📣",
    "Rating": "⭐",
    "Review": "📝",
    "Comment": "💬",
    "Post": "📮",
    "Article": "📰",
    "Blog": "✍️",
    "News": "📰",
    "Feed": "📱",
    "Social": "👥",
    "Share": "🔗",
    "Like": "👍",
    "Dislike": "👎",
    "Follow": "👣",
    "Unfollow": "🚫",
    "Friend": "👫",
    "Chat": "💬",
    "Message": "📩",
    "Email": "📧",
    "Phone": "📞",
    "Call": "📲",
    "VideoCall": "📹",
    "VoiceCall": "🎤",
    "Contact": "📒",
    "Address": "🏠",
    "Profile": "👤",
    "Account": "💳",
    "Login": "🔑",
    "Logout": "🚪",
    "Register": "📝",
    "Signup": "📝",
    "Signin": "🔑",
    "Signout": "🚪",
    "Password": "🔒",
    "Security": "🛡️",
    "Privacy": "👁️",
    "Policy": "📜",
    "Terms": "📜",
    "About": "ℹ️",
    "FAQ": "❓",
    "ContactUs": "📞",
    "Home": "🏠",
    "Dashboard": "📊",
    "Admin": "👮",
    "System": "🖥️",
    "App": "📱",
    "Web": "🌐",
    "Mobile": "📱",
    "Desktop": "🖥️",
    "Tablet": "📱",
    "Watch": "⌚",
    "TV": "📺",
    "Car": "🚗",
    "Game": "🎮",
    "Music": "🎵",
    "Movie": "🎬",
    "Book": "📖",
    "Food": "🍔",
    "Drink": "🍹",
    "Travel": "✈️",
    "Hotel": "🏨",
    "Flight": "🛫",
    "Train": "🚆",
    "Bus": "🚌",
    "Taxi": "🚖",
    "Bike": "🚲",
    "Run": "🏃",
    "Walk": "🚶",
    "Gym": "🏋️",
    "Sport": "⚽",
    "Weather": "☀️",
    "News": "📰",
    "Finance": "💰",
    "Bank": "🏦",
    "Money": "💵",
    "Stock": "📈",
    "Crypto": "🪙",
    "Shopping": "🛍️",
    "Store": "🏪",
    "Product": "📦",
    "Cart": "🛒",
    "Order": "📦",
    "Checkout": "💳",
}

def load_emoji_map(csv_path):
    emoji_map = {} # Key: FileName, Value: Row Dict
    if not csv_path.exists():
        return emoji_map
    
    with open(csv_path, mode='r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            emoji_map[row['FileName']] = row
    return emoji_map

def save_emoji_data(csv_path, emoji_data_list):
    # Sort by Category if present, else by FileName
    emoji_data_list.sort(key=lambda x: (x.get('Category', 'zzz'), x.get('FileName', '')))
    
    fieldnames = ['emoji', 'FileName', 'Category', 'Description', 'filePath']
    
    with open(csv_path, mode='w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(emoji_data_list)

def get_heuristic_emoji(class_name):
    # Check strict suffix/prefix or containment
    for keyword, emoji in HEURISTIC_MAP.items():
        if keyword in class_name:
            return emoji
    return None

def assign_emoji(class_name, existing_emojis):
    # 1. Try Heuristic
    emoji = get_heuristic_emoji(class_name)
    if emoji and emoji not in existing_emojis:
         return emoji

    # 2. Pick Random Unused
    img_pool = [e for e in EMOJI_POOL if e not in existing_emojis]
    if img_pool:
        return random.choice(img_pool)
    
    # 3. Fallback (reuse heuristic or random)
    return emoji if emoji else random.choice(EMOJI_POOL)

def update_source_file(file_path, emoji, dry_run=False):
    if not file_path.exists():
        print(f"Error: File not found {file_path}")
        return

    content = file_path.read_text(encoding='utf-8')
    # Regex to find log calls: log[VDIWE]("...
    # We want to insert the emoji at the beginning of the string if it's not already there.
    
    # Pattern: log(V|D|I|W|E)\(\s*"
    pattern = re.compile(r'(log[VDIWE]\(\s*")')
    
    new_content = []
    lines = content.splitlines()
    modified = False
    
    for line in lines:
        # Check if line has log call
        match = pattern.search(line)
        if match:
            # Check if emoji is already present after the quote
            # match.end() gives index after "
            quote_end_index = match.end()
            # Look ahead to see if emoji is there
            # Heuristic: check next few chars for the specific emoji
            rest_of_line = line[quote_end_index:]
            
            if not rest_of_line.startswith(emoji):
                 # Inject emoji
                 # Also check if there is another emoji? strict rule: use THIS emoji.
                 # Only if it doesn't match the assigned emoji, prepend it.
                 # But we might want to replace existing distinct emojis?
                 # For now, just prepend if missing.
                 
                 # Construct new line
                 new_line = line[:quote_end_index] + f"{emoji} " + line[quote_end_index:]
                 new_content.append(new_line)
                 modified = True
            else:
                 new_content.append(line)
        else:
            new_content.append(line)
            
    if modified:
        if not dry_run:
            file_path.write_text('\n'.join(new_content), encoding='utf-8')
            print(f"Updated {file_path} with emoji {emoji}")
        else:
            print(f"[Dry Run] Would update {file_path} with emoji {emoji}")
    else:
        print(f"No changes needed for {file_path}")

def get_category(file_path_str):
    parts = file_path_str.split('/')
    if 'Core' in parts: return 'Core'
    if 'Data' in parts: return 'Data'
    if 'Managers' in parts: return 'Managers'
    if 'UI' in parts: return 'UI'
    if 'Utils' in parts: return 'Utils'
    if 'Views' in parts: return 'Views'
    if 'Extensions' in parts: return 'Extensions'
    return 'Other'

def main():
    parser = argparse.ArgumentParser(description="Register a class with an emoji and update logger calls.")
    parser.add_argument("class_name", help="Name of the class (e.g. MyManager)")
    parser.add_argument("file_path", help="Relative or absolute path to the source file")
    parser.add_argument("--dry-run", action="store_true", help="Do not modify files")
    
    args = parser.parse_args()
    
    class_name = args.class_name
    file_path = Path(args.file_path).resolve()
    
    # Validation Rules
    ALLOWED_EXTENSIONS = {".swift"}
    IGNORE_PATTERNS = {"Tests/", ".agent/", "_tool/", "Preview", "Mock"}

    if file_path.suffix not in ALLOWED_EXTENSIONS:
        print(f"Error: Only {ALLOWED_EXTENSIONS} files are allowed.")
        sys.exit(1)

    # Check for ignored patterns in the full path string
    file_path_str = str(file_path)
    if any(pattern in file_path_str for pattern in IGNORE_PATTERNS):
        print(f"Error: File path matches ignored pattern: {IGNORE_PATTERNS}")
        sys.exit(1)

    if not file_path.exists():
        print(f"Error: Source file does not exist: {file_path}")
        sys.exit(1)
        
    # Relativize path for CSV logic
    try:
        rel_path = file_path.relative_to(PROJECT_ROOT)
    except ValueError:
        rel_path = file_path # Fallback if outside root
    
    rel_path_str = "fSnippet/" + str(rel_path) if not str(rel_path).startswith("fSnippet") else str(rel_path)

    
    # 1. Load existing map (Key: FileName, Value: Full Row Dict)
    emoji_map_full = load_emoji_map(CSV_PATH)
    
    existing_emojis = {row['FileName']: row['emoji'] for row in emoji_map_full.values()}
    
    
    # 2. Assign or Get Emoji
    if class_name in emoji_map_full:
        row = emoji_map_full[class_name]
        emoji = row['emoji']
        print(f"Class {class_name} already has emoji: {emoji}")
        
        # Update path if changed (optional)
        if row['filePath'] != rel_path_str:
             row['filePath'] = rel_path_str
             print(f"Updated path for {class_name}")

    else:
        emoji = assign_emoji(class_name, list(existing_emojis.values()))
        category = get_category(rel_path_str)
        
        new_row = {
            'emoji': emoji,
            'FileName': class_name,
            'Category': category,
            'Description': 'Auto-registered', # User can update later
            'filePath': rel_path_str
        }
        emoji_map_full[class_name] = new_row
        print(f"Assigned new emoji for {class_name}: {emoji}")
        
    
    if not args.dry_run:
        save_emoji_data(CSV_PATH, list(emoji_map_full.values()))
        print(f"Updated {CSV_PATH}")
    
    # 3. Update Source File
    update_source_file(file_path, emoji, dry_run=args.dry_run)

if __name__ == "__main__":
    main()
