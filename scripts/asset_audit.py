import os
import re
from datetime import datetime

# --- CONFIGURATION ---
def find_project_root():
    """Looks for the project.godot file starting from the script's location."""
    current_path = os.path.dirname(os.path.abspath(__file__))
    while current_path != os.path.dirname(current_path):
        if "project.godot" in os.listdir(current_path):
            return current_path
        current_path = os.path.dirname(current_path)
    return os.path.dirname(os.path.abspath(__file__))

PROJECT_ROOT = find_project_root()
DATA_DIR = os.path.join(PROJECT_ROOT, "data")
ASSETS_DIR = os.path.join(PROJECT_ROOT, "assets")
OUTPUT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "asset_audit.md")

# Categories we expect to find in res://data/
CATEGORIES = ["cards", "enemies", "items", "npcs", "player", "rooms", "map"]

def get_physical_assets():
    """Maps every file in res://assets/ for fast lookup."""
    assets = {} # path : exists
    for root, _, files in os.walk(ASSETS_DIR):
        for file in files:
            if file.endswith(".import"): continue
            rel_path = os.path.relpath(os.path.join(root, file), PROJECT_ROOT).replace("\\", "/")
            assets["res://" + rel_path] = True
    return assets

def audit_tres_file(file_path, physical_assets):
    """Parses a Godot .tres file to check if its ExtResources exist."""
    missing = []
    found_refs = []
    
    # Regex to find Godot resource paths: path="res://..."
    path_pattern = re.compile(r'path="res://([^"]+)"')
    
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
            references = path_pattern.findall(content)
            
            for ref in references:
                full_res_path = "res://" + ref
                found_refs.append(full_res_path)
                
                # Check if it's a script dependency or an asset dependency
                # We prioritize checking assets/ references
                if "res://assets/" in full_res_path:
                    if full_res_path not in physical_assets:
                        missing.append(full_res_path)
                else:
                    # Generic check for scripts or other resources
                    phys_path = os.path.join(PROJECT_ROOT, ref)
                    if not os.path.exists(phys_path):
                        missing.append(full_res_path)
                        
    except Exception as e:
        return {"error": str(e), "missing": [], "refs": []}

    return {"error": None, "missing": missing, "refs": found_refs}

def run_audit():
    print(f"Starting Resource Audit: {PROJECT_ROOT}")
    physical_assets = get_physical_assets()
    
    report_data = {} # category : { "total": 0, "broken": [], "healthy_count": 0 }
    all_referenced_assets = set()

    for cat in CATEGORIES:
        cat_path = os.path.join(DATA_DIR, cat)
        report_data[cat] = {"total": 0, "broken": [], "healthy_count": 0}
        
        if not os.path.exists(cat_path):
            continue

        for root, _, files in os.walk(cat_path):
            for file in files:
                if file.endswith(".tres"):
                    report_data[cat]["total"] += 1
                    full_phys_path = os.path.join(root, file)
                    rel_res_path = "res://" + os.path.relpath(full_phys_path, PROJECT_ROOT).replace("\\", "/")
                    
                    result = audit_tres_file(full_phys_path, physical_assets)
                    
                    for r in result["refs"]:
                        all_referenced_assets.add(r)

                    if result["missing"] or result["error"]:
                        report_data[cat]["broken"].append({
                            "name": file,
                            "path": rel_res_path,
                            "issues": result["missing"] if not result["error"] else [result["error"]]
                        })
                    else:
                        report_data[cat]["healthy_count"] += 1

    # Identify orphaned assets (Files in res://assets/ not used by any .tres)
    orphans = []
    for asset in physical_assets:
        if asset not in all_referenced_assets:
            # Filter out common engine files that wouldn't be in a .tres
            if not any(x in asset for x in ["icon.svg", "default_env"]):
                orphans.append(asset)

    _generate_markdown(report_data, orphans)

def _generate_markdown(report, orphans):
    lines = [
        "# Memory Dungeon: Asset & Resource Audit",
        f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n",
        "## 📊 Category Health",
        "| Category | Total Resources | Healthy | Broken | Status |",
        "| :--- | :---: | :---: | :---: | :--- |"
    ]

    total_broken = 0
    for cat in CATEGORIES:
        data = report[cat]
        broken_count = len(data["broken"])
        total_broken += broken_count
        status = "✅ OK" if broken_count == 0 else "❌ FAILED"
        if data["total"] == 0: status = "⚪ EMPTY"
        
        lines.append(f"| {cat.capitalize()} | {data['total']} | {data['healthy_count']} | {broken_count} | {status} |")

    if total_broken > 0:
        lines.append("\n## ❌ Broken Resources Details")
        for cat in CATEGORIES:
            if report[cat]["broken"]:
                lines.append(f"\n### {cat.capitalize()}")
                for item in report[cat]["broken"]:
                    lines.append(f"- **{item['name']}** (`{item['path']}`)")
                    for issue in item["issues"]:
                        lines.append(f"  - ⚠️ Missing: `{issue}`")

    if orphans:
        lines.append("\n## 🧹 Orphaned Assets (Unused)")
        lines.append("> These assets exist in `res://assets/` but are not referenced by any `.tres` file.")
        for orphan in sorted(orphans):
            lines.append(f"- `{orphan}`")

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    
    print(f"Audit Complete! Report saved to {OUTPUT_FILE}")
    if total_broken > 0:
        print(f"Found {total_broken} broken resources. Please check the report.")

if __name__ == "__main__":
    run_audit()