import json
import os
import sys

base_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
json_path = os.path.join(base_dir, "Contents.json")

try:
    with open(json_path, 'r') as f:
        data = json.load(f)
        
    images = data.get("images", [])
    missing = []
    
    print(f"Checking {len(images)} references in {json_path}...")
    
    for img in images:
        filename = img.get("filename")
        if filename:
            file_path = os.path.join(base_dir, filename)
            if not os.path.exists(file_path):
                missing.append(filename)
            else:
                # Check zero size
                if os.path.getsize(file_path) == 0:
                    print(f"WARNING: {filename} is 0 bytes!")
                    missing.append(filename + " (EMPTY)")

    if missing:
        print("ERROR: The following files referenced in Contents.json are MISSING on disk:")
        for m in missing:
            print(f" - {m}")
        sys.exit(1)
    else:
        print("SUCCESS: All referenced files exist.")
        
except Exception as e:
    print(f"CRITICAL: Failed to validate: {e}")
    sys.exit(1)
