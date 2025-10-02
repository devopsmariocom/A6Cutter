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
        // Show progress dialog
        let progressAlert = NSAlert()
        progressAlert.messageText = "Downloading Update"
        progressAlert.informativeText = "Please wait while the update is downloaded and installed..."
        progressAlert.alertStyle = .informational
        progressAlert.addButton(withTitle: "Cancel")
        progressAlert.runModal()
        
        // Download the DMG from GitHub releases
        let dmgUrl = "https://github.com/devopsmariocom/A6Cutter/releases/download/\(latestVersion)/A6Cutter-\(latestVersion).dmg"
        
        guard let url = URL(string: dmgUrl) else {
            showDownloadError("Invalid download URL")
            return
        }
        
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.showDownloadError("Download failed: \(error.localizedDescription)")
                    return
                }
                
                guard let localURL = localURL else {
                    self.showDownloadError("No local file received")
                    return
                }
                
                // Install the update
                self.installUpdate(from: localURL)
            }
        }
        
        task.resume()
    }
    
    private func installUpdate(from dmgURL: URL) {
        // Mount the DMG
        let mountTask = Process()
        mountTask.launchPath = "/usr/bin/hdiutil"
        mountTask.arguments = ["attach", dmgURL.path, "-nobrowse", "-noverify", "-noautoopen"]
        
        let pipe = Pipe()
        mountTask.standardOutput = pipe
        mountTask.standardError = pipe
        
        mountTask.launch()
        mountTask.waitUntilExit()
        
        if mountTask.terminationStatus != 0 {
            showDownloadError("Failed to mount DMG")
            return
        }
        
        // Get the mount point
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let lines = output.components(separatedBy: .newlines)
        let mountPoint = lines.first { $0.contains("/Volumes/") }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if mountPoint.isEmpty {
            showDownloadError("Could not find mount point")
            return
        }
        
        // Copy the app to Applications
        let sourceApp = "\(mountPoint)/A6Cutter.app"
        let destinationApp = "/Applications/A6Cutter.app"
        
        let copyTask = Process()
        copyTask.launchPath = "/bin/rm"
        copyTask.arguments = ["-rf", destinationApp]
        copyTask.launch()
        copyTask.waitUntilExit()
        
        let moveTask = Process()
        moveTask.launchPath = "/bin/cp"
        moveTask.arguments = ["-R", sourceApp, "/Applications/"]
        moveTask.launch()
        moveTask.waitUntilExit()
        
        if moveTask.terminationStatus != 0 {
            showDownloadError("Failed to install update")
            return
        }
        
        // Unmount the DMG
        let unmountTask = Process()
        unmountTask.launchPath = "/usr/bin/hdiutil"
        unmountTask.arguments = ["detach", mountPoint]
        unmountTask.launch()
        unmountTask.waitUntilExit()
        
        // Launch the updated app
        let launchTask = Process()
        launchTask.launchPath = "/usr/bin/open"
        launchTask.arguments = [destinationApp]
        launchTask.launch()
        
        // Exit current app
        NSApplication.shared.terminate(nil)
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
