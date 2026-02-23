import os

# --- CONFIGURATION ---
# Set this to the path containing your NPC assets (e.g., "res://assets/npcs" equivalent)
TARGET_DIRECTORY = "./assets/npcs"

# Define the rename mapping: { "old_suffix": "new_suffix" }
RENAME_MAP = {
    "_attack.png": "_interact.png",
    "_defend.png": "_talk.png"
}

def rename_assets():
    if not os.path.exists(TARGET_DIRECTORY):
        print(f"Error: Directory '{TARGET_DIRECTORY}' not found.")
        return

    print(f"Scanning directory: {TARGET_DIRECTORY}...")
    
    rename_count = 0
    
    # Iterate through files in the directory
    for filename in os.listdir(TARGET_DIRECTORY):
        new_filename = filename
        
        # Check if the filename ends with any of our target suffixes
        for old_suffix, new_suffix in RENAME_MAP.items():
            if filename.endswith(old_suffix):
                new_filename = filename.replace(old_suffix, new_suffix)
                break
        
        # If a match was found and the name changed
        if new_filename != filename:
            old_path = os.path.join(TARGET_DIRECTORY, filename)
            new_path = os.path.join(TARGET_DIRECTORY, new_filename)
            
            # Check if target filename already exists to avoid overwriting
            if os.path.exists(new_path):
                print(f"Skipping: {new_filename} already exists.")
                continue
                
            try:
                os.rename(old_path, new_path)
                print(f"Renamed: {filename} -> {new_filename}")
                rename_count += 1
            except Exception as e:
                print(f"Error renaming {filename}: {e}")

    print(f"\nOperation complete. Total files renamed: {rename_count}")

if __name__ == "__main__":
    # Safety confirmation
    confirm = input(f"This will rename files in '{TARGET_DIRECTORY}'. Continue? (y/n): ")
    if confirm.lower() == 'y':
        rename_assets()
    else:
        print("Operation cancelled.")