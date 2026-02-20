#!/bin/bash
# Fail on any error
set -e

# Define flutter dir relative to the workspace
export FLUTTER_DIR="/tmp/flutter"
export PATH="$FLUTTER_DIR/bin:$PATH"

echo "==== Downloading dependencies ===="
# Download Flutter SDK (stable)
if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git -b stable $FLUTTER_DIR
fi

echo "==== Doctor ===="
flutter doctor -v

echo "==== Building Web App ===="
cd mobile_app
flutter clean
flutter pub get
flutter build web --release --base-href "/"

echo "==== Preparing Output ===="
cd ..
rm -rf public
mkdir -p public
cp -r mobile_app/build/web/* public/

echo "==== Build Complete ===="
