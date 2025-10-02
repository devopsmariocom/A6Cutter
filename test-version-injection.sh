#!/bin/bash

# Test script to simulate GitHub Actions version injection
echo "🧪 Testing version injection locally..."

# Simulate GitHub Actions environment variables
export GITHUB_REF="refs/tags/v1.0.5"
export GITHUB_RUN_NUMBER="123"
export GITHUB_OUTPUT="/tmp/github_output"

# Get version and hash info (simulating the workflow step)
if [[ $GITHUB_REF == refs/tags/* ]]; then
  VERSION=${GITHUB_REF#refs/tags/}
elif [[ -n "$GITHUB_EVENT_INPUTS_VERSION" ]]; then
  VERSION=$GITHUB_EVENT_INPUTS_VERSION
else
  VERSION=dev-$(date +%Y%m%d-%H%M%S)
fi

# Get git hash
GIT_HASH=$(git rev-parse HEAD)
GIT_HASH_SHORT=$(git rev-parse --short HEAD)

echo "VERSION=$VERSION" >> $GITHUB_OUTPUT
echo "GIT_HASH=$GIT_HASH" >> $GITHUB_OUTPUT
echo "GIT_HASH_SHORT=$GIT_HASH_SHORT" >> $GITHUB_OUTPUT

echo "Version: $VERSION"
echo "Git Hash: $GIT_HASH_SHORT"

# Test the version injection
echo "🔧 Testing version injection..."
INFO_PLIST="A6Cutter/Info.plist"

# Update version and build number
plutil -replace CFBundleShortVersionString -string "$VERSION" "$INFO_PLIST"
plutil -replace CFBundleVersion -string "$GITHUB_RUN_NUMBER" "$INFO_PLIST"

# Add git hash to Info.plist
plutil -replace GitHash -string "$GIT_HASH" "$INFO_PLIST"

echo "✅ Updated Info.plist with version $VERSION and hash $GIT_HASH_SHORT"

# Verify the changes
echo "📋 Verifying changes:"
echo "Version: $(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")"
echo "Build: $(plutil -extract CFBundleVersion raw "$INFO_PLIST")"
echo "Git Hash: $(plutil -extract GitHash raw "$INFO_PLIST")"
