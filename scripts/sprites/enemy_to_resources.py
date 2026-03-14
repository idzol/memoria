import csv
import os
import re

# --- CONFIGURATION ---
CSV_FILE = "scripts/sprites/Enemy.csv"
OUTPUT_DIR_ENEMIES = "data/enemies"

ENEMY_SCRIPT_PATH = "res://data/resources/EnemyData.gd"
ENEMY_ASSET_ROOT = "res://assets/enemies"

NAME_SPANISH_KEYS = ["namespanish", "name_es", "namees", "spanishname"]
NAME_FRENCH_KEYS = ["namefrench", "name_fr", "namefr", "frenchname"]
NAME_GERMAN_KEYS = ["namegerman", "name_de", "namede", "germanname"]
LOOT_POWER_KEYS = ["lootpower", "loot_power"]

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


def get_loot_power(row):
    raw_value = get_first_value(row, LOOT_POWER_KEYS, "0")
    try:
        return int(raw_value)
    except ValueError:
        return 0


def parse_loot(loot_str):
    gold_min, gold_max = 0, 0
    items = []

    gold_match = re.search(r"gold\s*\((\d+)-(\d+)\)", loot_str.lower())
    if gold_match:
        gold_min = int(gold_match.group(1))
        gold_max = int(gold_match.group(2))

    parts = [part.strip() for part in loot_str.split(",")]
    for part in parts:
        if "gold" not in part.lower() and part != "":
            items.append(part)

    return gold_min, gold_max, items


def generate_enemy_tres(row):
    entity_id = row["id"].strip()
    out_path = os.path.join(OUTPUT_DIR_ENEMIES, f"{entity_id}.tres")
    asset_prefix = f"{ENEMY_ASSET_ROOT}/{entity_id}"

    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    g_min, g_max, items = parse_loot(row.get("loot", ""))
    names = get_localized_names(row)
    loot_power = get_loot_power(row)

    lines = [
        '[gd_resource type="Resource" script_class="EnemyData" load_steps=4 format=3]',
        "",
        '[ext_resource type="Script" path="%s" id="1_script"]' % ENEMY_SCRIPT_PATH,
        '[ext_resource type="Texture2D" path="%s_idle.png" id="2_idle"]' % asset_prefix,
        '[ext_resource type="Texture2D" path="%s_attack.png" id="3_atk"]' % asset_prefix,
        '[ext_resource type="Texture2D" path="%s_defend.png" id="4_def"]' % asset_prefix,
        "",
        "[resource]",
        'script = ExtResource("1_script")',
        'name = %s' % gd_string(names["name"]),
        'name_es = %s' % gd_string(names["name_es"]),
        'name_fr = %s' % gd_string(names["name_fr"]),
        'name_de = %s' % gd_string(names["name_de"]),
        'biome = %s' % gd_string(row.get("biome", "town")),
        'hp = %s' % row.get("hp", "50"),
        "hframes = 8",
        "vframes = 1",
        "total_frames = 8",
        "frame_speed = 0.1",
        'idle_sheet = ExtResource("2_idle")',
        'attack_sheet = ExtResource("3_atk")',
        'defend_sheet = ExtResource("4_def")',
        'armor = %s' % row.get("armor", "0"),
        'base_damage = %s' % row.get("attack", "10"),
        'difficulty_tier = %s' % row.get("tier", "1"),
        'xp_reward = %s' % row.get("xp", "20"),
        'loot_power = %d' % loot_power,
        'gold_min = %d' % g_min,
        'gold_max = %d' % g_max,
        'item_drops = %s' % str(items).replace("'", '"'),
        'initial_dialog = %s' % gd_string(row.get("greeting", "...")),
        "probabilities = [0.6, 0.2, 0.1, 0.1]",
    ]

    with open(out_path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))

    return out_path


def run_converter():
    if not os.path.exists(CSV_FILE):
        print(f"Error: {CSV_FILE} not found in current directory ({os.getcwd()}).")
        print("Ensure you are running the script from the project root.")
        return

    count = 0
    with open(CSV_FILE, mode="r", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for raw_row in reader:
            row = normalize_row(raw_row)
            if not row.get("id"):
                continue
            if row.get("type", "").strip().upper() != "ENEMY":
                continue
            path = generate_enemy_tres(row)
            print(f"Generated Enemy: {path}")
            count += 1

    print(f"\nSuccess! Converted {count} enemies into Godot Resources.")


if __name__ == "__main__":
    run_converter()
