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

NAME_SPANISH_KEYS = ["name_es", "name_espanol", "namespanish", "spanishname"]
NAME_FRENCH_KEYS = ["name_fr", "name_french", "namefr", "frenchname"]
NAME_GERMAN_KEYS = ["name_de", "name_german", "namede", "germanname"]
ITEM_POWER_KEYS = ["item_power", "itempower", "card_power", "cardpower"]

def normalize_row(row):
    return {str(key).strip().lower(): value for key, value in row.items()}

def get_first_value(row, keys, default=""):
    for key in keys:
        value = row.get(key, "")
        if value is not None and str(value).strip() != "":
            return str(value).strip()
    return default

def gd_string(value):
    text = "" if value is None else str(value)
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'

def get_localized_names(row):
    english_name = row.get("name", "Unknown").strip()
    return {
        "name": english_name,
        "name_es": get_first_value(row, NAME_SPANISH_KEYS, english_name),
        "name_fr": get_first_value(row, NAME_FRENCH_KEYS, english_name),
        "name_de": get_first_value(row, NAME_GERMAN_KEYS, english_name),
    }

def get_item_power(row):
    raw_value = get_first_value(row, ITEM_POWER_KEYS, "0")
    try:
        return int(raw_value)
    except ValueError:
        return 0

def generate_item_tres(row):
    # 'ID' is now the descriptive slug (e.g., wood_splinter), 'UID' (item_101) is ignored.
    item_id = row['id'].strip()
    if not item_id: return None
    
    os.makedirs(OUTPUT_ROOT, exist_ok=True)
    out_path = os.path.join(OUTPUT_ROOT, f"{item_id}.tres")
    
    # Asset conventions
    full_art = f"{IMAGE_ROOT}/{item_id}.png"
    icon_art = f"{ICON_ROOT}/{item_id}_icon.png"
    names = get_localized_names(row)
    item_power = get_item_power(row)
    
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
        'name = %s' % gd_string(names["name"]),
        'name_es = %s' % gd_string(names["name_es"]),
        'name_fr = %s' % gd_string(names["name_fr"]),
        'name_de = %s' % gd_string(names["name_de"]),
        f'type = "{row.get("type", "Material")}"',
        f'level = {row.get("level", 1)}',
        f'item_power = {item_power}',
        f'hp = {row.get("hp", 0)}',
        f'attack = {row.get("attack", 0)}',
        f'armour = {row.get("armour", 0)}',
        'effect = %s' % gd_string(row.get("effect", "None")),
        'description = %s' % gd_string(row.get("description", "")),
        'ai_prompt = %s' % gd_string(get_first_value(row, ["ai_image_prompt", "ai prompt"], "")),
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
        for raw_row in reader:
            row = normalize_row(raw_row)
            # DictReader ignores columns like 'UID' if they aren't explicitly accessed
            path = generate_item_tres(row)
            if path:
                count += 1
                
    print(f"Success! Converted {count} items.")

if __name__ == "__main__":
    run()
