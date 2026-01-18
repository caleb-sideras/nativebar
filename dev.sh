#!/bin/bash
set -e

PROJECT_NAME="nativebar"
PROJECT_FILE="nativebar.xcodeproj" 
SCHEME="nativebar"
CONFIGURATION="Debug"

# Build silently
xcodebuild -project "$PROJECT_FILE" -scheme "$SCHEME" -configuration "$CONFIGURATION" build > /dev/null 2>&1

if [ $? -eq 0 ]; then
    BUILD_DIR="$HOME/Library/Developer/Xcode/DerivedData/$PROJECT_NAME-*/Build/Products/$CONFIGURATION"
    APP_PATH=$(find $BUILD_DIR -name "$PROJECT_NAME.app" -type d 2>/dev/null | head -1)
    
    if [ -n "$APP_PATH" ]; then
        echo "Running in debug mode (Ctrl+C to stop):"
        "$APP_PATH/Contents/MacOS/$PROJECT_NAME"
    else
        echo "Could not locate built app"
        exit 1
    fi
else
    echo "Build failed"
    exit 1
fi