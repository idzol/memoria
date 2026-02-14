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

# Directories to scan for references based on the new structure
SEARCH_DIRS = ["core", "data", "features"]

def get_referenced_assets():
    """
    Scans all .gd, .tscn, and .tres files in core, data, and features 
    for strings containing 'res://assets/'.
    """
    referenced = set()
    dynamic_templates = set()
    
    # Pattern for code and scenes: res://assets/...
    asset_pattern = re.compile(r'res://assets/([^"\'\s>]+)')
    extensions_to_scan = {".gd", ".tscn", ".tres"}

    print(f"Scanning for references in {PROJECT_ROOT}...")
    
    for s_dir in SEARCH_DIRS:
        target_path = os.path.join(PROJECT_ROOT, s_dir)
        if not os.path.exists(target_path):
            continue
            
        for root, dirs, files in os.walk(target_path):
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
                                
                                # Filter: If it contains %s, it's a dynamic template (e.g. room_%s.png)
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
    Returns a tuple of (physical_assets_set, import_files_set).
    """
    physical = set()
    imports = set()
    
    if not os.path.exists(assets_dir):
        print(f"Error: Assets directory not found at {assets_dir}")
        return physical, imports

    for root, _, files in os.walk(assets_dir):
        for file in files:
            # Get relative path from the assets folder
            rel_dir = os.path.relpath(root, assets_dir)
            path = file if rel_dir == "." else os.path.join(rel_dir, file).replace("\\", "/")
            
            if file.endswith(".import"):
                imports.add(path)
            else:
                physical.add(path)
                
    return physical, imports

def run_audit():
    print("--- Memory Dungeon Comprehensive Asset Audit ---")
    print(f"Project Root: {PROJECT_ROOT}")
    
    ref_assets, templates = get_referenced_assets()
    phys_assets, import_files = get_physical_assets(ASSETS_DIR)
    
    missing_files = ref_assets - phys_assets
    unused_files = phys_assets - ref_assets
    
    # Calculate orphaned .import files
    # A .import file is orphaned if 'filename.ext.import' exists but 'filename.ext' does not
    orphaned_imports = []
    for imp in import_files:
        original_file = imp.replace(".import", "")
        if original_file not in phys_assets:
            orphaned_imports.append(imp)

    print(f"\nAudit Results:")
    print(f"  - Unique static asset references found: {len(ref_assets)}")
    print(f"  - Dynamic asset templates detected: {len(templates)}")
    print(f"  - Physical source files found: {len(phys_assets)}")
    print(f"  - Total .import files found: {len(import_files)}")

    if templates:
        print("\n🔍 DYNAMIC TEMPLATES (Requires manual verification):")
        for t in sorted(templates):
            print(f"  - res://assets/{t}")

    if missing_files:
        print("\n❌ MISSING ASSETS (Referenced in code/scenes but not found on disk):")
        for asset in sorted(missing_files):
            print(f"  - res://assets/{asset}")
    else:
        print("\n✅ No missing static assets found.")
        
    if orphaned_imports:
        print(f"\n🧹 ORPHANED .IMPORT FILES ({len(orphaned_imports)})")
        print("   (These were likely left behind after manual file moves. Safe to delete.)")
        for imp in sorted(orphaned_imports):
            print(f"  - res://assets/{imp}")

    if unused_files:
        print("\n⚠️ UNUSED ASSETS (On disk but not referenced directly):")
        print("   (Note: These may be used by the dynamic templates above.)")
        for asset in sorted(unused_files):
            print(f"  - {asset}")
    else:
        print("\n✅ Every asset on disk is referenced in the project.")

if __name__ == "__main__":
    run_audit()