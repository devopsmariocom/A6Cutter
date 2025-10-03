import SwiftUI

struct UpdateDebugView: View {
    @Binding var isPresented: Bool
    @State private var logMessages: [LogMessage] = []
    @State private var isCompleted = false
    @State private var hasError = false
    @State private var canCancel = true
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            HStack {
                Text("A6Cutter - Debug Updater")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Zavřít") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }
            
            // Status
            HStack {
                if hasError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Chyba při aktualizaci")
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                } else if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Aktualizace dokončena")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                    Text("Probíhá aktualizace...")
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
            
            // Log area
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Detailní log aktualizace")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("Kopírovat log") {
                        copyLogToClipboard()
                    }
                    .buttonStyle(.borderless)
                    .disabled(logMessages.isEmpty)
                }
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(logMessages) { message in
                            HStack(alignment: .top, spacing: 8) {
                                Text("[\(message.timestamp)]")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                
                                Text(message.text)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(message.isError ? .red : .primary)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(height: 300)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
            }
            
            // Action buttons
            HStack {
                if !isCompleted && !hasError {
                    Button("Zrušit") {
                        cancelUpdate()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canCancel)
                }
                
                Spacer()
                
                Button("Zavřít") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 700, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
        .onAppear {
            startUpdate()
        }
    }
    
    private func startUpdate() {
        addLogMessage("🚀 Spouštím debug updater...", isError: false)
        addLogMessage("📱 Získávám informace o aktuální verzi...", isError: false)
        
        // Get current version
        let currentVersion = getCurrentAppVersion()
        addLogMessage("✅ Aktuální verze: '\(currentVersion)'", isError: false)
        
        // Check if we have a valid current version
        if currentVersion.isEmpty || currentVersion == "1.0.0" {
            addLogMessage("⚠️  Používám výchozí verzi pro lokální testování", isError: false)
        }
        
        addLogMessage("🌐 Kontaktuji GitHub API...", isError: false)
        
        // Fetch latest release
        fetchLatestRelease { latestRelease in
            DispatchQueue.main.async {
                if let latestRelease = latestRelease {
                    let latestVersion = latestRelease.tagName.replacingOccurrences(of: "v", with: "")
                    self.addLogMessage("✅ Nejnovější verze: '\(latestVersion)'", isError: false)
                    self.addLogMessage("📝 Název release: '\(latestRelease.name)'", isError: false)
                    
                    if self.isNewerVersion(latestVersion, than: currentVersion) {
                        self.addLogMessage("🔄 Nalezena novější verze! Spouštím aktualizaci...", isError: false)
                        self.performUpdate(latestVersion: latestVersion, releaseNotes: latestRelease.body)
                    } else {
                        self.addLogMessage("✅ Aplikace je aktuální", isError: false)
                        self.isCompleted = true
                        self.canCancel = false
                    }
                } else {
                    self.addLogMessage("❌ Nepodařilo se získat informace o nejnovější verzi", isError: true)
                    self.hasError = true
                    self.canCancel = false
                }
            }
        }
    }
    
    private func performUpdate(latestVersion: String, releaseNotes: String) {
        addLogMessage("📥 Stahuji aktualizaci...", isError: false)
        
        // Perform actual update
        Task {
            do {
                let dmgURL = try await downloadUpdate(latestVersion: latestVersion)
                addLogMessage("✅ Aktualizace stažena", isError: false)
                
                addLogMessage("🔧 Instaluji aktualizaci...", isError: false)
                try await installUpdate(from: dmgURL)
                
                addLogMessage("✅ Aktualizace dokončena!", isError: false)
                addLogMessage("🔄 Restartuji aplikaci...", isError: false)
                
                await MainActor.run {
                    self.isCompleted = true
                    self.canCancel = false
                }
                
                // Restart the app
                try await restartApplication()
                
            } catch {
                await MainActor.run {
                    self.addLogMessage("❌ Chyba při aktualizaci: \(error.localizedDescription)", isError: true)
                    self.hasError = true
                    self.canCancel = false
                }
            }
        }
    }
    
    private func cancelUpdate() {
        addLogMessage("❌ Aktualizace zrušena uživatelem", isError: false)
        canCancel = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isPresented = false
        }
    }
    
    private func addLogMessage(_ text: String, isError: Bool) {
        let message = LogMessage(
            timestamp: DateFormatter.logFormatter.string(from: Date()),
            text: text,
            isError: isError
        )
        logMessages.append(message)
        
        // Auto-scroll to bottom
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // This would need ScrollViewReader for auto-scroll
        }
    }
    
    private func copyLogToClipboard() {
        let logText = logMessages.map { message in
            "[\(message.timestamp)] \(message.text)"
        }.joined(separator: "\n")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(logText, forType: .string)
        
        addLogMessage("📋 Log zkopírován do clipboardu", isError: false)
    }
    
    // Helper functions from A6CutterApp
    private func getCurrentAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            addLogMessage("🔍 CFBundleShortVersionString nalezen: '\(version)'", isError: false)
            // Remove 'v' prefix if present for consistent comparison
            let cleanVersion = version.hasPrefix("v") ? String(version.dropFirst()) : version
            addLogMessage("🧹 Vyčištěná verze: '\(cleanVersion)'", isError: false)
            return cleanVersion
        }
        addLogMessage("⚠️  CFBundleShortVersionString nenalezen. Používám výchozí '1.0.0'", isError: false)
        return "1.0.0"
    }
    
    private func fetchLatestRelease(completion: @escaping (GitHubRelease?) -> Void) {
        let urlString = "https://api.github.com/repos/devopsmariocom/A6Cutter/releases/latest"
        addLogMessage("🌐 Kontaktuji: \(urlString)", isError: false)
        
        guard let url = URL(string: urlString) else {
            addLogMessage("❌ Neplatná URL: \(urlString)", isError: true)
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("A6Cutter/\(getCurrentAppVersion())", forHTTPHeaderField: "User-Agent")
        
        addLogMessage("📤 Odesílám HTTP request...", isError: false)
        addLogMessage("🔧 Headers: \(request.allHTTPHeaderFields ?? [:])", isError: false)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.addLogMessage("❌ Network error: \(error.localizedDescription)", isError: true)
                    completion(nil)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    self.addLogMessage("📥 HTTP Status: \(httpResponse.statusCode)", isError: false)
                    if httpResponse.statusCode != 200 {
                        self.addLogMessage("❌ HTTP Error: \(httpResponse.statusCode)", isError: true)
                        completion(nil)
                        return
                    }
                }
                
                guard let data = data else {
                    self.addLogMessage("❌ Žádná data nebyla přijata", isError: true)
                    completion(nil)
                    return
                }
                
                // Debug: Print raw response
                if let responseString = String(data: data, encoding: .utf8) {
                    self.addLogMessage("📄 Raw response: \(responseString.prefix(200))...", isError: false)
                }
                
                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    self.addLogMessage("✅ JSON parsed successfully", isError: false)
                    self.addLogMessage("🏷️  Tag: '\(release.tagName)'", isError: false)
                    self.addLogMessage("📝 Name: '\(release.name)'", isError: false)
                    completion(release)
                } catch {
                    self.addLogMessage("❌ JSON parse error: \(error)", isError: true)
                    completion(nil)
                }
            }
        }.resume()
    }
    
    private func isNewerVersion(_ latest: String, than current: String) -> Bool {
        addLogMessage("🔍 Porovnávám verze: '\(current)' vs '\(latest)'", isError: false)
        
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        
        addLogMessage("📊 Latest components: \(latestComponents)", isError: false)
        addLogMessage("📊 Current components: \(currentComponents)", isError: false)
        
        let maxLength = max(latestComponents.count, currentComponents.count)
        
        for i in 0..<maxLength {
            let latestComponent = i < latestComponents.count ? latestComponents[i] : 0
            let currentComponent = i < currentComponents.count ? currentComponents[i] : 0
            
            if latestComponent > currentComponent {
                addLogMessage("✅ Latest is newer (component \(i): \(latestComponent) > \(currentComponent))", isError: false)
                return true
            } else if latestComponent < currentComponent {
                addLogMessage("❌ Current is newer (component \(i): \(currentComponent) > \(latestComponent))", isError: false)
                return false
            }
        }
        
        addLogMessage("⚖️  Versions are equal", isError: false)
        return false
    }
    
    // MARK: - Actual Update Functions
    
    private func downloadUpdate(latestVersion: String) async throws -> URL {
        let versionWithV = latestVersion.hasPrefix("v") ? latestVersion : "v\(latestVersion)"
        let dmgUrl = "https://github.com/devopsmariocom/A6Cutter/releases/download/\(versionWithV)/A6Cutter.dmg"
        
        addLogMessage("📥 Stahuji z: \(dmgUrl)", isError: false)
        
        guard let url = URL(string: dmgUrl) else {
            throw UpdateError.invalidURL
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
                if let error = error {
                    continuation.resume(throwing: UpdateError.downloadFailed(error.localizedDescription))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    continuation.resume(throwing: UpdateError.downloadFailed("HTTP error: \(statusCode)"))
                    return
                }
                
                guard let localURL = localURL else {
                    continuation.resume(throwing: UpdateError.downloadFailed("No local file received"))
                    return
                }
                continuation.resume(returning: localURL)
            }
            task.resume()
        }
    }
    
    private func installUpdate(from dmgURL: URL) async throws {
        addLogMessage("💿 Mountuji DMG...", isError: false)
        
        // Mount DMG
        let mountResult = try await runCommand("hdiutil", arguments: ["attach", dmgURL.path, "-nobrowse", "-quiet"])
        addLogMessage("✅ DMG namountován", isError: false)
        
        // Find mount point
        let mountPoint = try await findMountPoint()
        addLogMessage("📁 Mount point: \(mountPoint)", isError: false)
        
        // Copy app
        let appPath = "\(mountPoint)/A6Cutter.app"
        let targetPath = "/Applications/A6Cutter.app"
        
        addLogMessage("📋 Kopíruji aplikaci...", isError: false)
        addLogMessage("   Z: \(appPath)", isError: false)
        addLogMessage("   Do: \(targetPath)", isError: false)
        
        // Remove old app if exists
        if FileManager.default.fileExists(atPath: targetPath) {
            addLogMessage("🗑️  Odstraňuji starou verzi...", isError: false)
            try await runCommand("rm", arguments: ["-rf", targetPath])
        }
        
        // Copy new app
        try await runCommand("cp", arguments: ["-R", appPath, "/Applications/"])
        addLogMessage("✅ Aplikace zkopírována", isError: false)
        
        // Unmount DMG
        addLogMessage("💿 Odmountovávám DMG...", isError: false)
        try await runCommand("hdiutil", arguments: ["detach", mountPoint, "-quiet"])
        addLogMessage("✅ DMG odmountován", isError: false)
    }
    
    private func restartApplication() async throws {
        addLogMessage("🔄 Spouštím novou verzi...", isError: false)
        
        // Launch new version
        try await runCommand("open", arguments: ["/Applications/A6Cutter.app"])
        
        // Give it time to start
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Quit current version
        addLogMessage("👋 Ukončuji aktuální verzi...", isError: false)
        NSApplication.shared.terminate(nil)
    }
    
    private func findMountPoint() async throws -> String {
        let result = try await runCommand("hdiutil", arguments: ["info", "-plist"])
        
        // Parse plist to find mount point
        if let data = result.data(using: .utf8),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
           let images = plist["images"] as? [[String: Any]] {
            
            for image in images {
                if let entities = image["system-entities"] as? [[String: Any]] {
                    for entity in entities {
                        if let mountPoint = entity["mount-point"] as? String,
                           mountPoint.contains("A6Cutter") {
                            return mountPoint
                        }
                    }
                }
            }
        }
        
        throw UpdateError.installationFailed("Could not find mount point")
    }
    
    private func runCommand(_ command: String, arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/\(command)")
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            addLogMessage("❌ Command failed: \(command) \(arguments.joined(separator: " "))", isError: true)
            addLogMessage("   Exit code: \(process.terminationStatus)", isError: true)
            addLogMessage("   Output: \(output)", isError: true)
            throw UpdateError.installationFailed("Command failed: \(command)")
        }
        
        return output
    }
}

// MARK: - Update Errors
// UpdateError is defined in UpdateProgressView.swift

// MARK: - Supporting Types
// LogMessage is defined in UpdateProgressView.swift

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

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
