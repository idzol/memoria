import csv
import os

# --- CONFIGURATION ---
CSV_FILE = "scripts/sprites/Card.csv" 
OUTPUT_ROOT = "data/cards"
CARD_SCRIPT_PATH = "res://data/resources/CardData.gd"

# Asset Paths (Remaining the same as per requirements)
IMAGE_ROOT = "res://assets/cards/full"
ICON_ROOT = "res://assets/cards/icon"

def generate_card_tres(row):
    card_id = row['ID'].strip()
    if not card_id: return None
    
    # FLATTENED: All .tres files now go directly into the OUTPUT_ROOT
    os.makedirs(OUTPUT_ROOT, exist_ok=True)
    out_path = os.path.join(OUTPUT_ROOT, f"{card_id}.tres")
    
    # Asset conventions (Kept identical)
    full_art = f"{IMAGE_ROOT}/{card_id}.png"
    icon_art = f"{ICON_ROOT}/{card_id}_icon.png"
    
    # Extract Type for metadata
    c_type = row.get('Type', 'utility').strip().lower()
    
    # 4 Load Steps: Script + Image + Icon + Resource Header
    lines = [
        '[gd_resource type="Resource" script_class="CardData" load_steps=4 format=3]',
        '',
        f'[ext_resource type="Script" path="{CARD_SCRIPT_PATH}" id="1_script"]',
        f'[ext_resource type="Texture2D" path="{full_art}" id="2_image"]',
        f'[ext_resource type="Texture2D" path="{icon_art}" id="3_icon"]',
        '',
        '[resource]',
        'script = ExtResource("1_script")',
        f'card_id = "{card_id}"',
        f'name = "{row.get("Name", "Unknown")}"',
        f'type = "{c_type}"',
        f'value = {row.get("Value", 0)}',
        f'description = "{row.get("Description", "").replace("\"", "\\\"")}"',
        f'special_effect = "{row.get("Special Effect", "")}"',
        'card_image = ExtResource("2_image")',
        'card_icon = ExtResource("3_icon")'
    ]

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    return out_path

def run():
    if not os.path.exists(CSV_FILE):
        print(f"Error: {CSV_FILE} not found. Ensure it is in the project root.")
        return
        
    # Ensure the output directory exists
    os.makedirs(OUTPUT_ROOT, exist_ok=True)
    
    count = 0
    with open(CSV_FILE, mode='r', encoding='utf-8') as f:
        # csv.DictReader maps headers to values automatically
        reader = csv.DictReader(f)
        for row in reader:
            path = generate_card_tres(row)
            if path:
                print(f"Generated Card Resource: {path}")
                count += 1
                
    print(f"\nSuccess! Converted {count} cards into Godot Resources in {OUTPUT_ROOT}.")

if __name__ == "__main__":
    run()