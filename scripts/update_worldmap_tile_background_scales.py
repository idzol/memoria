import json
import os
import re
import struct
import zlib


ROOMS_ROOT = os.path.join("data", "rooms")
SETTINGS_PATH = os.path.join("data", "map", "worldmap_tile_background_scales.json")
HEX_WIDTH = 180.0
HEX_HEIGHT = 180.0
HEX_POINTS = [
    (HEX_WIDTH * 0.5, 0.0),
    (HEX_WIDTH, HEX_HEIGHT * 0.25),
    (HEX_WIDTH, HEX_HEIGHT * 0.75),
    (HEX_WIDTH * 0.5, HEX_HEIGHT),
    (0.0, HEX_HEIGHT * 0.75),
    (0.0, HEX_HEIGHT * 0.25),
]
MAP_ICON_PATH_PATTERN = re.compile(r'path="(res://assets/rooms/map/[^"]+)"')


def find_project_root():
    current_path = os.path.dirname(os.path.abspath(__file__))
    while current_path != os.path.dirname(current_path):
        if os.path.exists(os.path.join(current_path, "project.godot")):
            return current_path
        current_path = os.path.dirname(current_path)
    return os.path.dirname(os.path.abspath(__file__))


PROJECT_ROOT = find_project_root()
ROOMS_DIR = os.path.join(PROJECT_ROOT, ROOMS_ROOT)
SETTINGS_FILE = os.path.join(PROJECT_ROOT, SETTINGS_PATH)


def load_settings():
    defaults = {
        "version": 1,
        "defaults": {"scale_x": 1.0, "scale_y": 1.0},
        "rooms": {},
    }
    if not os.path.exists(SETTINGS_FILE):
        return defaults
    with open(SETTINGS_FILE, "r", encoding="utf-8") as handle:
        try:
            parsed = json.load(handle)
        except json.JSONDecodeError:
            return defaults
    if not isinstance(parsed, dict):
        return defaults
    defaults["version"] = int(parsed.get("version", 1))
    parsed_defaults = parsed.get("defaults", {})
    if isinstance(parsed_defaults, dict):
        defaults["defaults"] = {
            "scale_x": float(parsed_defaults.get("scale_x", 1.0)),
            "scale_y": float(parsed_defaults.get("scale_y", 1.0)),
        }
    parsed_rooms = parsed.get("rooms", {})
    if isinstance(parsed_rooms, dict):
        for room_path, entry in parsed_rooms.items():
            if not isinstance(entry, dict):
                continue
            defaults["rooms"][room_path] = {
                "texture_path": str(entry.get("texture_path", "")),
                "scale_x": float(entry.get("scale_x", defaults["defaults"]["scale_x"])),
                "scale_y": float(entry.get("scale_y", defaults["defaults"]["scale_y"])),
            }
    return defaults


def save_settings(document):
    os.makedirs(os.path.dirname(SETTINGS_FILE), exist_ok=True)
    ordered_rooms = {
        room_path: document["rooms"][room_path]
        for room_path in sorted(document["rooms"].keys())
    }
    payload = {
        "version": int(document.get("version", 1)),
        "defaults": {
            "scale_x": float(document["defaults"].get("scale_x", 1.0)),
            "scale_y": float(document["defaults"].get("scale_y", 1.0)),
        },
        "rooms": ordered_rooms,
    }
    with open(SETTINGS_FILE, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, sort_keys=False)
        handle.write("\n")


def iter_room_resources():
    for root, _, files in os.walk(ROOMS_DIR):
        for file_name in sorted(files):
            if not file_name.endswith(".tres"):
                continue
            full_path = os.path.join(root, file_name)
            rel_path = os.path.relpath(full_path, PROJECT_ROOT).replace("\\", "/")
            yield "res://" + rel_path, full_path


def read_map_icon_path(room_file_path):
    with open(room_file_path, "r", encoding="utf-8", errors="ignore") as handle:
        content = handle.read()
    match = MAP_ICON_PATH_PATTERN.search(content)
    if not match:
        return ""
    return match.group(1)


