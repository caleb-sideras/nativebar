#!/bin/bash
set -e

PROJECT_FILE="nativebar.xcodeproj"
SCHEME="nativebar"

# Install xcode-build-server if needed
if ! command -v xcode-build-server >/dev/null 2>&1; then
    echo "Installing xcode-build-server..."
    brew install xcode-build-server
fi

# Clean up manual configurations
rm -f compile_commands.json Package.swift

# Generate Build Server Protocol configuration
echo "Generating buildServer.json..."
xcode-build-server config -project "$PROJECT_FILE" -scheme "$SCHEME"

if [ -f buildServer.json ]; then
    echo "LSP setup complete"
    echo "Restart your editor and configure it to use buildServer workspace type"
else
    echo "Failed to create buildServer.json"
    exit 1
fi