# A6Cutter Development Guide

This guide explains how to build and develop A6Cutter locally with proper version information.

## Quick Start

### Using the Makefile

```bash
# Build and run the app
make run

# Just build the app
make build

# Create a DMG for distribution
make dmg

# Clean build artifacts
make clean

# Show version information
make version-info
```

### Using the Development Script

```bash
# Build and run the app
./dev.sh run

# Just build the app
./dev.sh build

# Create a DMG
./dev.sh dmg

# Clean build artifacts
./dev.sh clean

# Show version information
./dev.sh version
```

## Version Information

The development tools automatically inject proper version information into the app:

- **Version**: Extracted from the latest git tag (e.g., `v1.0.26`)
- **Build Number**: Short git hash (e.g., `585f76e`)
- **Git Hash**: Full git commit hash
- **Info.plist**: Automatically updated with version data

### Manual Version Override

You can override version information using environment variables:

```bash
# Build with custom version
make run VERSION=v1.2.0 BUILD_NUMBER=123

# Or using the script
VERSION=v1.2.0 BUILD_NUMBER=123 ./dev.sh run
```

## Available Targets

### Makefile Targets

- `help` - Show help message
- `version-info` - Display current version information
- `clean` - Clean build artifacts
- `build` - Build the application
- `run` - Build and run the application
- `dmg` - Create DMG for distribution
- `install` - Install to Applications folder
- `dev-build` - Development build (Debug configuration)
- `dev-run` - Run development build
- `quick-version` - Update version info without full build
- `git-status` - Show git status
- `release` - Create full release build

### Development Script Commands

- `build` - Build the app with proper version info
- `run` - Build and run the app
- `clean` - Clean build artifacts
- `version` - Show current version info
- `dmg` - Create DMG for distribution
- `release` - Create full release build
- `help` - Show help message

## Build Configurations

- **Release**: Optimized build for distribution (`make build`, `make run`)
- **Debug**: Development build with debugging symbols (`make dev-build`, `make dev-run`)

## File Structure

```
A6Cutter/
├── Makefile              # Main build automation
├── dev.sh                # Development helper script
├── A6Cutter/
│   ├── Info.plist        # App metadata (auto-updated)
│   └── ...               # Source files
└── build/                # Build artifacts (created automatically)
    └── dmg/              # DMG contents
```

## Troubleshooting

### Version Information Issues

If version information is not showing correctly:

1. Ensure you're in a git repository
2. Check if you have git tags: `git tag`
3. Verify git status: `make git-status`
4. Manually set version: `make run VERSION=v1.0.0`

### Build Issues

If the build fails:

1. Clean build artifacts: `make clean`
2. Check Xcode installation
3. Verify project structure
4. Try development build: `make dev-build`

### App Not Running

If the app doesn't start:

1. Check build output for errors
2. Verify app location: `make version-info`
3. Try manual launch: `open /path/to/A6Cutter.app`

## CI/CD Integration

The GitHub Actions workflow uses similar version injection:

```yaml
- name: Update version info
  run: |
    plutil -replace CFBundleShortVersionString -string "${{ github.ref_name }}" A6Cutter/Info.plist
    plutil -replace CFBundleVersion -string "${{ github.sha }}" A6Cutter/Info.plist
    plutil -replace GitHash -string "${{ github.sha }}" A6Cutter/Info.plist
```

## Contributing

1. Use `make dev-build` for development
2. Test with `make dev-run`
3. Create release with `make release`
4. Ensure version info is correct before committing

## Environment Variables

- `VERSION` - Version string (default: git tag)
- `BUILD_NUMBER` - Build number (default: git short hash)
- `GIT_HASH` - Full git hash (default: git rev-parse HEAD)
