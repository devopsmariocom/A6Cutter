# GitHub Actions for A6Cutter

This directory contains GitHub Actions workflows for building and releasing the A6Cutter application.

## Workflows

### 1. Build and Release (`build-and-release.yml`)

**Triggers:**
- Push to tags starting with `v*` (e.g., `v1.0.0`)
- Manual workflow dispatch

**What it does:**
- Builds the A6Cutter app in Release configuration
- Creates a DMG file for distribution
- Generates release notes from git commits
- Creates a GitHub release with the DMG file

**Usage:**
1. **Automatic:** Push a tag like `v1.0.0` to trigger release
2. **Manual:** Go to Actions → "Build and Release A6Cutter" → Run workflow

### 2. Create Tag (`create-tag.yml`)

**Triggers:**
- Manual workflow dispatch only

**What it does:**
- Creates and pushes a git tag
- Triggers the build and release workflow

**Usage:**
1. Go to Actions → "Create Tag" → Run workflow
2. Enter version (e.g., `v1.0.0`)
3. This will automatically trigger the build and release

## How to Release

### Method 1: Manual Tag Creation
1. Go to Actions → "Create Tag"
2. Enter version (e.g., `v1.0.0`)
3. Click "Run workflow"
4. The build and release will start automatically

### Method 2: Direct Build and Release
1. Go to Actions → "Build and Release A6Cutter"
2. Enter version (optional)
3. Click "Run workflow"

### Method 3: Git Tag (Command Line)
```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

## Release Notes

Release notes are automatically generated from git commits since the last tag. The workflow includes:

- **What's New** section with commit messages
- **Installation** instructions
- **System Requirements**
- **Features** overview

## Artifacts

- **DMG file:** Ready-to-distribute macOS application
- **Release notes:** Automatically generated from commits
- **GitHub release:** Public release with download link

## Requirements

- macOS runner (automatically provided by GitHub)
- Xcode (latest stable version)
- GitHub token (automatically provided)

## Troubleshooting

### Build Fails
- Check that the Xcode project builds locally
- Ensure all dependencies are properly configured
- Check the Actions logs for specific error messages

### Release Not Created
- Ensure you have push permissions to the repository
- Check that the tag was created successfully
- Verify the GitHub token has release permissions

### DMG Creation Fails
- Check that the app was built successfully
- Ensure the app bundle is in the expected location
- Check the Actions logs for hdiutil errors
