import csv
import os

# --- CONFIGURATION ---
CSV_FILE = "scripts/sprites/NPC.csv"
OUTPUT_DIR_NPCS = "data/npcs"

NPC_SCRIPT_PATH = "res://data/resources/NPCData.gd"
NPC_ASSET_ROOT = "res://assets/npcs"

def normalize_row(row):
    return {str(key).strip().lower(): value for key, value in row.items()}


def gd_string(value):
    text = "" if value is None else str(value)
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def generate_npc_tres(row):
    entity_id = row["id"].strip()
    out_path = os.path.join(OUTPUT_DIR_NPCS, f"{entity_id}.tres")
    asset_prefix = f"{NPC_ASSET_ROOT}/{entity_id}"

    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    is_merchant = str(row.get("ismerchant", "FALSE")).upper() == "TRUE"
    wares_str = row.get("wares", "{}")

    lines = [
        '[gd_resource type="Resource" script_class="NPCData" load_steps=3 format=3]',
        "",
        '[ext_resource type="Script" path="%s" id="1_script"]' % NPC_SCRIPT_PATH,
        '[ext_resource type="Texture2D" path="%s_idle.png" id="2_idle"]' % asset_prefix,
        '[ext_resource type="Texture2D" path="%s_talk.png" id="3_talk"]' % asset_prefix,
        "",
        "[resource]",
        'script = ExtResource("1_script")',
        'name = %s' % gd_string(row.get("name", "Stranger")),
        'role = %s' % gd_string(row.get("role", "Villager")),
        'biome = %s' % gd_string(row.get("biome", "town")),
        "hframes = 8",
        "vframes = 1",
        "total_frames = 8",
        "frame_speed = 0.1",
        'idle_sheet = ExtResource("2_idle")',
        'talk_sheet = ExtResource("3_talk")',
        'initial_greeting = %s' % gd_string(row.get("greeting", "Hello.")),
        'dialog_tree_id = %s' % gd_string(row.get("dialogtree", "")),
        'is_merchant = %s' % ("true" if is_merchant else "false"),
        'wares = %s' % wares_str,
        'persistence_key = %s' % gd_string("met_%s" % entity_id),
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
            if row.get("type", "").strip().upper() != "NPC":
                continue
            path = generate_npc_tres(row)
            print(f"Generated NPC: {path}")
            count += 1

    print(f"\nSuccess! Converted {count} NPCs into Godot Resources.")


if __name__ == "__main__":
    run_converter()
