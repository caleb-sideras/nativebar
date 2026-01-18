#!/bin/bash
set -e

PROJECT_NAME="nativebar"
PROJECT_FILE="nativebar.xcodeproj"

xcodebuild -project "$PROJECT_FILE" clean

# Remove derived data
DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData"
if [ -d "$DERIVED_DATA_PATH" ]; then
    find "$DERIVED_DATA_PATH" -name "$PROJECT_NAME-*" -type d -exec rm -rf {} + 2>/dev/null || true
fi

echo "Clean completed"