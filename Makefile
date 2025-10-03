# A6Cutter Makefile for Local Development
# This Makefile provides local build capabilities with proper version injection

# Configuration
APP_NAME = A6Cutter
SCHEME = A6Cutter
CONFIGURATION = Release
DESTINATION = "platform=macOS"

# Version information (can be overridden)
VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")
BUILD_NUMBER ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "dev")
GIT_HASH ?= $(shell git rev-parse HEAD 2>/dev/null || echo "dev")

# Directories
BUILD_DIR = build
DMG_DIR = $(BUILD_DIR)/dmg
APP_PATH = /Users/$(USER)/Library/Developer/Xcode/DerivedData/$(APP_NAME)-*/Build/Products/$(CONFIGURATION)/$(APP_NAME).app

.PHONY: help clean build run dmg version-info

# Default target
help:
	@echo "A6Cutter Makefile - Local Development"
	@echo ""
	@echo "Available targets:"
	@echo "  help        - Show this help message"
	@echo "  version-info- Show current version information"
	@echo "  clean       - Clean build artifacts"
	@echo "  build       - Build the application"
	@echo "  run         - Build and run the application"
	@echo "  dmg         - Create DMG for distribution"
	@echo "  install     - Install to Applications folder"
	@echo ""
	@echo "Environment variables:"
	@echo "  VERSION     - Version string (default: git tag or v1.0.0)"
	@echo "  BUILD_NUMBER- Build number (default: git short hash)"
	@echo "  GIT_HASH    - Full git hash (default: git rev-parse HEAD)"
	@echo ""
	@echo "Examples:"
	@echo "  make run                    # Build and run with default version"
	@echo "  make run VERSION=v1.2.0    # Build and run with specific version"
	@echo "  make dmg                    # Create DMG for distribution"

version-info:
	@echo "Current version information:"
	@echo "  Version: $(VERSION)"
	@echo "  Build: $(BUILD_NUMBER)"
	@echo "  Git Hash: $(GIT_HASH)"
	@echo "  Git Hash (short): $(shell echo $(GIT_HASH) | cut -c1-7)"

clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	xcodebuild clean -scheme $(SCHEME) -configuration $(CONFIGURATION)

# Update Info.plist with version information
update-version:
	@echo "📝 Updating version information..."
	@echo "  Version: $(VERSION)"
	@echo "  Build: $(BUILD_NUMBER)"
	@echo "  Git Hash: $(GIT_HASH)"
	
	# Update Info.plist with version and build number
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" A6Cutter/Info.plist
	plutil -replace CFBundleVersion -string "$(BUILD_NUMBER)" A6Cutter/Info.plist
	
	# Add git hash to Info.plist
	plutil -replace GitHash -string "$(GIT_HASH)" A6Cutter/Info.plist
	
	@echo "✅ Version information updated in Info.plist"

build: update-version
	@echo "🔨 Building $(APP_NAME)..."
	xcodebuild -scheme $(SCHEME) -configuration $(CONFIGURATION) -destination $(DESTINATION) build
	
	@echo "✅ Build completed successfully!"
	@echo "📱 App location: $(APP_PATH)"

run: build
	@echo "🚀 Running $(APP_NAME)..."
	open $(APP_PATH)

install: build
	@echo "📦 Installing $(APP_NAME) to Applications..."
	cp -R $(APP_PATH) /Applications/
	@echo "✅ $(APP_NAME) installed to /Applications/"

dmg: build
	@echo "💿 Creating DMG..."
	
	# Create DMG directory structure
	mkdir -p $(DMG_DIR)
	
	# Copy the built app
	cp -R $(APP_PATH) $(DMG_DIR)/
	
	# Create Applications shortcut (symlink)
	ln -s /Applications $(DMG_DIR)/Applications
	
	# Create installation instructions
	echo "Drag $(APP_NAME).app to Applications folder" > $(DMG_DIR)/README.txt
	
	# Create DMG
	hdiutil create -volname "$(APP_NAME)" -srcfolder $(DMG_DIR) -ov -format UDZO $(BUILD_DIR)/$(APP_NAME).dmg
	
	@echo "✅ DMG created: $(BUILD_DIR)/$(APP_NAME).dmg"

# Development helpers
dev-build: update-version
	@echo "🔨 Development build..."
	xcodebuild -scheme $(SCHEME) -configuration Debug -destination $(DESTINATION) build
	@echo "✅ Development build completed!"

dev-run: dev-build
	@echo "🚀 Running development build..."
	open /Users/$(USER)/Library/Developer/Xcode/DerivedData/$(APP_NAME)-*/Build/Products/Debug/$(APP_NAME).app

# Quick version update without full build
quick-version: update-version
	@echo "✅ Version information updated. Run 'make build' to rebuild with new version."

# Show current git status
git-status:
	@echo "📊 Git status:"
	@echo "  Current branch: $(shell git branch --show-current)"
	@echo "  Latest commit: $(shell git log -1 --oneline)"
	@echo "  Uncommitted changes: $(shell git status --porcelain | wc -l | tr -d ' ') files"

# Create a release build with proper versioning
release: clean version-info build dmg
	@echo "🎉 Release build completed!"
	@echo "📦 DMG: $(BUILD_DIR)/$(APP_NAME).dmg"
	@echo "📱 App: $(APP_PATH)"
