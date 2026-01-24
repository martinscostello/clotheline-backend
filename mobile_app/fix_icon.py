from PIL import Image
import os
import sys

def flatten_image(input_path, output_path, bg_color=(14, 165, 232)): # #0EA5E8
    try:
        img = Image.open(input_path).convert("RGBA")
        background = Image.new("RGB", img.size, bg_color)
        background.paste(img, mask=img.split()[3]) # 3 is the alpha channel
        background.save(output_path, "JPEG", quality=95)
        print(f"Flattened {input_path} to {output_path} on {bg_color}")
    except Exception as e:
        print(f"Failed to flatten {input_path}: {e}")

def strip_alpha_channel(file_path):
    try:
        img = Image.open(file_path)
        if img.mode != 'RGB':
            rgb_img = img.convert('RGB')
            rgb_img.save(file_path, "PNG")
            print(f"Converted {os.path.basename(file_path)} to RGB (stripped alpha).")
        else:
            print(f"Skipping {os.path.basename(file_path)} (already RGB).")
    except Exception as e:
        print(f"Failed to process {file_path}: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "flatten":
        # Usage: python fix_icon.py flatten <input> <output>
        if len(sys.argv) == 4:
            flatten_image(sys.argv[2], sys.argv[3])
        else:
            print("Usage: python fix_icon.py flatten <input> <output>")
    else:
        # Default behavior: scan directory
        ios_icon_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
        print(f"Scanning {ios_icon_dir} for PNGs to strip alpha...")
        if os.path.exists(ios_icon_dir):
            for filename in os.listdir(ios_icon_dir):
                if filename.lower().endswith('.png'):
                    file_path = os.path.join(ios_icon_dir, filename)
                    strip_alpha_channel(file_path)
        else:
            print(f"Directory not found: {ios_icon_dir}")
        print("Done.")
