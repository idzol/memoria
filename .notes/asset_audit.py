import os
import re
from datetime import datetime

def find_project_root():
    """Looks for the project.godot file starting from the script's location."""
    current_path = os.path.dirname(os.path.abspath(__file__))
    while current_path != os.path.dirname(current_path):
        if "project.godot" in os.listdir(current_path):
            return current_path
        current_path = os.path.dirname(current_path)
    return os.path.dirname(os.path.abspath(__file__))

# Set paths dynamically
PROJECT_ROOT = find_project_root()
ASSETS_DIR = os.path.join(PROJECT_ROOT, "assets")
ROOMS_DIR = os.path.join(PROJECT_ROOT, "data", "rooms")

# Try multiple common locations for GameData.gd
GAMEDATA_LOCATIONS = [
    os.path.join(PROJECT_ROOT, "core", "GameData.gd"),
    os.path.join(PROJECT_ROOT, "data", "GameData.gd"),
    os.path.join(PROJECT_ROOT, "GameData.gd")
]
GAMEDATA_PATH = next((p for p in GAMEDATA_LOCATIONS if os.path.exists(p)), GAMEDATA_LOCATIONS[0])

OUTPUT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "asset_audit.md")

SEARCH_DIRS = ["core", "data", "features"]

def get_referenced_assets():
    """Scans all .gd, .tscn, and .tres files for res://assets/ references."""
    referenced = set()
    dynamic_templates = set()
    asset_pattern = re.compile(r'res://assets/([^"\'\s>]+)')
    extensions_to_scan = {".gd", ".tscn", ".tres"}

    for s_dir in SEARCH_DIRS:
        target_path = os.path.join(PROJECT_ROOT, s_dir)
        if not os.path.exists(target_path): continue
        for root, _, files in os.walk(target_path):
            for file in files:
                if any(file.endswith(ext) for ext in extensions_to_scan):
                    file_path = os.path.join(root, file)
                    try:
                        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                            content = f.read()
                            matches = asset_pattern.findall(content)
                            for match in matches:
                                clean_match = match.split('"')[0].split("'")[0].split(" ")[0]
                                if "%s" in clean_match: dynamic_templates.add(clean_match)
                                else: referenced.add(clean_match)
                    except Exception: pass
    return referenced, dynamic_templates

def get_required_room_resources():
    """
    Indentation-aware parser for GameData.gd.
    Distinguishes between Biomes (1 tab) and Rooms (2 tabs).
    """
    required = []
    if not os.path.exists(GAMEDATA_PATH):
        print(f"Warning: GameData not found at {GAMEDATA_PATH}")
        return required

    try:
        with open(GAMEDATA_PATH, 'r', encoding='utf-8') as f:
            content = f.read()
            
            # 1. Isolate the ROOMS dictionary block
            # We look for 'const ROOMS = {' and capture until the next major GDScript keyword or end of file.
            rooms_match = re.search(r'const ROOMS\s*=\s*\{(.*?)(\nconst|\nfunc|\nsignal|\Z)', content, re.DOTALL)
            
            if not rooms_match:
                print("Error: Could not find 'const ROOMS' block in GameData.gd")
                return required

            rooms_block = rooms_match.group(1)
            
            # 2. Find Biomes: Quoted keys preceded by exactly ONE tab (or 4 spaces) and a newline.
            # Pattern: newline, then 1 tab/whitespace, then "key": {
            biome_pattern = re.compile(r'\n[\t ]{1}["\'](\w+)["\']:\s*\{', re.MULTILINE)
            biome_matches = list(biome_pattern.finditer(rooms_block))
            
            if not biome_matches:
                print("Warning: Found ROOMS block but no biomes. Check indentation.")
                return required

            # Extract content chunks for each biome
            for i in range(len(biome_matches)):
                biome_name = biome_matches[i].group(1)
                start_pos = biome_matches[i].end()
                end_pos = biome_matches[i+1].start() if i + 1 < len(biome_matches) else len(rooms_block)
                biome_chunk = rooms_block[start_pos:end_pos]
                
                # 3. Find Rooms inside this biome chunk: Quoted keys preceded by exactly TWO tabs/whitespace.
                # Usually rooms look like "t1", "f20", "i5".
                room_pattern = re.compile(r'\n[\t ]{2}["\'](\w\d+)["\']:\s*\{', re.MULTILINE)
                room_keys = room_pattern.findall(biome_chunk)
                
                for key in room_keys:
                    required.append({
                        "biome": biome_name,
                        "key": key,
                        "path": f"res://data/rooms/{biome_name}/{key}.tres",
                        "phys_path": os.path.join(ROOMS_DIR, biome_name, f"{key}.tres"),
                        "dir_path": os.path.join(ROOMS_DIR, biome_name)
                    })
                    
    except Exception as e:
        print(f"Error parsing GameData: {e}")
    
    return required

