# 🔄 Sparkle Auto-Updater Integration Guide

This guide explains how to complete the Sparkle auto-updater integration for A6Cutter.

## 📋 Current Status

✅ **Completed:**
- Info.plist configured with Sparkle settings
- GitHub Actions workflow updated for automatic appcast generation
- Scripts created for key generation and appcast creation
- Documentation updated to English
- Code prepared for Sparkle integration (commented out)

⏳ **Pending:**
- Add Sparkle package dependency in Xcode
- Uncomment Sparkle code in A6CutterApp.swift
- Test auto-updater functionality

## 🛠️ Step-by-Step Integration

### 1. Add Sparkle Package Dependency

**In Xcode:**
1. Open `A6Cutter.xcodeproj`
2. Go to **File > Add Package Dependencies...**
3. Enter URL: `https://github.com/sparkle-project/Sparkle`
4. Click **Add Package**
5. Select **Sparkle** and click **Add Package**

### 2. Enable Sparkle Code

**In A6CutterApp.swift:**
1. Uncomment the import:
   ```swift
   import Sparkle
   ```

2. Uncomment the updater controller:
   ```swift
   private let updaterController = SPUStandardUpdaterController(
       startingUpdater: true,
       updaterDelegate: nil,
       userDriverDelegate: nil
   )
   ```

3. Uncomment the menu command:
   ```swift
   CommandGroup(after: .appInfo) {
       CheckForUpdatesCommand(updater: updaterController.updater)
   }
   ```

### 3. Test the Integration

**Build and Run:**
1. Build the project (`Cmd+B`)
2. Run the application (`Cmd+R`)
3. Check the **A6Cutter** menu for **"Check for Updates..."** option

## 🎯 Expected Results

### Menu Structure
```
A6Cutter
├── About A6Cutter
└── Check for Updates...
```

### Functionality
- **Automatic checks:** Every 24 hours (configurable)
- **Manual checks:** Via "Check for Updates..." menu
- **Secure updates:** Ed25519 signature verification
- **Seamless installation:** Automatic download and install

## 🔧 Configuration

### Info.plist Settings
The following settings are already configured:

```xml
<key>SUFeedURL</key>
<string>https://github.com/mariovejlupek/A6Cutter/releases.atom</string>

<key>SUPublicEDSAKey</key>
<string>placeholder-key-will-be-generated</string>

<key>SUEnableAutomaticChecks</key>
<true/>

<key>SUCheckInterval</key>
<integer>86400</integer> <!-- 24 hours -->
```

### GitHub Actions
The workflow automatically:
- Downloads Sparkle tools
- Generates signing keys
- Creates appcast.xml
- Signs DMG files
- Uploads to GitHub releases

## 🧪 Testing the Auto-Updater

### 1. Create Test Release
```bash
# Create a new tag
git tag v1.0.1
git push origin v1.0.1

# GitHub Actions will automatically:
# - Build the app
# - Generate appcast.xml
# - Create GitHub release
```

### 2. Test Update Detection
1. Run the current version of the app
2. Go to **A6Cutter > Check for Updates...**
3. The app should detect the new version
4. Follow the update installation process

## 🔍 Troubleshooting

### Build Errors
- **"Unable to find module dependency: 'Sparkle'"**
  - Solution: Add Sparkle package dependency in Xcode

### Update Detection Issues
- **"No updates found"**
  - Check `SUFeedURL` in Info.plist
  - Verify appcast.xml is available at the URL
  - Ensure DMG is properly signed

### Signature Verification
- **"Invalid signature"**
  - Verify `SUPublicEDSAKey` is correct
  - Check that private key matches public key
  - Regenerate keys if needed

## 📚 Additional Resources

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Sparkle GitHub Repository](https://github.com/sparkle-project/Sparkle)
- [Code Signing Guide](https://sparkle-project.org/documentation/code-signing/)

## 🎉 Completion Checklist

- [ ] Add Sparkle package dependency in Xcode
- [ ] Uncomment Sparkle import in A6CutterApp.swift
- [ ] Uncomment updater controller code
- [ ] Uncomment CheckForUpdatesCommand
- [ ] Build and test the application
- [ ] Verify "Check for Updates..." appears in menu
- [ ] Test update detection with a new release
- [ ] Verify automatic update installation

---

**Note:** Once the Sparkle package is added and code is uncommented, the auto-updater will be fully functional! 🚀
