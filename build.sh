#!/bin/bash
set -e

PROJECT_NAME="nativebar"
PROJECT_FILE="nativebar.xcodeproj"
SCHEME="nativebar"
CONFIGURATION="Debug"

xcodebuild -project "$PROJECT_FILE" -scheme "$SCHEME" -configuration "$CONFIGURATION" build

if [ $? -eq 0 ]; then
    echo "Build successful"   
else
    echo "Build failed"
    exit 1
fi