def get_physical_assets(assets_dir):
    physical = set()
    imports = set()
    if not os.path.exists(assets_dir): return physical, imports
    for root, _, files in os.walk(assets_dir):
        for file in files:
            rel_dir = os.path.relpath(root, assets_dir)
            path = file if rel_dir == "." else os.path.join(rel_dir, file).replace("\\", "/")
            if file.endswith(".import"): imports.add(path)
            else: physical.add(path)
    return physical, imports

def run_audit():
    print(f"Running audit on: {PROJECT_ROOT}")
    print(f"Reading GameData from: {GAMEDATA_PATH}")
    
    ref_assets, templates = get_referenced_assets()
    phys_assets, import_files = get_physical_assets(ASSETS_DIR)
    required_rooms = get_required_room_resources()
    
    missing_assets = ref_assets - phys_assets
    
    # Check for missing .tres files and missing directories
    missing_rooms = []
    missing_dirs = set()
    for room in required_rooms:
        if not os.path.exists(room["dir_path"]):
            missing_dirs.add(room["biome"])
        if not os.path.exists(room["phys_path"]):
            missing_rooms.append(room["path"])

    orphaned_imports = [imp for imp in import_files if imp.replace(".import", "") not in phys_assets]

    # Prepare Markdown Output
    lines = [
        "# Asset & Resource Audit Report",
        f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"\n**Project Root:** `{PROJECT_ROOT}`",
        f"**GameData Path:** `{GAMEDATA_PATH}`",
        "\n## Summary",
        f"- **Unique static asset references found:** {len(ref_assets)}",
        f"- **Missing static assets (PNGs, etc):** {len(missing_assets)}",
        f"- **Required Room Resources (.tres):** {len(required_rooms)}",
        f"- **Missing Room Resources (.tres):** {len(missing_rooms)}",
        f"- **Missing Biome Directories:** {len(missing_dirs)}",
        f"- **Orphaned .import files:** {len(orphaned_imports)}"
    ]

    if missing_dirs:
        lines.append("\n## 📂 Missing Biome Directories")
        lines.append("> These folders must exist in `res://data/rooms/` for the audit to pass.")
        for d in sorted(missing_dirs):
            lines.append(f"- `res://data/rooms/{d}/` (Currently missing)")

    if missing_rooms:
        lines.append("\n## 💎 Missing Room Resources (.tres)")
        lines.append("> Files must be named after the **Key** in `GameData.gd` (e.g. `t1.tres`).")
        
        current_biome = ""
        for path in sorted(missing_rooms):
            parts = path.split("/")
            biome_part = parts[-2]
            if biome_part != current_biome:
                current_biome = biome_part
                lines.append(f"\n### Biome: {current_biome}")
            lines.append(f"- `{path}`")
    elif required_rooms:
        lines.append("\n## ✅ All Room Resources found.")

    if missing_assets:
        lines.append("\n## ❌ Missing Static Assets")
        for asset in sorted(missing_assets):
            lines.append(f"- `res://assets/{asset}`")
    
    if orphaned_imports:
        lines.append("\n## 🧹 Orphaned .import Files")
        for imp in sorted(orphaned_imports):
            lines.append(f"- `res://assets/{imp}`")

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    
    print(f"Audit complete! Checked {len(required_rooms)} rooms. Results saved to: {OUTPUT_FILE}")

if __name__ == "__main__":
    run_audit()