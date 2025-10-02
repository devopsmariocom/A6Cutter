# 🔄 Sparkle Auto-Updater Setup

This document describes the setup of automatic updater for A6Cutter using the Sparkle framework.

## 📋 Overview

Sparkle allows users to automatically download and install application updates without the need for manual downloads from GitHub.

## 🛠️ Setup

### 1. Local Development

```bash
# Download Sparkle tools
curl -L -o sparkle.tar.xz https://github.com/sparkle-project/Sparkle/releases/latest/download/Sparkle-2.6.0.tar.xz
tar -xf sparkle.tar.xz
mkdir -p bin
cp Sparkle-2.6.0/bin/* ./bin/

# Generate keys (only once)
./scripts/generate_sparkle_keys.sh

# Generate appcast.xml
./scripts/generate_appcast.sh
```

### 2. GitHub Actions

The workflow automatically:
- ✅ Downloads Sparkle tools
- ✅ Generates keys (if they don't exist)
- ✅ Creates appcast.xml
- ✅ Adds appcast.xml to release

## 🔑 Keys and Security

### Private Key
- **Location:** `keys/ed25519_private_key.pem`
- **Security:** NEVER commit to Git!
- **Purpose:** Signing DMG files

### Public Key
- **Location:** `keys/ed25519_public_key.pem`
- **Purpose:** Verifying signatures in the app
- **Info.plist:** Automatically added to `SUPublicEDSAKey`

## 📡 Appcast.xml

### What is it?
- XML file containing information about available updates
- Sparkle uses it to detect new versions
- Automatically generated on each release

### URL Structure
```
https://github.com/mariovejlupek/A6Cutter/releases.atom
```

## 🚀 How it Works

### 1. User opens the app
- Sparkle automatically checks for updates
- Check runs every 24 hours (configurable)

### 2. New version found
- Notification is displayed
- User can download and install

### 3. Installation
- Downloads DMG from GitHub releases
- Verifies signature using public key
- Installs new version
- Restarts the application

## ⚙️ Configuration

### Info.plist Settings

```xml
<key>SUFeedURL</key>
<string>https://github.com/mariovejlupek/A6Cutter/releases.atom</string>

<key>SUPublicEDSAKey</key>
<string>your-public-key-here</string>

<key>SUEnableAutomaticChecks</key>
<true/>

<key>SUCheckInterval</key>
<integer>86400</integer> <!-- 24 hours -->
```

### Menu Items

The app automatically adds:
- **"Check for Updates..."** in A6Cutter menu
- **"Check for Updates..."** in About dialog

## 🧪 Testing

### Local Test
```bash
# Create test release
git tag v1.0.1
git push origin v1.0.1

# GitHub Actions will create release with appcast.xml
```

### Debug Mode
```swift
// In A6CutterApp.swift
updaterController.updater.checkForUpdates()
```

## 🔧 Troubleshooting

### Problem: "No updates found"
- ✅ Check `SUFeedURL` in Info.plist
- ✅ Verify that appcast.xml is available
- ✅ Check that DMG is signed

### Problem: "Invalid signature"
- ✅ Verify that `SUPublicEDSAKey` is correct
- ✅ Check that private key is correct
- ✅ Regenerate keys if needed

### Problem: "Download failed"
- ✅ Check internet connection
- ✅ Verify that DMG URL is available
- ✅ Check GitHub permissions

## 📚 Useful Links

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Sparkle GitHub](https://github.com/sparkle-project/Sparkle)
- [Code Signing Guide](https://sparkle-project.org/documentation/code-signing/)

## 🎯 Next Steps

1. **First release:** Create tag `v1.0.0`
2. **Test:** Open the app and check "Check for Updates"
3. **Second release:** Create tag `v1.0.1` and test auto-update
4. **Monitoring:** Watch GitHub Actions logs

---

**Note:** This setup is fully automatic. Just create a Git tag and GitHub Actions will handle the rest! 🚀
