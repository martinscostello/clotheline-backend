import json
import os
from PIL import Image

def generate_icons():
    source_path = "assets/images/final_clean_icon.jpg"
    base_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    json_path = os.path.join(base_dir, "Contents.json")

    if not os.path.exists(source_path):
        print(f"ERROR: Source {source_path} not found!")
        return

    if not os.path.exists(json_path):
        print(f"ERROR: JSON {json_path} not found!")
        return
        
    print(f"Opening source: {source_path}")
    img = Image.open(source_path).convert("RGB")
    
    with open(json_path, 'r') as f:
        data = json.load(f)
        
    images = data.get("images", [])
    print(f"Generating {len(images)} icons...")
    
    for entry in images:
        filename = entry["filename"]
        size_str = entry["size"] # e.g. "20x20"
        scale_str = entry["scale"] # e.g. "2x"
        
        # Calculate pixels
        base_size = float(size_str.split('x')[0])
        scale = int(scale_str.replace('x', ''))
        pixels = int(base_size * scale)
        
        out_path = os.path.join(base_dir, filename)
        
        # Resize
        resized = img.resize((pixels, pixels), Image.Resampling.LANCZOS)
        resized.save(out_path, "PNG")
        print(f"Generated {filename} ({pixels}x{pixels})")
        
    print("DONE. All icons generated manually.")

if __name__ == "__main__":
    generate_icons()
