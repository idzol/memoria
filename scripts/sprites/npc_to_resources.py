import csv
import os
import re
import json

# --- CONFIGURATION ---
# The script expects this file to be in the directory where you RUN the command (Project Root)
CSV_FILE = "scripts/sprites/NPC.csv"
OUTPUT_DIR_ENEMIES = "data/enemies"
OUTPUT_DIR_NPCS = "data/npcs"

# Paths to the .gd scripts (Blueprints)
ENEMY_SCRIPT_PATH = "res://data/resources/EnemyData.gd"
NPC_SCRIPT_PATH = "res://data/resources/NPCData.gd"

# Asset Convention Paths
ENEMY_ASSET_ROOT = "res://assets/enemies"
NPC_ASSET_ROOT = "res://assets/npcs"

def parse_loot(loot_str):
    """
    Parses 'gold (10-20), item1, item2' into:
    gold_min, gold_max, [items]
    """
    gold_min, gold_max = 0, 0
    items = []
    
    # Extract gold range
    gold_match = re.search(r'gold\s*\((\d+)-(\d+)\)', loot_str.lower())
    if gold_match:
        gold_min = int(gold_match.group(1))
        gold_max = int(gold_match.group(2))
    
    # Split items by comma and clean up
    parts = [p.strip() for p in loot_str.split(',')]
    for p in parts:
        if "gold" not in p.lower() and p != "":
            items.append(p)
            
    return gold_min, gold_max, items

def generate_tres(row):
    entity_id = row['ID'].strip()
    raw_type = row['Type'].strip().upper()
    entity_type = "Enemy" if raw_type == "ENEMY" else "NPC"
    
    # 1. Determine destination and script
    if entity_type == "Enemy":
        out_path = os.path.join(OUTPUT_DIR_ENEMIES, f"{entity_id}.tres")
        script_res = ENEMY_SCRIPT_PATH
        asset_prefix = f"{ENEMY_ASSET_ROOT}/{entity_id}"
        # Script + Idle + Attack + Defend = 4 load steps
        load_steps = 4 
    else:
        out_path = os.path.join(OUTPUT_DIR_NPCS, f"{entity_id}.tres")
        script_res = NPC_SCRIPT_PATH
        asset_prefix = f"{NPC_ASSET_ROOT}/{entity_id}"
        # Script + Idle + Talk = 3 load steps
        load_steps = 3

    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    # 2. Parse Loot
    g_min, g_max, items = parse_loot(row.get('Loot', ''))
    
    # 3. Construct the .tres content
    # Preamble and Script
    lines = [
        '[gd_resource type="Resource" script_class="%sData" load_steps=%d format=3]' % (entity_type, load_steps),
        '',
        '[ext_resource type="Script" path="%s" id="1_script"]' % script_res,
        '[ext_resource type="Texture2D" path="%s_idle.png" id="2_idle"]' % asset_prefix,
    ]

    # Type-specific Ext Resources
    if entity_type == "Enemy":
        lines.append('[ext_resource type="Texture2D" path="%s_attack.png" id="3_atk"]' % asset_prefix)
        lines.append('[ext_resource type="Texture2D" path="%s_defend.png" id="4_def"]' % asset_prefix)
    else:
        lines.append('[ext_resource type="Texture2D" path="%s_talk.png" id="3_talk"]' % asset_prefix)

    lines += [
        '',
        '[resource]',
        'script = ExtResource("1_script")',
        'name = "%s"' % row.get('Name', 'Unknown'),
        'biome = "%s"' % row.get('Biome', 'town'),
        'hp = %s' % row.get('HP', '50'),
        # UPDATED: Assuming 8x1 (4096x512) convention for all sheets
        'hframes = 8', 
        'vframes = 1',
        'total_frames = 8',
        'frame_speed = 0.1',
        'idle_sheet = ExtResource("2_idle")'
    ]

    if entity_type == "Enemy":
        lines += [
            'attack_sheet = ExtResource("3_atk")',
            'defend_sheet = ExtResource("4_def")',
            'armor = %s' % row.get('Armor', '0'),
            'base_damage = %s' % row.get('Attack', '10'),
            'difficulty_tier = %s' % row.get('Tier', '1'),
            'xp_reward = %s' % row.get('XP', '20'),
            'gold_min = %d' % g_min,
            'gold_max = %d' % g_max,
            'item_drops = %s' % str(items).replace("'", '"'),
            'initial_dialog = "%s"' % row.get('Greeting', '...').replace('"', '\\"'),
            'probabilities = [0.6, 0.2, 0.1, 0.1]'
        ]
    else:
        # NPC Specifics
        is_merch = row.get('IsMerchant', 'FALSE').upper() == 'TRUE'
        wares_str = row.get('Wares', '{}')
        lines += [
            'talk_sheet = ExtResource("3_talk")',
            'role = "%s"' % row.get('Role', 'Villager'),
            'initial_greeting = "%s"' % row.get('Greeting', 'Hello.').replace('"', '\\"'),
            'dialog_tree_id = "%s"' % row.get('DialogTree', ''),
            'is_merchant = %s' % ("true" if is_merch else "false"),
            'wares = %s' % wares_str,
            'persistence_key = "met_%s"' % entity_id
        ]

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    
    return out_path

def run_converter():
    if not os.path.exists(CSV_FILE):
        print(f"Error: {CSV_FILE} not found in current directory ({os.getcwd()}).")
        print("Ensure you are running the script from the project root.")
        return

    count = 0
    with open(CSV_FILE, mode='r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if not row['ID']: continue
            path = generate_tres(row)
            print(f"Generated: {path}")
            count += 1
            
    print(f"\nSuccess! Converted {count} entities into Godot Resources.")

if __name__ == "__main__":
    run_converter()