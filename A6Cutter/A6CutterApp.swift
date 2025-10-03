//
//  A6CutterApp.swift
//  A6Cutter
//
//  Created by Mario Vejlupek on 01.10.2025.
//

import SwiftUI
import SwiftData
// import Sparkle // TODO: Add Sparkle package dependency in Xcode


@main
struct A6CutterApp: App {
    @Environment(\.openWindow) private var openWindow
    
    // Update debug state
    @State private var showUpdateDebug = false
    
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
        // Show debug updater
        print("DEBUG: checkForUpdates called - showing debug updater")
        showUpdateDebug = true
    }
    
    
    private func getCurrentAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            print("DEBUG: CFBundleShortVersionString found: '\(version)'")
            // Remove 'v' prefix if present for consistent comparison
            let cleanVersion = version.hasPrefix("v") ? String(version.dropFirst()) : version
            print("DEBUG: Clean version: '\(cleanVersion)'")
            return cleanVersion
        }
        print("DEBUG: CFBundleShortVersionString not found. Using default '1.0.0'")
        return "1.0.0"
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
                .sheet(isPresented: $showUpdateDebug) {
                    UpdateDebugView(isPresented: $showUpdateDebug)
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
