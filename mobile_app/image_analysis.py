from PIL import Image
import os
import sys

def analyze(path):
    try:
        if not os.path.exists(path):
            print(f"MISSING: {path}")
            return
            
        img = Image.open(path)
        print(f"Analyzing {path} ({img.size} {img.mode})")
        
        # Check standard deviation of color to see if it's solid
        stat = img.getextrema()
        print(f"  Extrema: {stat}")
        
        # Get center pixel
        cx, cy = img.size[0]//2, img.size[1]//2
        center_px = img.getpixel((cx, cy))
        print(f"  Center Pixel: {center_px}")
        
        # Check if all pixels are the same (simplified)
        colors = img.getcolors(maxcolors=1)
        if colors:
            print(f"  RESULT: SOLID COLOR {colors[0][1]}")
        else:
            print(f"  RESULT: VARIANCE DETECTED (Content exists)")
            
    except Exception as e:
        print(f"  ERROR: {e}")

print("--- Source Image ---")
analyze("assets/images/distinct_icon.jpg")

print("\n--- Generated Icon (Sample) ---")
analyze("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png")
