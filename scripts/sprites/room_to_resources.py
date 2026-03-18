import csv
import os
import ast
import re

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

def parse_character_scaling(raw_value):
    value = raw_value.strip()
    if not value:
        return "Vector2(1, 1)"

    cleaned = value.replace("x", ",").replace("X", ",")
    parts = [part.strip() for part in re.split(r"[,\s]+", cleaned) if part.strip()]
    if len(parts) >= 2:
        try:
            x_val = float(parts[0])
            y_val = float(parts[1])
            return f"Vector2({x_val:g}, {y_val:g})"
        except ValueError:
            pass
    return "Vector2(1, 1)"

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
    background_scaling = row.get('background_scaling', row.get('background scaling', 'fixed')).strip().lower() or "fixed"
    if background_scaling not in {"fixed", "proportional"}:
        background_scaling = "fixed"
    character_scaling = parse_character_scaling(row.get('character_scaling', row.get('character scaling', '')))
    floor_path = row.get('floor', '').strip()
    
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
    
    load_steps = 4 + (1 if floor_path else 0)
    floor_resource_id = "4_floor" if floor_path else ""

    lines = [
        f'[gd_resource type="Resource" script_class="RoomData" load_steps={load_steps} format=3]',
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
        f'background_scaling = "{background_scaling}"',
        f'character_scaling = {character_scaling}',
        'music_track = "battle_theme"'
    ]

    if floor_path:
        lines.insert(5, f'[ext_resource type="Texture2D" path="{floor_path}" id="{floor_resource_id}"]')
        lines.insert(6, '')
        lines.insert(-1, f'floor = ExtResource("{floor_resource_id}")')

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
