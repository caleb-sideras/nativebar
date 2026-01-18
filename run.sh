#!/bin/bash
set -e

PROJECT_NAME="nativebar"
PROJECT_FILE="nativebar.xcodeproj"
SCHEME="nativebar"
CONFIGURATION="Debug"
    
BUILD_DIR="$HOME/Library/Developer/Xcode/DerivedData/$PROJECT_NAME-*/Build/Products/$CONFIGURATION"
APP_PATH=$(find $BUILD_DIR -name "$PROJECT_NAME.app" -type d 2>/dev/null | head -1)
    
open "$APP_PATH"
