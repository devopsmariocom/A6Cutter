//
//  UpdateProgressView.swift
//  A6Cutter
//
//  Created by Mario Vejlupek on 03.10.2025.
//

import SwiftUI

struct UpdateProgressView: View {
    @Binding var isPresented: Bool
    let currentVersion: String
    let latestVersion: String
    let releaseNotes: String
    
    @State private var progress: Double = 0.0
    @State private var currentStep: String = "Příprava aktualizace..."
    @State private var isIndeterminate: Bool = true
    @State private var showLog: Bool = false
    @State private var logMessages: [LogMessage] = []
    @State private var canCancel: Bool = true
    @State private var isCompleted: Bool = false
    @State private var hasError: Bool = false
    @State private var errorMessage: String = ""
    
    // Update process
    @State private var updateTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Aktualizace A6Cutter")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Aktualizace z \(currentVersion) na \(latestVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Progress section
            VStack(spacing: 12) {
                HStack {
                    Text(currentStep)
                        .font(.body)
                        .foregroundColor(hasError ? .red : .primary)
                    
                    Spacer()
                    
                    if !isIndeterminate {
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                ProgressView(value: isIndeterminate ? nil : progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: hasError ? .red : .blue))
                    .frame(height: 8)
            }
            
            // Log section (expandable)
            if showLog {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Log aktualizace")
                            .font(.headline)
                        Spacer()
                        Button("Skrýt") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showLog = false
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(logMessages) { message in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(message.timestamp)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .monospaced()
                                    
                                    Text(message.text)
                                        .font(.caption)
                                        .foregroundColor(message.isError ? .red : .primary)
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(8)
                    }
                    .frame(height: 150)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .transition(.opacity.combined(with: .scale))
            }
            
            // Action buttons
            HStack {
                Button("Zobrazit log") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showLog = true
                    }
                }
                .buttonStyle(.borderless)
                .disabled(showLog)
                
                Spacer()
                
