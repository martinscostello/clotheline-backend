#!/bin/bash

SOURCE="ios/Runner/Assets.xcassets/AppIcon.appiconset/original.png"
DEST="ios/Runner/Assets.xcassets/AppIcon.appiconset"

# Ensure source exists
if [ ! -f "$SOURCE" ]; then
    echo "Error: Source image not found at $SOURCE"
    exit 1
fi

# Sizes for iPhone and iPad
# Format: Size Filename
# 20pt
sips -z 40 40   "$SOURCE" --out "$DEST/Icon-App-20x20@2x.png"
sips -z 60 60   "$SOURCE" --out "$DEST/Icon-App-20x20@3x.png"
# 29pt
sips -z 58 58   "$SOURCE" --out "$DEST/Icon-App-29x29@2x.png"
sips -z 87 87   "$SOURCE" --out "$DEST/Icon-App-29x29@3x.png"
# 40pt
sips -z 80 80   "$SOURCE" --out "$DEST/Icon-App-40x40@2x.png"
sips -z 120 120 "$SOURCE" --out "$DEST/Icon-App-40x40@3x.png"
# 60pt
sips -z 120 120 "$SOURCE" --out "$DEST/Icon-App-60x60@2x.png"
sips -z 180 180 "$SOURCE" --out "$DEST/Icon-App-60x60@3x.png"
# 76pt (iPad)
sips -z 76 76   "$SOURCE" --out "$DEST/Icon-App-76x76@1x.png"
sips -z 152 152 "$SOURCE" --out "$DEST/Icon-App-76x76@2x.png"
# 83.5pt (iPad Pro)
sips -z 167 167 "$SOURCE" --out "$DEST/Icon-App-83.5x83.5@2x.png"
# 1024pt (App Store)
sips -z 1024 1024 "$SOURCE" --out "$DEST/Icon-App-1024x1024@1x.png"

echo "Icons generated successfully."
