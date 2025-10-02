//
//  A6CutterApp.swift
//  A6Cutter
//
//  Created by Mario Vejlupek on 01.10.2025.
//

import SwiftUI
import SwiftData
// import Sparkle // TODO: Add Sparkle package dependency in Xcode

// MARK: - GitHub API Models
struct GitHubRelease: Codable, Sendable {
    let tagName: String
    let name: String
    let body: String
    let htmlUrl: String
    let publishedAt: String
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
    }
}

@main
struct A6CutterApp: App {
    @Environment(\.openWindow) private var openWindow
    
    // Sparkle updater controller - TODO: Uncomment after adding Sparkle package
    // private let updaterController = SPUStandardUpdaterController(
    //     startingUpdater: true,
    //     updaterDelegate: nil,
    //     userDriverDelegate: nil
    // )
    
    private func openAboutWindow() {
        // Open the About window using SwiftUI openWindow
        openWindow(id: "about")
    }
    
    private func checkForUpdates() {
        // Check for updates by comparing current version with latest GitHub release
        checkForUpdatesFromGitHub()
    }
    
    private func checkForUpdatesFromGitHub() {
        // Get current app version
        let currentVersion = getCurrentAppVersion()
        
        // Fetch latest release from GitHub
        fetchLatestRelease { latestRelease in
            DispatchQueue.main.async {
                
                if let latestRelease = latestRelease {
                    let latestVersion = latestRelease.tagName.replacingOccurrences(of: "v", with: "")
                    
                    if self.isNewerVersion(latestVersion, than: currentVersion) {
                        self.showUpdateDialog(currentVersion: currentVersion, latestVersion: latestVersion, releaseNotes: latestRelease.body)
                    } else {
                        self.showNoUpdatesDialog()
                    }
                } else {
                    self.showUpdateErrorDialog()
                }
            }
        }
    }
    
