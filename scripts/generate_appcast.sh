#!/bin/bash

# Generate appcast.xml for Sparkle auto-updater
# This script creates the appcast.xml file that Sparkle uses to check for updates

echo "📡 Generating appcast.xml for A6Cutter..."

# Check if we have the required tools
if [ ! -f "./bin/generate_appcast" ]; then
    echo "❌ generate_appcast tool not found. Please download it from Sparkle repository."
    echo "Download from: https://github.com/sparkle-project/Sparkle/releases"
    exit 1
fi

# Check if we have the private key
if [ ! -f "keys/ed25519_private_key.pem" ]; then
    echo "❌ Private key not found. Please run generate_sparkle_keys.sh first."
    exit 1
fi

# Create releases directory if it doesn't exist
mkdir -p releases

# Generate appcast.xml
echo "Generating appcast.xml..."
./bin/generate_appcast \
    --ed-key-file keys/ed25519_private_key.pem \
    --download-url-prefix "https://github.com/mariovejlupek/A6Cutter/releases/download/" \
    --full-release-notes-url "https://github.com/mariovejlupek/A6Cutter/releases" \
    releases/

# Move appcast.xml to the root directory
if [ -f "releases/appcast.xml" ]; then
    mv releases/appcast.xml .
    echo "✅ appcast.xml generated successfully!"
    echo "📁 appcast.xml is ready for GitHub Pages or your web server"
else
    echo "❌ Failed to generate appcast.xml"
    exit 1
fi

echo "📡 Appcast generation complete!"
echo "🔗 Make sure to host appcast.xml at: https://github.com/mariovejlupek/A6Cutter/releases.atom"
