import os
from PIL import Image

# Configuration: Folder path and the target width
# (Height will be calculated automatically to maintain aspect ratio)
targets = {
    "./assets/card_full": 512,
    "./assets/card_icon": 256,
    "./assets/enemies": 2048,
    "./assets/npcs": 2048,
    "./assets/player": 2048,
    "./assets/maps/backgrounds": 1024,
    "./assets/maps/grids": 256,
    "./assets/maps/icons": 128,
    "./assets/rooms": 512
}

def resize_images():
    for folder, target_width in targets.items():
        if not os.path.exists(folder):
            print(f"Skipping {folder}: Directory not found.")
            continue

        print(f"Processing folder: {folder}...")

        for filename in os.listdir(folder):
            if filename.lower().endswith(".png"):
                img_path = os.path.join(folder, filename)
                
                with Image.open(img_path) as img:
                    # Calculate proportional height
                    width_percent = (target_width / float(img.size[0]))
                    target_height = int((float(img.size[1]) * float(width_percent)))

                    # Only resize if the image isn't already the target size
                    if img.size[0] == target_width:
                        print(f"  - {filename} is already {target_width}px. Skipping.")
                        continue

                    # Resize using LANCZOS for high-quality downsampling
                    resized_img = img.resize((target_width, target_height), Image.Resampling.LANCZOS)
                    
                    # Overwrite the original file
                    resized_img.save(img_path, "PNG")
                    print(f"  - Resized {filename} to {target_width}x{target_height}")

    print("\nBatch resizing complete!")

if __name__ == "__main__":
    resize_images()