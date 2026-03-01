# 
# Creates a "Persona" for your project. When you start a new session, you can simply paste the content of .ai-context.md. 
# The AI will now know that your "Game Manager" is a singleton and that your "Enemy" base class is available globally.
# 
# Usage: 
# ```
# python3 ai_context_generator.py
# ```

import os
import re

def get_godot_project_info():
    """Extracts critical project settings from project.godot."""
    info = {
        "name": "Unknown Godot Project",
        "render_engine": "Unknown",
        "autoloads": []
    }
    if os.path.exists("project.godot"):
        with open("project.godot", "r") as f:
            content = f.read()
            name_match = re.search(r'config/name="([^"]+)"', content)
            if name_match: info["name"] = name_match.group(1)
            
            # Find Autoloads (Singletons)
            autoload_section = re.findall(r'(\w+)="(\*res://[^"]+)"', content)
            for name, path in autoload_section:
                info["autoloads"].append(f"{name} ({path})")
    return info

def extract_global_classes():
    """Finds all class_name declarations in the project."""
    classes = []
    for root, _, files in os.walk("."):
        for file in files:
            if file.endswith(".gd"):
                path = os.path.join(root, file)
                try:
                    with open(path, "r") as f:
                        first_lines = [next(f) for _ in range(10)] # Check top of file
                        for line in first_lines:
                            match = re.match(r'^class_name\s+(\w+)', line)
                            if match:
                                classes.append(f"{match.group(1)} (at {path})")
                except: pass
    return classes

def generate_ai_context():
    project_info = get_godot_project_info()
    global_classes = extract_global_classes()
    
    output_path = "./.notes/ai-context.md"
    
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(f"# AI Context: {project_info['name']}\n\n")
        f.write("## 🛠 Tech Stack\n")
        f.write("- **Engine:** Godot 4.x\n")
        f.write("- **Language:** GDScript\n")
        f.write("- **Architecture:** Feature-based Refactor (Core/Features/Data/Assets)\n\n")
        
        f.write("## 📝 Coding Conventions\n")
        f.write("- Use `class_name` for types to enable IDE-like autocompletion in prompts.\n")
        f.write("- Prefer Signal-based communication for decoupled features.\n")
        f.write("- Standard: `snake_case` for variables/functions, `PascalCase` for classes.\n")
        f.write("- Pathing: Use `res://` absolute paths for resources.\n\n")
        
        f.write("## 🚀 Global Singletons (Autoloads)\n")
        if project_info["autoloads"]:
            for auto in project_info["autoloads"]:
                f.write(f"- {auto}\n")
        else:
            f.write("- None defined.\n")
        f.write("\n")

        f.write("## 🧩 Registered Global Classes\n")
        if global_classes:
            for cls in sorted(global_classes):
                f.write(f"- {cls}\n")
        else:
            f.write("- None detected.\n")
            
        f.write("\n## 📂 Key Directories\n")
        f.write("- `/core`: Essential engine systems (Managers, Base Classes).\n")
        f.write("- `/features`: Modular gameplay elements.\n")
        f.write("- `/data`: Resource files (.tres) and data definitions.\n")
        
    print(f"Successfully generated {output_path}")

if __name__ == "__main__":
    generate_ai_context()