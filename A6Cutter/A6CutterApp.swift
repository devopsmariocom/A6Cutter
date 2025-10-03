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
    
    // Update progress state
    @State private var showUpdateProgress = false
    @State private var updateCurrentVersion = ""
    @State private var updateLatestVersion = ""
    @State private var updateReleaseNotes = ""
    
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
            // Remove 'v' prefix if present for consistent comparison
            return version.hasPrefix("v") ? String(version.dropFirst()) : version
        }
        return "1.0.0"
    }
    
    private func fetchLatestRelease(completion: @escaping (GitHubRelease?) -> Void) {
        let urlString = "https://api.github.com/repos/devopsmariocom/A6Cutter/releases/latest"
        print("DEBUG: Fetching from URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("DEBUG: Failed to create URL from string: \(urlString)")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("A6Cutter/\(getCurrentAppVersion())", forHTTPHeaderField: "User-Agent")
        
        print("DEBUG: Making request with headers: \(request.allHTTPHeaderFields ?? [:])")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("DEBUG: GitHub API error: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            // Debug: Print raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("DEBUG: GitHub API response: \(responseString)")
            }
            
            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                print("DEBUG: Parsed release - tagName: '\(release.tagName)', name: '\(release.name)'")
                completion(release)
            } catch {
                print("DEBUG: JSON decode error: \(error)")
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
        updateCurrentVersion = currentVersion
        updateLatestVersion = latestVersion
        updateReleaseNotes = releaseNotes
        showUpdateProgress = true
    }
    
    // Update functionality moved to UpdateProgressView
    
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
                .sheet(isPresented: $showUpdateProgress) {
                    UpdateProgressView(
                        isPresented: $showUpdateProgress,
                        currentVersion: updateCurrentVersion,
                        latestVersion: updateLatestVersion,
                        releaseNotes: updateReleaseNotes
                    )
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About A6Cutter") {
                    self.openAboutWindow()
                }
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    self.checkForUpdates()
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
