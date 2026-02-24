import csv
import os

# --- CONFIGURATION ---
# Specialized for Player Progression (Base -> Final)
CSV_FILE = "scripts/sprites/Player.csv" 
OUTPUT_ROOT = "data/player"
PLAYER_SCRIPT_PATH = "res://data/resources/PlayerData.gd"
PLAYER_ASSET_ROOT = "res://assets/player"

def generate_player_tres(row):
    """Generates visual progression resources for Player Classes."""
    entity_id = row['ID'].strip()
    p_class = row.get('Class', 'Archivist').strip()
    stage = row.get('Stage', 'base').strip().lower()
    
    # NEW LOGIC: Remove class prefix from filename and flatten folder
    # If entity_id is 'archivist_base', filename becomes 'base.tres'
    tres_name = stage + ".tres"
    
    # Flattened output: data/player/base.tres
    os.makedirs(OUTPUT_ROOT, exist_ok=True)
    out_path = os.path.join(OUTPUT_ROOT, tres_name)
    
    # NEW LOGIC: Asset prefix now uses 'stage' instead of 'entity_id' 
    # to remove class prefixes from image references (e.g. base_idle.png)
    asset_prefix = f"{PLAYER_ASSET_ROOT}/{stage}"
    
    # 5 Load Steps: Script + Idle + Attack + Defend + (Header)
    lines = [
        '[gd_resource type="Resource" script_class="PlayerData" load_steps=5 format=3]',
        '',
        f'[ext_resource type="Script" path="{PLAYER_SCRIPT_PATH}" id="1_script"]',
        f'[ext_resource type="Texture2D" path="{asset_prefix}_idle.png" id="2_idle"]',
        f'[ext_resource type="Texture2D" path="{asset_prefix}_attack.png" id="3_atk"]',
        f'[ext_resource type="Texture2D" path="{asset_prefix}_defend.png" id="4_def"]',
        '',
        '[resource]',
        'script = ExtResource("1_script")',
        f'player_class = "{p_class}"',
        f'stage = "{stage}"',
        f'description = "{row.get("Description", "").replace("\"", "\\\"")}"',
        'idle_sheet = ExtResource("2_idle")',
        'attack_sheet = ExtResource("3_atk")',
        'defend_sheet = ExtResource("4_def")',
        'hframes = 8', 
        'vframes = 1', 
        'total_frames = 8', 
        'frame_speed = 0.1'
    ]

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    return out_path

def run():
    if not os.path.exists(CSV_FILE):
        print(f"Error: {CSV_FILE} not found.")
        return
        
    count = 0
    with open(CSV_FILE, mode='r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row.get('ID'):
                path = generate_player_tres(row)
                print(f"Generated: {path}")
                count += 1
    print(f"\nSuccess! Converted {count} Player Stages to flat resource files.")

if __name__ == "__main__":
    run()