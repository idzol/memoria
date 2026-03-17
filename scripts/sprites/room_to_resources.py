import csv
import os
import ast

# --- CONFIGURATION ---
CSV_FILE = "scripts/sprites/Room.csv" 
OUTPUT_ROOT = "data/rooms"
ROOM_SCRIPT_PATH = "res://data/resources/RoomData.gd"
ASSET_ROOT = "res://assets/rooms"

def normalize_row(row):
    return {str(key).strip().lower(): value for key, value in row.items()}

def infer_type(row):
    explicit_type = row.get('type', '').strip().lower()
    if explicit_type:
        return explicit_type
    enemy = row.get('enemy', '').strip()
    npc = row.get('npc id', '').strip()
    object_id = row.get('object_id', '').strip()
    event = row.get('event id', '').strip()
    if enemy: return "battle"
    if object_id: return "event"
    if event or npc: return "event"
    return "lore"

def parse_complete_condition(raw_value):
    value = raw_value.strip()
    if not value:
        return {}
    try:
        parsed = ast.literal_eval(value)
        return parsed if isinstance(parsed, dict) else {}
    except (ValueError, SyntaxError):
        return {}

def generate_room_tres(row):
    room_id = row['id'].strip()
    if not room_id: return None
    
    biome = row.get('region', 'town').strip().lower()
    name = row.get('name', 'Unknown Location')
    dialog = row.get('dialog', '').replace('"', '\\"')
    tree_id = row.get('dialog tree', '').strip()
    npc_id = row.get('npc id', '').strip()
    enemy_id = row.get('enemy', '').strip()
    object_id = row.get('object_id', '').strip()
    difficulty_tier = row.get('difficulty_tier', '').strip() or "-1"
    loot_raw = row.get('loot', '').strip()
    complete_condition = parse_complete_condition(row.get('complete_condition', ''))
    
    # Path setup: data/rooms/town/town_village_gate.tres
    out_dir = os.path.join(OUTPUT_ROOT, biome)
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, f"{room_id}.tres")
    
    # ASSET CONVENTION: Organized by Biome
    # map_icon_path = f"{ASSET_ROOT}/{biome}/{room_id}_map.png"
    # scene_bg_path = f"{ASSET_ROOT}/{biome}/{room_id}_scene.png"
    map_icon_path = f"{ASSET_ROOT}/map/{room_id}.png"
    scene_bg_path = f"{ASSET_ROOT}/scene/{room_id}_room.png"
    
    loot_array = [i.strip() for i in loot_raw.split(',')] if loot_raw else []
    
    # 4 Load Steps: Header + Script + MapIcon + SceneBG
    lines = [
        '[gd_resource type="Resource" script_class="RoomData" load_steps=4 format=3]',
        '',
        f'[ext_resource type="Script" path="{ROOM_SCRIPT_PATH}" id="1_script"]',
        f'[ext_resource type="Texture2D" path="{map_icon_path}" id="2_icon"]',
        f'[ext_resource type="Texture2D" path="{scene_bg_path}" id="3_bg"]',
        '',
        '[resource]',
        'script = ExtResource("1_script")',
        f'room_name = "{name}"',
        f'type = "{infer_type(row)}"',
        f'biome = "{biome}"',
        f'initial_dialog = "{dialog}"',
        f'dialog_tree_id = "{tree_id}"',
        f'enemy_id = "{enemy_id}"',
        f'npc_id = "{npc_id}"',
        f'object_id = "{object_id}"',
        f'difficulty_tier = {difficulty_tier}',
        f'loot_list = {str(loot_array).replace("\'", "\"")}',
        f'complete_condition = {str(complete_condition).replace("\'", "\"")}',
        'map_icon = ExtResource("2_icon")',
        'background_texture = ExtResource("3_bg")',
        'music_track = "battle_theme"'
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
            if row.get('id'):
                if generate_room_tres(row): count += 1
    print(f"Success! Converted {count} rooms.")

if __name__ == "__main__":
    run()
