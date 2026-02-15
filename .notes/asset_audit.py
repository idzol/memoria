import os
import re
from datetime import datetime

def find_project_root():
    """
    Looks for the project.godot file starting from the script's location.
    Works if the script is in a subdirectory like ./.notes/
    """
    current_path = os.path.dirname(os.path.abspath(__file__))
    
    # Traverse upwards to find the Godot project root
    while current_path != os.path.dirname(current_path):
        if "project.godot" in os.listdir(current_path):
            return current_path
        current_path = os.path.dirname(current_path)
        
    # Fallback to current directory if not found
    return os.path.dirname(os.path.abspath(__file__))

# Set paths dynamically
PROJECT_ROOT = find_project_root()
ASSETS_DIR = os.path.join(PROJECT_ROOT, "assets")
OUTPUT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "asset_audit.md")

# Directories to scan for references
SEARCH_DIRS = ["core", "data", "features"]

def get_referenced_assets():
    """
    Scans all .gd, .tscn, and .tres files in target directories
    for strings containing 'res://assets/'.
    """
    referenced = set()
    dynamic_templates = set()
    
    asset_pattern = re.compile(r'res://assets/([^"\'\s>]+)')
    extensions_to_scan = {".gd", ".tscn", ".tres"}

    print(f"Scanning for references in: {PROJECT_ROOT}")
    
    for s_dir in SEARCH_DIRS:
        target_path = os.path.join(PROJECT_ROOT, s_dir)
        if not os.path.exists(target_path):
            continue
            
        for root, _, files in os.walk(target_path):
            for file in files:
                if any(file.endswith(ext) for ext in extensions_to_scan):
                    file_path = os.path.join(root, file)
                    try:
                        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                            content = f.read()
                            matches = asset_pattern.findall(content)
                            for match in matches:
                                # Clean up potential trailing characters
                                clean_match = match.split('"')[0].split("'")[0].split(" ")[0]
                                
                                if "%s" in clean_match:
                                    dynamic_templates.add(clean_match)
                                else:
                                    referenced.add(clean_match)
                    except Exception as e:
                        print(f"  Could not read {file_path}: {e}")
    
    return referenced, dynamic_templates

def get_physical_assets(assets_dir):
    """
    Walks the assets directory to find all actual files.
    """
    physical = set()
    imports = set()
    
    if not os.path.exists(assets_dir):
        return physical, imports

    for root, _, files in os.walk(assets_dir):
        for file in files:
            rel_dir = os.path.relpath(root, assets_dir)
            path = file if rel_dir == "." else os.path.join(rel_dir, file).replace("\\", "/")
            
            if file.endswith(".import"):
                imports.add(path)
            else:
                physical.add(path)
                
    return physical, imports

def run_audit():
    print("Running audit...")
    ref_assets, templates = get_referenced_assets()
    phys_assets, import_files = get_physical_assets(ASSETS_DIR)
    
    missing_files = ref_assets - phys_assets
    unused_files = phys_assets - ref_assets
    
    orphaned_imports = []
    for imp in import_files:
        original_file = imp.replace(".import", "")
        if original_file not in phys_assets:
            orphaned_imports.append(imp)

    # Prepare Markdown Output
    lines = []
    lines.append("# Asset Audit Report")
    lines.append(f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"\n**Project Root:** `{PROJECT_ROOT}`")
    
    lines.append("\n## Summary")
    lines.append(f"- **Unique static references found:** {len(ref_assets)}")
    lines.append(f"- **Dynamic templates (regex):** {len(templates)}")
    lines.append(f"- **Physical files on disk:** {len(phys_assets)}")
    lines.append(f"- **Orphaned .import files:** {len(orphaned_imports)}")

    if templates:
        lines.append("\n## 🔍 Dynamic Templates")
        lines.append("> Found patterns with `%s`. Check these manually for asset usage.")
        for t in sorted(templates):
            lines.append(f"- `res://assets/{t}`")

    if missing_files:
        lines.append("\n## ❌ Missing Assets")
        lines.append("Referenced in code/scenes but not found in the `assets/` folder:")
        for asset in sorted(missing_files):
            lines.append(f"- `res://assets/{asset}`")
    else:
        lines.append("\n## ✅ Missing Assets")
        lines.append("No missing static assets found.")
        
    if orphaned_imports:
        lines.append("\n## 🧹 Orphaned .import Files")
        lines.append("These `.import` files exist without a corresponding source file. Safe to delete.")
        for imp in sorted(orphaned_imports):
            lines.append(f"- `res://assets/{imp}`")

    if unused_files:
        lines.append("\n## ⚠️ Unreferenced Assets")
        lines.append("Found on disk but not directly referenced in searched directories. (May be used by dynamic paths).")
        for asset in sorted(unused_files):
            lines.append(f"- `{asset}`")

    # Write to file
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    
    print(f"Audit complete! Results saved to: {OUTPUT_FILE}")

if __name__ == "__main__":
    run_audit()