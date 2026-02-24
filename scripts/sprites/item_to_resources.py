import csv
import os

# --- CONFIGURATION ---
# Target: Item.csv (Columns: ID, UID, Name, Type, Level, HP, Attack, Armour, Effect, Description, AI_Image_Prompt)
CSV_FILE = "scripts/sprites/Item.csv" 
OUTPUT_ROOT = "data/items"
ITEM_SCRIPT_PATH = "res://data/resources/ItemData.gd"

# Asset Paths - Assumes naming follows the 'ID' column (e.g. wood_splinter.png)
IMAGE_ROOT = "res://assets/items/full"
ICON_ROOT = "res://assets/items/icon"

def generate_item_tres(row):
    # 'ID' is now the descriptive slug (e.g., wood_splinter), 'UID' (item_101) is ignored.
    item_id = row['ID'].strip()
    if not item_id: return None
    
    os.makedirs(OUTPUT_ROOT, exist_ok=True)
    out_path = os.path.join(OUTPUT_ROOT, f"{item_id}.tres")
    
    # Asset conventions
    full_art = f"{IMAGE_ROOT}/{item_id}.png"
    icon_art = f"{ICON_ROOT}/{item_id}_icon.png"
    
    # Header: Script + Image + Icon + Resource
    lines = [
        '[gd_resource type="Resource" script_class="ItemData" load_steps=4 format=3]',
        '',
        f'[ext_resource type=\"Script\" path=\"{ITEM_SCRIPT_PATH}\" id=\"1_script\"]',
        f'[ext_resource type=\"Texture2D\" path=\"{full_art}\" id=\"2_image\"]',
        f'[ext_resource type=\"Texture2D\" path=\"{icon_art}\" id=\"3_icon\"]',
        '',
        '[resource]',
        'script = ExtResource("1_script")',
        f'item_id = "{item_id}"',
        f'name = "{row.get("Name", "Unknown")}"',
        f'type = "{row.get("Type", "Material")}"',
        f'level = {row.get("Level", 1)}',
        f'hp = {row.get("HP", 0)}',
        f'attack = {row.get("Attack", 0)}',
        f'armour = {row.get("Armour", 0)}',
        f'effect = "{row.get("Effect", "None")}"',
        f'description = "{row.get("Description", "").replace("\"", "\\\"")}"',
        f'ai_prompt = "{row.get("AI_Image_Prompt", "").replace("\"", "\\\"")}"',
        'item_image = ExtResource("2_image")',
        'item_icon = ExtResource("3_icon")'
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
            # DictReader ignores columns like 'UID' if they aren't explicitly accessed
            path = generate_item_tres(row)
            if path:
                count += 1
                
    print(f"Success! Converted {count} items.")

if __name__ == "__main__":
    run()