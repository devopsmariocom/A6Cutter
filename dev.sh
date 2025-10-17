#!/bin/bash

# A6Cutter Development Helper Script
# This script helps with local development and testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to show help
show_help() {
    echo "A6Cutter Development Helper"
    echo ""
    echo "Usage: ./dev.sh [command]"
    echo ""
    echo "Commands:"
    echo "  build       - Build the app with proper version info"
    echo "  run         - Build and run the app"
    echo "  clean       - Clean build artifacts"
    echo "  version     - Show current version info"
    echo "  dmg         - Create DMG for distribution"
    echo "  release     - Create full release build"
    echo "  help        - Show this help"
    echo ""
    echo "Examples:"
    echo "  ./dev.sh run"
    echo "  ./dev.sh build"
    echo "  ./dev.sh dmg"
}

# Function to check if we're in the right directory
check_directory() {
    if [ ! -f "A6Cutter.xcodeproj/project.pbxproj" ]; then
        print_error "Not in A6Cutter project directory!"
        print_status "Please run this script from the A6Cutter project root."
        exit 1
    fi
}

# Function to get version info
get_version_info() {
    print_status "Getting version information..."
    
    # Try to get version from git tag
    VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")
    BUILD_NUMBER=$(git rev-parse --short HEAD 2>/dev/null || echo "dev")
    GIT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "dev")
    
    print_success "Version: $VERSION"
    print_success "Build: $BUILD_NUMBER"
    print_success "Git Hash: $GIT_HASH"
}

# Function to update Info.plist
update_info_plist() {
    print_status "Updating Info.plist with version information..."
    
    # Update version and build number
    plutil -replace CFBundleShortVersionString -string "$VERSION" A6Cutter/Info.plist
    plutil -replace CFBundleVersion -string "$BUILD_NUMBER" A6Cutter/Info.plist
    
    # Add git hash to Info.plist
    plutil -replace GitHash -string "$GIT_HASH" A6Cutter/Info.plist
    
    print_success "Info.plist updated successfully"
}

# Function to build the app
build_app() {
    print_status "Building A6Cutter..."
    
    # Update version info first
    update_info_plist
    
    # Build the app
    xcodebuild -scheme A6Cutter -configuration Release -destination "platform=macOS" build
    
    print_success "Build completed successfully!"
}

# Function to run the app
run_app() {
    print_status "Running A6Cutter..."
    
    # Find the built app
    APP_PATH=$(find /Users/$(whoami)/Library/Developer/Xcode/DerivedData -name "A6Cutter.app" -path "*/Build/Products/Release/*" 2>/dev/null | head -1)
    
    if [ -z "$APP_PATH" ]; then
        print_error "Could not find built app. Please run './dev.sh build' first."
        exit 1
    fi
    
    if [ ! -d "$APP_PATH" ]; then
        print_error "App found but is not a valid directory: $APP_PATH"
        exit 1
    fi
    
    print_success "Opening app: $APP_PATH"
    open "$APP_PATH"
}

# Function to create DMG
create_dmg() {
    print_status "Creating DMG..."
    
    # Find the built app
    APP_PATH=$(find /Users/$(whoami)/Library/Developer/Xcode/DerivedData -name "A6Cutter.app" -path "*/Build/Products/Release/*" 2>/dev/null | head -1)
    
    if [ -z "$APP_PATH" ]; then
        print_error "Could not find built app. Please run 'make build' first."
        exit 1
    fi
    
    # Create DMG directory
    mkdir -p build/dmg
    
    # Copy app
    cp -R "$APP_PATH" build/dmg/
    
    # Create Applications shortcut
    ln -s /Applications build/dmg/
    
    # Create README
    echo "Drag A6Cutter.app to Applications folder" > build/dmg/README.txt
    
    # Create DMG
    hdiutil create -volname "A6Cutter" -srcfolder build/dmg -ov -format UDZO build/A6Cutter.dmg
    
    print_success "DMG created: build/A6Cutter.dmg"
}

# Function to clean build artifacts
clean_build() {
    print_status "Cleaning build artifacts..."
    
    rm -rf build/
    xcodebuild clean -scheme A6Cutter -configuration Release
    
    print_success "Build artifacts cleaned"
}

# Main script logic
check_directory

case "${1:-help}" in
    "build")
        get_version_info
        build_app
        ;;
    "run")
        get_version_info
        build_app
        run_app
        ;;
    "clean")
        clean_build
        ;;
    "version")
        get_version_info
        ;;
    "dmg")
        create_dmg
        ;;
    "release")
        get_version_info
        clean_build
        build_app
        create_dmg
        print_success "Release build completed!"
        ;;
    "help"|*)
        show_help
        ;;
esac
