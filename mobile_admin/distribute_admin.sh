#!/bin/bash

# Ensure script stops on first error
set -e

# Configuration
TESTERS_FILE="testers.txt"
ANDROID_APP_ID="1:641268154673:android:3cb2f1b4ba7f7a1828f010"
IOS_APP_ID="1:641268154673:ios:b9e3504f1680dd2628f010"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper function for printing
echo_info() { echo -e "${YELLOW}>>> $1${NC}"; }
echo_success() { echo -e "${GREEN}>>> $1${NC}"; }
echo_error() { echo -e "${RED}>>> $1${NC}"; }

# Check dependencies
if ! command -v firebase &> /dev/null; then
    echo_error "Firebase CLI could not be found. Please install it: npm install -g firebase-tools"
    exit 1
fi

if ! command -v flutter &> /dev/null; then
    echo_error "Flutter could not be found. Please ensure it is in your PATH."
    exit 1
fi

# Ensure testers file exists
if [ ! -f "$TESTERS_FILE" ]; then
    echo_error "$TESTERS_FILE not found. Creating an empty one. Please add tester emails to it."
    touch "$TESTERS_FILE"
    exit 1
fi

# Generate Release Notes from latest git commit
RELEASE_NOTES=$(git log -1 --pretty=format:"%s")

deploy_android() {
    echo_info "Building Android APK..."
    flutter build apk --release
    
    echo_info "Distributing Android APK to Firebase..."
    firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
        --app "$ANDROID_APP_ID" \
        --testers-file "$TESTERS_FILE" \
        --release-notes "$RELEASE_NOTES"
        
    echo_success "Android distribution complete!"
}

deploy_ios() {
    echo_info "Building iOS IPA..."
    # Note: Requires an exportOptions.plist configured for Ad-Hoc/Enterprise distribution
    flutter build ipa --release
    
    echo_info "Distributing iOS IPA to Firebase..."
    firebase appdistribution:distribute build/ios/ipa/*.ita \
        --app "$IOS_APP_ID" \
        --testers-file "$TESTERS_FILE" \
        --release-notes "$RELEASE_NOTES"
        
    echo_success "iOS distribution complete!"
}

# Main routing
case "$1" in
    android)
        deploy_android
        ;;
    ios)
        deploy_ios
        ;;
    both)
        deploy_android
        # ios requires specific build config that often fails on simple scripts without exportOptions, so we do it sequentially.
        deploy_ios
        ;;
    *)
        echo "Usage: $0 {android|ios|both}"
        exit 1
esac