def read_image_size(res_path):
    file_path = os.path.join(PROJECT_ROOT, res_path.replace("res://", "").replace("/", os.sep))
    if not os.path.exists(file_path):
        return None
    with open(file_path, "rb") as handle:
        header = handle.read(32)
    if header.startswith(b"\x89PNG\r\n\x1a\n"):
        return struct.unpack(">II", header[16:24])
    if header.startswith(b"\xff\xd8"):
        return read_jpeg_size(file_path)
    return None


def read_jpeg_size(file_path):
    with open(file_path, "rb") as handle:
        handle.read(2)
        while True:
            marker_start = handle.read(1)
            if not marker_start:
                return None
            if marker_start != b"\xff":
                continue
            marker = handle.read(1)
            while marker == b"\xff":
                marker = handle.read(1)
            if marker in {b"\xc0", b"\xc1", b"\xc2", b"\xc3", b"\xc5", b"\xc6", b"\xc7", b"\xc9", b"\xca", b"\xcb", b"\xcd", b"\xce", b"\xcf"}:
                block_length = struct.unpack(">H", handle.read(2))[0]
                data = handle.read(block_length - 2)
                height, width = struct.unpack(">HH", data[1:5])
                return width, height
            if marker in {b"\xd8", b"\xd9"}:
                continue
            block_length = struct.unpack(">H", handle.read(2))[0]
            handle.seek(block_length - 2, os.SEEK_CUR)


def get_fitted_size(texture_width, texture_height):
    fit_scale = min(HEX_WIDTH / float(texture_width), HEX_HEIGHT / float(texture_height))
    return texture_width * fit_scale, texture_height * fit_scale


def get_minimum_cover_scales(texture_width, texture_height):
    fitted_width, fitted_height = get_fitted_size(texture_width, texture_height)
    if fitted_width <= 0.0 or fitted_height <= 0.0:
        return 1.0, 1.0
    return HEX_WIDTH / fitted_width, HEX_HEIGHT / fitted_height


def hex_is_covered(texture_width, texture_height, scale_x, scale_y):
    fitted_width, fitted_height = get_fitted_size(texture_width, texture_height)
    displayed_width = fitted_width * scale_x
    displayed_height = fitted_height * scale_y
    left = (HEX_WIDTH - displayed_width) * 0.5
    top = (HEX_HEIGHT - displayed_height) * 0.5
    right = left + displayed_width
    bottom = top + displayed_height
    for point_x, point_y in HEX_POINTS:
        if point_x < left or point_x > right or point_y < top or point_y > bottom:
            return False
    return True


def round_scale(value):
    return round(float(value) + 1e-9, 6)


def update_scales():
    settings = load_settings()
    updated_count = 0
    skipped = []
    for room_res_path, room_file_path in iter_room_resources():
        icon_res_path = read_map_icon_path(room_file_path)
        if not icon_res_path:
            skipped.append((room_res_path, "missing map icon reference"))
            continue
        image_size = read_image_size(icon_res_path)
        if image_size is None:
            skipped.append((room_res_path, "missing or unsupported image"))
            continue
        tex_width, tex_height = image_size
        scale_x, scale_y = get_minimum_cover_scales(tex_width, tex_height)
        covered = hex_is_covered(tex_width, tex_height, scale_x, scale_y)
        if not covered:
            skipped.append((room_res_path, "coverage check failed"))
            continue
        settings["rooms"][room_res_path] = {
            "texture_path": icon_res_path,
            "scale_x": round_scale(scale_x),
            "scale_y": round_scale(scale_y),
        }
        updated_count += 1
    save_settings(settings)
    print(f"Updated {updated_count} world map tile scale entries in {SETTINGS_PATH}")
    if skipped:
        print("Skipped entries:")
        for room_res_path, reason in skipped:
            print(f"  - {room_res_path}: {reason}")


if __name__ == "__main__":
    update_scales()
