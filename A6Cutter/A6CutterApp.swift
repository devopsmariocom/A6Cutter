//
//  A6CutterApp.swift
//  A6Cutter
//
//  Created by Mario Vejlupek on 01.10.2025.
//

import SwiftUI
import SwiftData

@main
struct A6CutterApp: App {
    @Environment(\.openWindow) private var openWindow
    
    private func openAboutWindow() {
        // Open the About window using SwiftUI openWindow
        openWindow(id: "about")
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
        }
        
        WindowGroup("About A6Cutter", id: "about") {
            AboutView()
        }
        .defaultSize(width: 500, height: 600)
        .windowResizability(.contentSize)
    }
}
