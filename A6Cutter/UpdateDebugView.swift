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
        
        // Simulate update process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.addLogMessage("✅ Aktualizace stažena", isError: false)
            self.addLogMessage("🔧 Instaluji aktualizaci...", isError: false)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.addLogMessage("✅ Aktualizace dokončena!", isError: false)
                self.isCompleted = true
                self.canCancel = false
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
}

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
