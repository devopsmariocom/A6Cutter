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
        // Simple check for updates that opens GitHub releases page
        // This is a temporary solution until Sparkle is fully integrated
        if let url = URL(string: "https://github.com/mariovejlupek/A6Cutter/releases") {
            NSWorkspace.shared.open(url)
        }
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
