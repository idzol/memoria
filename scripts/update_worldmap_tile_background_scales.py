import json
import os
import re

from PIL import Image


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
OPAQUE_ALPHA_THRESHOLD = 8


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
        "defaults": {"scale_x": 1.0, "scale_y": 1.0, "offset_x": 0.0, "offset_y": 0.0},
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
            "offset_x": float(parsed_defaults.get("offset_x", 0.0)),
            "offset_y": float(parsed_defaults.get("offset_y", 0.0)),
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
                "offset_x": float(entry.get("offset_x", defaults["defaults"]["offset_x"])),
                "offset_y": float(entry.get("offset_y", defaults["defaults"]["offset_y"])),
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
            "offset_x": float(document["defaults"].get("offset_x", 0.0)),
            "offset_y": float(document["defaults"].get("offset_y", 0.0)),
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


def get_image_file_path(res_path):
    return os.path.join(PROJECT_ROOT, res_path.replace("res://", "").replace("/", os.sep))


def load_image_rgba(res_path):
    file_path = get_image_file_path(res_path)
    if not os.path.exists(file_path):
        return None
    try:
        image = Image.open(file_path).convert("RGBA")
    except OSError:
        return None
    return image


def get_fitted_size(texture_width, texture_height):
    fit_scale = min(HEX_WIDTH / float(texture_width), HEX_HEIGHT / float(texture_height))
    return texture_width * fit_scale, texture_height * fit_scale


def get_minimum_cover_scales(texture_width, texture_height):
    fitted_width, fitted_height = get_fitted_size(texture_width, texture_height)
    if fitted_width <= 0.0 or fitted_height <= 0.0:
        return 1.0, 1.0
    return HEX_WIDTH / fitted_width, HEX_HEIGHT / fitted_height


def find_first_opaque_y_from_top(image, center_x):
    for y in range(image.height):
        if image.getpixel((center_x, y))[3] >= OPAQUE_ALPHA_THRESHOLD:
            return y
    return None


def find_first_opaque_y_from_bottom(image, center_x):
    for y in range(image.height - 1, -1, -1):
        if image.getpixel((center_x, y))[3] >= OPAQUE_ALPHA_THRESHOLD:
            return y
    return None


def find_first_opaque_x_from_left(image, center_y):
    for x in range(image.width):
        if image.getpixel((x, center_y))[3] >= OPAQUE_ALPHA_THRESHOLD:
            return x
    return None


def find_first_opaque_x_from_right(image, center_y):
    for x in range(image.width - 1, -1, -1):
        if image.getpixel((x, center_y))[3] >= OPAQUE_ALPHA_THRESHOLD:
            return x
    return None


def get_center_line_opaque_bounds(image):
    center_x = image.width // 2
    center_y = image.height // 2
    top_y = find_first_opaque_y_from_top(image, center_x)
    bottom_y = find_first_opaque_y_from_bottom(image, center_x)
    left_x = find_first_opaque_x_from_left(image, center_y)
    right_x = find_first_opaque_x_from_right(image, center_y)
    if None in (top_y, bottom_y, left_x, right_x):
        return None
    return {
        "center_x": center_x,
        "center_y": center_y,
        "top_y": top_y,
        "bottom_y": bottom_y,
        "left_x": left_x,
        "right_x": right_x,
    }


def get_minimum_cover_scales_from_center_lines(image):
    opaque_bounds = get_center_line_opaque_bounds(image)
    if opaque_bounds is None:
        return get_minimum_cover_scales(image.width, image.height), (0.0, 0.0), "image_bounds"

    fitted_width, fitted_height = get_fitted_size(image.width, image.height)
    fit_scale_x = fitted_width / float(image.width)
    fit_scale_y = fitted_height / float(image.height)

    top_distance = max(0.0, opaque_bounds["center_y"] - opaque_bounds["top_y"])
    bottom_distance = max(0.0, opaque_bounds["bottom_y"] - opaque_bounds["center_y"])
    left_distance = max(0.0, opaque_bounds["center_x"] - opaque_bounds["left_x"])
    right_distance = max(0.0, opaque_bounds["right_x"] - opaque_bounds["center_x"])

    vertical_half_extent = max(top_distance, bottom_distance) * fit_scale_y
    horizontal_half_extent = max(left_distance, right_distance) * fit_scale_x

    scale_x = 1.0 if horizontal_half_extent <= 0.0 else HEX_WIDTH * 0.5 / horizontal_half_extent
    scale_y = 1.0 if vertical_half_extent <= 0.0 else HEX_HEIGHT * 0.5 / vertical_half_extent
    scale_x = max(1.0, scale_x)
    scale_y = max(1.0, scale_y)
    content_center_x = (opaque_bounds["left_x"] + opaque_bounds["right_x"]) * 0.5
    content_center_y = (opaque_bounds["top_y"] + opaque_bounds["bottom_y"]) * 0.5
    delta_x = content_center_x - opaque_bounds["center_x"]
    delta_y = content_center_y - opaque_bounds["center_y"]
    offset_x = -delta_x * fit_scale_x * scale_x
    offset_y = -delta_y * fit_scale_y * scale_y
    return (scale_x, scale_y), (offset_x, offset_y), "center_lines"


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
    center_line_count = 0
    fallback_count = 0
    for room_res_path, room_file_path in iter_room_resources():
        icon_res_path = read_map_icon_path(room_file_path)
        if not icon_res_path:
            skipped.append((room_res_path, "missing map icon reference"))
            continue
        image = load_image_rgba(icon_res_path)
        if image is None:
            skipped.append((room_res_path, "missing or unsupported image"))
            continue
        (scale_x, scale_y), (offset_x, offset_y), method = get_minimum_cover_scales_from_center_lines(image)
        covered = hex_is_covered(image.width, image.height, scale_x, scale_y)
        if not covered:
            skipped.append((room_res_path, "coverage check failed"))
            continue
        if method == "center_lines":
            center_line_count += 1
        else:
            fallback_count += 1
        settings["rooms"][room_res_path] = {
            "texture_path": icon_res_path,
            "scale_x": round_scale(scale_x),
            "scale_y": round_scale(scale_y),
            "offset_x": round_scale(offset_x),
            "offset_y": round_scale(offset_y),
        }
        updated_count += 1
    save_settings(settings)
    print(f"Updated {updated_count} world map tile scale entries in {SETTINGS_PATH}")
    print(f"  - Used center-line alpha bounds: {center_line_count}")
    print(f"  - Used full-image fallback: {fallback_count}")
    if skipped:
        print("Skipped entries:")
        for room_res_path, reason in skipped:
            print(f"  - {room_res_path}: {reason}")


if __name__ == "__main__":
    update_scales()
