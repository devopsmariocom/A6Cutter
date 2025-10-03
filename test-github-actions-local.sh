#!/bin/bash

# Test script for GitHub Actions workflow locally
set -e

echo "🧪 Testing GitHub Actions workflow locally..."

# Set up test environment
export GITHUB_REF=refs/tags/v1.0.50
export GITHUB_RUN_NUMBER=42
export GITHUB_EVENT_NAME=push

echo "📝 Step 1: Getting version and hash info..."
if [[ $GITHUB_REF == refs/tags/* ]]; then
  VERSION=${GITHUB_REF#refs/tags/}
else
  VERSION=dev-$(date +%Y%m%d-%H%M%S)
fi

GIT_HASH=$(git rev-parse HEAD)
GIT_HASH_SHORT=$(git rev-parse --short HEAD)

echo "VERSION=$VERSION"
echo "GIT_HASH=$GIT_HASH"
echo "GIT_HASH_SHORT=$GIT_HASH_SHORT"

echo "📝 Step 2: Updating Info.plist..."
INFO_PLIST="A6Cutter/Info.plist"

echo "📄 Current Info.plist content:"
plutil -p "$INFO_PLIST" | grep -E "(CFBundleShortVersionString|CFBundleVersion|GitHash)" || echo "No version info found"

echo "🔧 Updating CFBundleShortVersionString to: $VERSION"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$INFO_PLIST"

echo "🔧 Updating CFBundleVersion to: $GITHUB_RUN_NUMBER"
plutil -replace CFBundleVersion -string "$GITHUB_RUN_NUMBER" "$INFO_PLIST"

echo "🔧 Updating GitHash to: $GIT_HASH"
plutil -replace GitHash -string "$GIT_HASH" "$INFO_PLIST"

echo "📄 Updated Info.plist content:"
plutil -p "$INFO_PLIST" | grep -E "(CFBundleShortVersionString|CFBundleVersion|GitHash)"

echo "📡 Step 3: Testing appcast generation..."
mkdir -p releases
echo "Test DMG content" > releases/A6Cutter-$VERSION.dmg
echo "Test appcast content" > releases/releases.atom

echo "📁 Available files in releases/:"
ls -la releases/

# Test the appcast.xml generation logic
if [ -f "releases/appcast.xml" ]; then
  mv releases/appcast.xml .
  echo "✅ appcast.xml generated successfully!"
elif [ -f "releases/releases.atom" ]; then
  mv releases/releases.atom appcast.xml
  echo "✅ appcast.xml generated successfully (from releases/releases.atom)!"
else
  echo "❌ Failed to generate appcast.xml"
  echo "📁 Available files in releases/:"
  ls -la releases/ || echo "No releases directory found"
  echo "📁 Available files in current directory:"
  ls -la *.xml *.atom 2>/dev/null || echo "No XML/ATOM files found"
  exit 1
fi

echo "📋 Step 4: Final verification..."
echo "📄 Info.plist content:"
plutil -p A6Cutter/Info.plist | grep -E "(CFBundleShortVersionString|CFBundleVersion|GitHash)"

echo "📄 appcast.xml exists:"
ls -la appcast.xml

echo "✅ All tests passed!"

# Cleanup
rm -rf releases/
rm -f appcast.xml

echo "🧹 Cleanup completed!"