    private func getCurrentAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "1.0.0"
    }
    
    private func fetchLatestRelease(completion: @escaping (GitHubRelease?) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/devopsmariocom/A6Cutter/releases/latest") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("A6Cutter/\(getCurrentAppVersion())", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                completion(release)
            } catch {
                print("Error decoding GitHub release: \(error)")
                completion(nil)
            }
        }.resume()
    }
    
    private func isNewerVersion(_ latest: String, than current: String) -> Bool {
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(latestComponents.count, currentComponents.count)
        
        for i in 0..<maxLength {
            let latestValue = i < latestComponents.count ? latestComponents[i] : 0
            let currentValue = i < currentComponents.count ? currentComponents[i] : 0
            
            if latestValue > currentValue {
                return true
            } else if latestValue < currentValue {
                return false
            }
        }
        
        return false
    }
    
    private func showUpdateDialog(currentVersion: String, latestVersion: String, releaseNotes: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "A6Cutter \(latestVersion) is available. You currently have version \(currentVersion).\n\n\(releaseNotes)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download & Install")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Download and install the update directly
            downloadAndInstallUpdate(latestVersion: latestVersion)
        }
    }
    
    private func downloadAndInstallUpdate(latestVersion: String) {
        // Download the DMG from GitHub releases
        let dmgUrl = "https://github.com/devopsmariocom/A6Cutter/releases/download/\(latestVersion)/A6Cutter-\(latestVersion).dmg"
        
        guard let url = URL(string: dmgUrl) else {
            showDownloadError("Invalid download URL")
            return
        }
        
        // Show progress dialog with progress bar and log
        showProgressDialog()
        
        updateProgress("Starting download from: \(dmgUrl)", isError: false)
        
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.updateProgress("Download failed: \(error.localizedDescription)", isError: true)
                    return
                }
                
                guard let localURL = localURL else {
                    self.updateProgress("No local file received", isError: true)
                    return
                }
                
                self.updateProgress("Download completed, starting installation...", isError: false)
                
                // Install the update
                self.installUpdate(from: localURL)
            }
        }
        
        task.resume()
    }
    
    private var progressWindow: NSWindow?
    private var progressBar: NSProgressIndicator?
    private var logTextView: NSTextView?
    private var isExpanded = false
    
    private func showProgressDialog() {
        // Create progress window
        progressWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        guard let window = progressWindow else { return }
        
        window.title = "Updating A6Cutter"
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // Create main view
        let mainView = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 200))
        
        // Progress label
        let progressLabel = NSTextField(labelWithString: "Downloading update...")
        progressLabel.frame = NSRect(x: 20, y: 160, width: 460, height: 20)
        progressLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        mainView.addSubview(progressLabel)
        
        // Progress bar
        progressBar = NSProgressIndicator(frame: NSRect(x: 20, y: 130, width: 460, height: 20))
        progressBar?.style = .bar
        progressBar?.isIndeterminate = true
        progressBar?.startAnimation(nil)
        mainView.addSubview(progressBar!)
        
        // Log text view (initially hidden)
        logTextView = NSTextView(frame: NSRect(x: 20, y: 20, width: 460, height: 80))
        logTextView?.isEditable = false
        logTextView?.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        logTextView?.backgroundColor = NSColor.controlBackgroundColor
        logTextView?.isHidden = true
        mainView.addSubview(logTextView!)
        
        // Expand/Collapse button
        let expandButton = NSButton(title: "Show Log", target: self, action: #selector(toggleLog))
        expandButton.frame = NSRect(x: 20, y: 10, width: 80, height: 25)
        mainView.addSubview(expandButton)
        
        // Cancel button
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelUpdate))
        cancelButton.frame = NSRect(x: 400, y: 10, width: 80, height: 25)
        mainView.addSubview(cancelButton)
        
        window.contentView = mainView
        
        // Initial log message
        updateProgress("Starting update process...", isError: false)
    }
    
    @objc private func toggleLog() {
        guard let logView = logTextView else { return }
        
        isExpanded.toggle()
        
        if isExpanded {
            logView.isHidden = false
            progressWindow?.setContentSize(NSSize(width: 500, height: 300))
        } else {
            logView.isHidden = true
            progressWindow?.setContentSize(NSSize(width: 500, height: 200))
        }
    }
    
    @objc private func cancelUpdate() {
        progressWindow?.close()
        progressWindow = nil
    }
    
    private func updateProgress(_ message: String, isError: Bool = false) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let logMessage = "[\(timestamp)] \(message)\n"
            
            if let logView = self.logTextView {
                let attributedString = NSMutableAttributedString(string: logMessage)
                if isError {
                    attributedString.addAttribute(.foregroundColor, value: NSColor.systemRed, range: NSRange(location: 0, length: logMessage.count))
                } else {
                    attributedString.addAttribute(.foregroundColor, value: NSColor.labelColor, range: NSRange(location: 0, length: logMessage.count))
                }
                
                logView.textStorage?.append(attributedString)
                logView.scrollToEndOfDocument(nil)
            }
        }
    }
    
    private func updateProgressBar(step: Int, total: Int) {
        DispatchQueue.main.async {
            self.progressBar?.isIndeterminate = false
            self.progressBar?.doubleValue = Double(step) / Double(total) * 100.0
        }
    }
    
    private func closeProgressDialog() {
        DispatchQueue.main.async {
            self.progressWindow?.close()
            self.progressWindow = nil
        }
    }
    
    private func installUpdate(from dmgURL: URL) {
        updateProgress("Download completed successfully", isError: false)
        updateProgressBar(step: 1, total: 6)
        
        // Mount the DMG
        updateProgress("Mounting DMG file...", isError: false)
        let mountTask = Process()
        mountTask.launchPath = "/usr/bin/hdiutil"
        mountTask.arguments = ["attach", dmgURL.path, "-nobrowse", "-noverify", "-noautoopen", "-readonly"]
        
        let pipe = Pipe()
        mountTask.standardOutput = pipe
        mountTask.standardError = pipe
        
        mountTask.launch()
        mountTask.waitUntilExit()
        
        if mountTask.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            updateProgress("Failed to mount DMG: \(errorOutput)", isError: true)
            return
        }
        
        updateProgress("DMG mounted successfully", isError: false)
        updateProgressBar(step: 2, total: 6)
        
        // Get the mount point from output
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let lines = output.components(separatedBy: .newlines)
        
        // Find the mount point - hdiutil outputs something like "/dev/disk2s1	/Volumes/A6Cutter"
        var mountPoint = ""
        for line in lines {
            if line.contains("/Volumes/") {
                let components = line.components(separatedBy: .whitespaces)
                for component in components {
                    if component.hasPrefix("/Volumes/") {
                        mountPoint = component
                        break
                    }
                }
                if !mountPoint.isEmpty { break }
            }
        }
        
        if mountPoint.isEmpty {
            updateProgress("Could not find mount point in: \(output)", isError: true)
            return
        }
        
        updateProgress("Found mount point: \(mountPoint)", isError: false)
        updateProgressBar(step: 3, total: 6)
        
        // Copy the app to Applications
        let sourceApp = "\(mountPoint)/A6Cutter.app"
        let destinationApp = "/Applications/A6Cutter.app"
        
        // Check if source app exists
        if !FileManager.default.fileExists(atPath: sourceApp) {
            updateProgress("A6Cutter.app not found in DMG at: \(sourceApp)", isError: true)
            return
        }
        
        updateProgress("Found A6Cutter.app in DMG", isError: false)
        updateProgressBar(step: 4, total: 6)
        
        // Remove existing app
        updateProgress("Removing existing application...", isError: false)
        let removeTask = Process()
        removeTask.launchPath = "/bin/rm"
        removeTask.arguments = ["-rf", destinationApp]
        removeTask.launch()
        removeTask.waitUntilExit()
        
        updateProgress("Existing application removed", isError: false)
        updateProgressBar(step: 5, total: 6)
        
        // Copy new app
        updateProgress("Installing new application...", isError: false)
        let copyTask = Process()
        copyTask.launchPath = "/bin/cp"
        copyTask.arguments = ["-R", sourceApp, "/Applications/"]
        copyTask.launch()
        copyTask.waitUntilExit()
        
        if copyTask.terminationStatus != 0 {
            updateProgress("Failed to copy app to Applications folder", isError: true)
            return
        }
        
        updateProgress("Application installed successfully", isError: false)
        
        // Unmount the DMG
        updateProgress("Cleaning up DMG...", isError: false)
        let unmountTask = Process()
        unmountTask.launchPath = "/usr/bin/hdiutil"
        unmountTask.arguments = ["detach", mountPoint]
        unmountTask.launch()
        unmountTask.waitUntilExit()
        
        updateProgress("DMG unmounted", isError: false)
        updateProgressBar(step: 6, total: 6)
        
        // Launch the updated app
        updateProgress("Launching updated application...", isError: false)
        let launchTask = Process()
        launchTask.launchPath = "/usr/bin/open"
        launchTask.arguments = [destinationApp]
        launchTask.launch()
        
        updateProgress("Update completed successfully! Launching new version...", isError: false)
        
        // Close progress dialog and exit current app
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.closeProgressDialog()
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func showDownloadError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Update Failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showNoUpdatesDialog() {
        let alert = NSAlert()
        alert.messageText = "No Updates Available"
        alert.informativeText = "You are running the latest version of A6Cutter."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showUpdateErrorDialog() {
        let alert = NSAlert()
        alert.messageText = "Update Check Failed"
        alert.informativeText = "Unable to check for updates. Please check your internet connection and try again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About A6Cutter") {
                    openAboutWindow()
                }
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    checkForUpdates()
                }
            }
        }
        
        WindowGroup("About A6Cutter", id: "about") {
            AboutView()
        }
        .defaultSize(width: 500, height: 600)
        .windowResizability(.contentSize)
    }
}
