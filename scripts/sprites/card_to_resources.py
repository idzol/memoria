import csv
import os

# --- CONFIGURATION ---
CSV_FILE = "scripts/sprites/Card.csv" 
OUTPUT_ROOT = "data/cards"
CARD_SCRIPT_PATH = "res://data/resources/CardData.gd"
IMAGE_ROOT = "res://assets/cards/full"
ICON_ROOT = "res://assets/cards/icon"

NAME_SPANISH_KEYS = ["name_es", "name_espanol", "namespanish", "spanishname"]
NAME_FRENCH_KEYS = ["name_fr", "name_french", "namefr", "frenchname"]
NAME_GERMAN_KEYS = ["name_de", "name_german", "namede", "germanname"]
CARD_POWER_KEYS = ["card_power", "cardpower"]

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

def get_card_power(row):
    raw_value = get_first_value(row, CARD_POWER_KEYS, "0")
    try:
        return int(raw_value)
    except ValueError:
        return 0

def generate_card_tres(row):
    card_id = row['id'].strip()
    if not card_id: return None
    
    os.makedirs(OUTPUT_ROOT, exist_ok=True)
    out_path = os.path.join(OUTPUT_ROOT, f"{card_id}.tres")
    
    full_art = f"{IMAGE_ROOT}/{card_id}.png"
    icon_art = f"{ICON_ROOT}/{card_id}_icon.png"
    
    # Metadata extraction
    c_type = row.get('type', 'utility').strip().lower()
    c_rarity = row.get('rarity', 'common').strip().lower()
    names = get_localized_names(row)
    card_power = get_card_power(row)
    
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
        'name = %s' % gd_string(names["name"]),
        'name_es = %s' % gd_string(names["name_es"]),
        'name_fr = %s' % gd_string(names["name_fr"]),
        'name_de = %s' % gd_string(names["name_de"]),
        f'rarity = "{c_rarity}"',
        f'type = "{c_type}"',
        f'card_power = {card_power}',
        f'value = {row.get("value", 0)}',
        'description = %s' % gd_string(row.get("description", "")),
        'special_effect = %s' % gd_string(row.get("special effect", "")),
        'card_image = ExtResource("2_image")',
        'card_icon = ExtResource("3_icon")'
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
            if generate_card_tres(row): count += 1
    print(f"Success! Converted {count} cards with Rarity mapping.")

if __name__ == "__main__":
    run()