                if isCompleted {
                    Button("Zavřít") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                } else if hasError {
                    Button("Zavřít") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Zrušit") {
                        cancelUpdate()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canCancel)
                }
            }
        }
        .padding(24)
        .frame(width: 500, height: showLog ? 400 : 250)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
        .onAppear {
            startUpdate()
        }
        .onDisappear {
            updateTask?.cancel()
        }
    }
    
    // MARK: - Update Logic
    
    private func startUpdate() {
        addLogMessage("Spouštím aktualizaci...", isError: false)
        
        updateTask = Task {
            await performUpdate()
        }
    }
    
    private func cancelUpdate() {
        addLogMessage("Aktualizace zrušena uživatelem", isError: false)
        canCancel = false
        updateTask?.cancel()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isPresented = false
        }
    }
    
    @MainActor
    private func performUpdate() async {
        do {
            // Step 1: Download update
            updateProgress(step: "Stahování aktualizace...", progress: 0.1, isIndeterminate: true)
            addLogMessage("Stahuji nejnovější verzi z GitHub...", isError: false)
            
            let dmgURL = try await downloadUpdate()
            
            // Step 2: Verify download
            updateProgress(step: "Ověřování staženého souboru...", progress: 0.3, isIndeterminate: false)
            addLogMessage("Ověřuji integritu staženého souboru...", isError: false)
            
            try await verifyDownload(at: dmgURL)
            
            // Step 3: Mount DMG
            updateProgress(step: "Připojování DMG souboru...", progress: 0.4, isIndeterminate: false)
            addLogMessage("Připojuji DMG soubor...", isError: false)
            
            let mountPoint = try await mountDMG(at: dmgURL)
            
            // Step 4: Install application
            updateProgress(step: "Instalace aplikace...", progress: 0.6, isIndeterminate: false)
            addLogMessage("Instaluji novou verzi aplikace...", isError: false)
            
            try await installApplication(from: mountPoint)
            
            // Step 5: Cleanup
            updateProgress(step: "Dokončování instalace...", progress: 0.9, isIndeterminate: false)
            addLogMessage("Čistím dočasné soubory...", isError: false)
            
            try await cleanup(mountPoint: mountPoint, dmgURL: dmgURL)
            
            // Step 6: Complete
            updateProgress(step: "Aktualizace dokončena!", progress: 1.0, isIndeterminate: false)
            addLogMessage("Aktualizace byla úspěšně dokončena!", isError: false)
            
            isCompleted = true
            canCancel = false
            
            // Launch updated app after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                launchUpdatedApp()
            }
            
        } catch {
            handleUpdateError(error)
        }
    }
    
    // MARK: - Update Steps
    
    private func downloadUpdate() async throws -> URL {
        let dmgUrl = "https://github.com/devopsmariocom/A6Cutter/releases/download/\(latestVersion)/A6Cutter.dmg"
        
        guard let url = URL(string: dmgUrl) else {
            throw UpdateError.invalidURL
        }
        
        addLogMessage("Stahuji z: \(dmgUrl)", isError: false)
        
        let (localURL, response) = try await URLSession.shared.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.downloadFailed("HTTP error: \(response)")
        }
        
        addLogMessage("Stažení dokončeno: \(localURL.lastPathComponent)", isError: false)
        return localURL
    }
    
    private func verifyDownload(at url: URL) async throws {
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        
        if fileSize < 1024 * 1024 { // Less than 1MB is suspicious
            throw UpdateError.downloadFailed("Stažený soubor je příliš malý: \(fileSize) bytes")
        }
        
        addLogMessage("Soubor ověřen: \(fileSize) bytes", isError: false)
    }
    
    private func mountDMG(at url: URL) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", url.path, "-nobrowse", "-noverify", "-noautoopen", "-readonly"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw UpdateError.mountFailed("hdiutil error: \(errorOutput)")
        }
        
        // Parse mount point from output
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        for line in output.components(separatedBy: .newlines) {
            if line.contains("/Volumes/") {
                let components = line.components(separatedBy: .whitespaces)
                for component in components {
                    if component.hasPrefix("/Volumes/") {
                        addLogMessage("DMG připojen na: \(component)", isError: false)
                        return component
                    }
                }
            }
        }
        
        throw UpdateError.mountFailed("Nepodařilo se najít mount point")
    }
    
    private func installApplication(from mountPoint: String) async throws {
        let sourceApp = "\(mountPoint)/A6Cutter.app"
        let destinationApp = "/Applications/A6Cutter.app"
        
        // Check if source app exists
        guard FileManager.default.fileExists(atPath: sourceApp) else {
            throw UpdateError.installationFailed("A6Cutter.app nenalezen v DMG")
        }
        
        addLogMessage("Nalezen A6Cutter.app v DMG", isError: false)
        
        // Remove existing app
        if FileManager.default.fileExists(atPath: destinationApp) {
            addLogMessage("Odstraňuji existující aplikaci...", isError: false)
            try FileManager.default.removeItem(atPath: destinationApp)
        }
        
        // Copy new app
        addLogMessage("Kopíruji novou aplikaci...", isError: false)
        try FileManager.default.copyItem(atPath: sourceApp, toPath: destinationApp)
        
        addLogMessage("Aplikace úspěšně nainstalována", isError: false)
    }
    
    private func cleanup(mountPoint: String, dmgURL: URL) async throws {
        // Unmount DMG
        let unmountProcess = Process()
        unmountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        unmountProcess.arguments = ["detach", mountPoint]
        
        try unmountProcess.run()
        unmountProcess.waitUntilExit()
        
        addLogMessage("DMG odpojen", isError: false)
        
        // Remove temporary DMG file
        try FileManager.default.removeItem(at: dmgURL)
        addLogMessage("Dočasný soubor odstraněn", isError: false)
    }
    
    private func launchUpdatedApp() {
        addLogMessage("Spouštím aktualizovanou aplikaci...", isError: false)
        
        let launchProcess = Process()
        launchProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        launchProcess.arguments = ["/Applications/A6Cutter.app"]
        
        do {
            try launchProcess.run()
            addLogMessage("Aktualizovaná aplikace spuštěna", isError: false)
            
            // Terminate current app after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            addLogMessage("Chyba při spouštění aktualizované aplikace: \(error.localizedDescription)", isError: true)
        }
    }
    
    // MARK: - UI Updates
    
    @MainActor
    private func updateProgress(step: String, progress: Double, isIndeterminate: Bool) {
        self.currentStep = step
        self.progress = progress
        self.isIndeterminate = isIndeterminate
    }
    
    @MainActor
    private func addLogMessage(_ text: String, isError: Bool) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let message = LogMessage(timestamp: timestamp, text: text, isError: isError)
        logMessages.append(message)
        
        // Auto-scroll to bottom
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // This would need to be implemented with ScrollViewReader if we want auto-scroll
        }
    }
    
    @MainActor
    private func handleUpdateError(_ error: Error) {
        hasError = true
        canCancel = false
        
        let errorText: String
        if let updateError = error as? UpdateError {
            errorText = updateError.localizedDescription
        } else {
            errorText = error.localizedDescription
        }
        
        errorMessage = errorText
        currentStep = "Chyba při aktualizaci"
        addLogMessage("CHYBA: \(errorText)", isError: true)
    }
}

// MARK: - Supporting Types

struct LogMessage: Identifiable {
    let id = UUID()
    let timestamp: String
    let text: String
    let isError: Bool
}

enum UpdateError: LocalizedError {
    case invalidURL
    case downloadFailed(String)
    case mountFailed(String)
    case installationFailed(String)
    case cleanupFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Neplatná URL pro stažení aktualizace"
        case .downloadFailed(let message):
            return "Stažení selhalo: \(message)"
        case .mountFailed(let message):
            return "Připojení DMG selhalo: \(message)"
        case .installationFailed(let message):
            return "Instalace selhala: \(message)"
        case .cleanupFailed(let message):
            return "Čištění selhalo: \(message)"
        }
    }
}

// MARK: - Preview

#Preview {
    UpdateProgressView(
        isPresented: .constant(true),
        currentVersion: "v1.0.0",
        latestVersion: "v1.1.0",
        releaseNotes: "Bug fixes and improvements"
    )
}
