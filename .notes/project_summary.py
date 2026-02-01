# Generates a structured summary of the project directory,
# Usage: 
# ```
# cd /mnt/c/Documents and Settings/pkubi/My Documents/memory-dungeon
# python3 .notes/project_summary.py
# ```

import os

def generate_summary():
    # Define project directories
    target_dirs = ["assets", "scenes", "scripts"]
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
                level = root.replace(target, '').count(os.sep)
                indent = ' ' * 4 * level
                folder_name = os.path.basename(root)
                if folder_name != target:
                    f.write(f"{indent}📂 {folder_name}/\n")
                
                sub_indent = ' ' * 4 * (level + 1)
                for file in sorted(files):
                    if file.endswith(('.tscn', '.gd', '.png', '.import')):
                        icon = "🎬 " if file.endswith(".tscn") else "📜 " if file.endswith(".gd") else "🖼️ "
                        f.write(f"{sub_indent}{icon}{file}\n")
            
            f.write("```\n\n")

        # Logical Mapping (Scenes to Scripts)
        f.write("## 🔗 Scene-to-Script Mapping\n")
        f.write("| Scene (.tscn) | Script (.gd) | Description |\n")
        f.write("| :--- | :--- | :--- |\n")
        
        # Walk through scenes to find script references
        for root, _, files in os.walk("scenes"):
            for file in files:
                if file.endswith(".tscn"):
                    scene_path = os.path.join(root, file)
                    script_path = "N/A"
                    
                    try:
                        with open(scene_path, 'r') as scene_file:
                            content = scene_file.read()
                            # Basic parser for Godot ext_resource paths
                            if 'res://scripts/' in content:
                                start = content.find('res://scripts/')
                                end = content.find('"', start)
                                script_path = content[start:end]
                    except Exception:
                        pass
                        
                    f.write(f"| {file} | {script_path.replace('res://', '/')} | Auto-detected |\n")

    print(f"Summary successfully written to {output_file}")

if __name__ == "__main__":
    generate_summary()