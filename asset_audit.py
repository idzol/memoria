import os
import re

def find_project_root(start_path="."):
    """Recursively looks up for the project.godot file to identify the root."""
    current_path = os.path.abspath(start_path)
    while current_path != os.path.dirname(current_path):
        if "project.godot" in os.listdir(current_path):
            return current_path
        current_path = os.path.dirname(current_path)
    return os.path.abspath(start_path)

# Set paths dynamically
PROJECT_ROOT = find_project_root()
ASSETS_DIR = os.path.join(PROJECT_ROOT, "assets")

def get_referenced_assets():
    """
    Scans all .gd and .tscn files in the project for strings 
    containing 'res://assets/'.
    """
    referenced = set()
    # Pattern for code: "res://assets/path/to/file.png"
    # Pattern for tscn: path="res://assets/path/to/file.png"
    asset_pattern = re.compile(r'res://assets/([^"\'\s>]+)')

    extensions_to_scan = {".gd", ".tscn", ".tres"}

    print(f"Scanning for references in {PROJECT_ROOT}...")
    
    for root, dirs, files in os.walk(PROJECT_ROOT):
        # Skip the .godot folder and assets folder itself to avoid self-referencing
        if ".godot" in root or "assets" in root:
            continue
            
        for file in files:
            if any(file.endswith(ext) for ext in extensions_to_scan):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                        matches = asset_pattern.findall(content)
                        for match in matches:
                            # Clean up potential trailing characters from regex capture
                            clean_match = match.split('"')[0].split("'")[0].split(" ")[0]
                            referenced.add(clean_match)
                except Exception as e:
                    print(f"  Could not read {file_path}: {e}")
    
    return referenced

def get_physical_assets(assets_dir):
    """Walks the assets directory to find all actual files, ignoring .import files."""
    physical = set()
    if not os.path.exists(assets_dir):
        print(f"Error: Assets directory not found at {assets_dir}")
        return physical

    for root, _, files in os.walk(assets_dir):
        for file in files:
            # Skip Godot internal import tracking files
            if file.endswith(".import"):
                continue
            
            # Get relative path from the assets folder
            rel_dir = os.path.relpath(root, assets_dir)
            if rel_dir == ".":
                path = file
            else:
                # Replace OS backslashes with forward slashes for Godot consistency
                path = os.path.join(rel_dir, file).replace("\\", "/")
            
            physical.add(path)
                
    return physical

def run_audit():
    print("--- Memoria Comprehensive Asset Audit ---")
    print(f"Project Root: {PROJECT_ROOT}")
    
    ref_assets = get_referenced_assets()
    phys_assets = get_physical_assets(ASSETS_DIR)
    
    missing_files = ref_assets - phys_assets
    unused_files = phys_assets - ref_assets

    print(f"\nAudit Results:")
    print(f"  - Unique asset references found in project: {len(ref_assets)}")
    print(f"  - Physical files found in /assets/: {len(phys_assets)}")

    if missing_files:
        print("\n❌ MISSING ASSETS (Referenced in code/scenes but not found on disk):")
        for asset in sorted(missing_files):
            print(f"  - res://assets/{asset}")
    else:
        print("\n✅ No missing assets found.")

    if unused_files:
        print("\n⚠️ UNUSED ASSETS (On disk but not referenced in code or scenes):")
        print("   (Double check before deleting! Some might be dynamically constructed strings.)")
        for asset in sorted(unused_files):
            print(f"  - {asset}")
    else:
        print("\n✅ Every asset on disk is referenced in the project.")

if __name__ == "__main__":
    run_audit()