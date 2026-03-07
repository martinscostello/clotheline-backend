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
cd mobile_admin
flutter clean
flutter pub get
flutter build web --release --base-href "/"

echo "==== Preparing Output ===="
cd ..
rm -rf public
mkdir -p public
cp -R mobile_admin/build/web/* public/
cp mobile_admin/build/web/.* public/ 2>/dev/null || :
mkdir -p public/pricelist/benin
mkdir -p public/pricelist/abuja
cp mobile_admin/web/pricelist-app.html public/pricelist/benin/index.html
cp mobile_admin/web/pricelist-app.html public/pricelist/abuja/index.html
cp mobile_admin/web/pricelist.js public/

echo "==== Build Complete ===="
