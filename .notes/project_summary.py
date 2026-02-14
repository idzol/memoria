# Generates a structured summary of the project directory based on the feature-based refactor.
# Usage: 
# ```
# python3 project_summary.py
# ```

import os
import re

def generate_summary():
    # Define new project directories based on the refactor plan
    target_dirs = ["core", "data", "features", "assets"]
    output_file = ".notes/SUMMARY.md"
    
    # Ensure .notes directory exists
    if not os.path.exists(".notes"):
        os.makedirs(".notes")

    with open(output_file, "w", encoding="utf-8") as f:
        f.write("# Memory Dungeon: Project Summary\n\n")
        f.write("Generated automatically for AI context and debugging.\n\n")

        for target in target_dirs:
            if not os.path.exists(target):
                continue
                
            f.write(f"## /{target}\n")
            f.write("```text\n")
            
            for root, dirs, files in os.walk(target):
                # Calculate indentation level based on subfolder depth
                level = root.replace(target, '').count(os.sep)
                indent = ' ' * 4 * level
                folder_name = os.path.basename(root)
                
                if folder_name != target:
                    f.write(f"{indent}📂 {folder_name}/\n")
                
                sub_indent = ' ' * 4 * (level + 1)
                for file in sorted(files):
                    # Filter for relevant Godot file types including the new .tres resources
                    if file.endswith(('.tscn', '.gd', '.png', '.import', '.tres')):
                        icon = "🎬 " if file.endswith(".tscn") \
                               else "📜 " if file.endswith(".gd") \
                               else "💎 " if file.endswith(".tres") \
                               else "🖼️ "
                        f.write(f"{sub_indent}{icon}{file}\n")
            
            f.write("```\n\n")

        # Logical Mapping (Scenes to Scripts)
        f.write("## 🔗 Scene-to-Script Mapping\n")
        f.write("| Scene (.tscn) | Script (.gd) | Location |\n")
        f.write("| :--- | :--- | :--- |\n")
        
        # Search through the 'features' and 'ui' folders for scene-script pairings
        search_roots = ["features", "core"]
        for s_root in search_roots:
            if not os.path.exists(s_root): continue
            
            for root, _, files in os.walk(s_root):
                for file in files:
                    if file.endswith(".tscn"):
                        scene_path = os.path.join(root, file)
                        script_path = "N/A"
                        
                        try:
                            with open(scene_path, 'r') as scene_file:
                                content = scene_file.read()
                                # Robust regex to find any GDScript path referenced as an external resource
                                match = re.search(r'path="res://([^"]+\.gd)"', content)
                                if match:
                                    script_path = "/" + match.group(1)
                        except Exception:
                            pass
                            
                        f.write(f"| {file} | {script_path} | {root} |\n")

    print(f"Summary successfully written to {output_file}")

if __name__ == "__main__":
    generate_summary()