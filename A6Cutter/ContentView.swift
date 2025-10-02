import SwiftUI
import PDFKit
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Localization Helper
extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}

struct ContentView: View {
    @State private var isImporterPresented = false
    @State private var isPrintPresented = false
    @FocusState private var isPrintButtonFocused: Bool
    @FocusState private var isHorizontalShiftFocused: Bool
    @FocusState private var isVerticalShiftFocused: Bool
    @FocusState private var isSkipPagesFocused: Bool
    @State private var cutDocument: PDFDocument?
    @State private var originalDocument: PDFDocument?
    @State private var pageCount: Int = 0
    
    // Computed property pro finální počet stránek po odečtení vynechaných
    private var finalPageCount: Int {
        if skipPagesEnabled {
            let skipPagesList = parseSkipPages()
            return max(0, pageCount - skipPagesList.count)
        } else {
            return pageCount
        }
    }
    
    // UserDefaults klíče pro ukládání nastavení
    private let horizontalShiftKey = "horizontalShift"
    private let verticalShiftKey = "verticalShift"
    private let skipPagesKey = "skipPages"
    private let rotateToPortraitKey = "rotateToPortrait"
    private let disableCuttingKey = "disableCutting"
    private let rotateClockwiseKey = "rotateClockwise"
    private let rotationEnabledKey = "rotationEnabled"
    private let cuttingEnabledKey = "cuttingEnabled"
    private let skipPagesEnabledKey = "skipPagesEnabled"
    private let modificationsEnabledKey = "modificationsEnabled"
    private let presetsKey = "presets"
    private let currentPresetKey = "currentPreset"
    
    // Parametry pro posunutí řezů
    @State private var horizontalShift: Double = -15.0
    @State private var verticalShift: Double = 30.0
    
    // Parametry pro vynechání stránek
    @State private var skipPages: String = "2,4,5,6"
    
    // Parametr pro otočení z landscape na portrait
    @State private var rotateToPortrait: Bool = true
    
    // Parametr pro vypnutí řezání
    @State private var disableCutting: Bool = false
    
    // Parametr pro směr otáčení
    @State private var rotateClockwise: Bool = true
    
    // Enable/disable pro každou sekci
    @State private var rotationEnabled: Bool = true
    @State private var cuttingEnabled: Bool = true
    @State private var skipPagesEnabled: Bool = true
    @State private var modificationsEnabled: Bool = false
    
    // Presets
    @State private var presets: [String: [String: Any]] = [:]
    @State private var currentPreset: String = "FedEx"
    @State private var isAddingNewPreset: Bool = false
    @State private var newPresetName: String = ""
    
    private var leftPanel: some View {
        VStack(spacing: 16) {
            // Krok 1: Otočení
            stepSection(
                stepNumber: 1,
                title: "Rotate from landscape to portrait",
                color: .green,
                isEnabled: $rotationEnabled
            ) {
                rotationSection
            }
            
            // Krok 2: Řezání (s posuny)
            stepSection(
                stepNumber: 2,
                title: "Cutting",
                color: .blue,
                isEnabled: $cuttingEnabled
            ) {
                cuttingWithShiftsSection
            }
            
            // Krok 3: Vynechání stránek
            stepSection(
                stepNumber: 3,
                title: "Vynechání stránek",
                color: .orange,
                isEnabled: $skipPagesEnabled
            ) {
                skipPagesSection
            }
            
            // Presets section
            presetsSection
            
            Spacer()
            
            // Enable modifications checkbox
            VStack(spacing: 8) {
                Toggle("Enable modifications".localized, isOn: $modificationsEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            openPDFButton
            if let doc = cutDocument {
                printSection(doc: doc)
            }
        }
        .frame(width: 300)
    }
    
    // Funkce pro vytvoření sekce s číslem kroku
    private func stepSection<Content: View>(
        stepNumber: Int,
        title: String,
        color: Color,
        isEnabled: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // Header s číslem kroku a disable tlačítkem
            HStack {
                ZStack {
                    Circle()
                        .fill(isEnabled.wrappedValue ? color : Color.gray)
                        .frame(width: 24, height: 24)
                    Text("\(stepNumber)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Text(title.localized)
                    .font(.headline)
                    .foregroundColor(isEnabled.wrappedValue ? .primary : .secondary)
                
                Spacer()
                
                // Disable tlačítko v pravém horním rohu
                Button(action: {
                    isEnabled.wrappedValue.toggle()
                }) {
                    Image(systemName: isEnabled.wrappedValue ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isEnabled.wrappedValue ? color : .gray)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!modificationsEnabled)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // Obsah sekce
            content()
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .opacity(isEnabled.wrappedValue ? 1.0 : 0.4)
                .disabled(!isEnabled.wrappedValue || !modificationsEnabled)
        }
        .frame(width: 300, height: 120)
        .background(isEnabled.wrappedValue ? color.opacity(0.08) : Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isEnabled.wrappedValue ? color.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 2)
        )
        .overlay(
            // Overlay pro "Disabled modification" když je modificationsEnabled = false
            Group {
                if !modificationsEnabled {
                    ZStack {
                        Color.black.opacity(0.6)
                            .cornerRadius(12)
                        VStack {
                            Image(systemName: "lock.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                            Text("Disabled modification".localized)
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
        )
    }
    
    // Nová sekce pro řezání s posuny
    private var cuttingWithShiftsSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Horizontální posun".localized + ":")
                    .frame(width: 90, alignment: .leading)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $horizontalShift, in: -100...100, step: 5)
                    .accentColor(.blue)
                Text("\(Int(horizontalShift))")
                    .frame(width: 35)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Vertikální posun".localized + ":")
                    .frame(width: 90, alignment: .leading)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $verticalShift, in: -100...100, step: 5)
                    .accentColor(.blue)
                Text("\(Int(verticalShift))")
                    .frame(width: 35)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var rightPanel: some View {
        VStack(spacing: 16) {
                    if let doc = cutDocument {
                PDFThumbnailsView(document: doc, skipPages: skipPagesEnabled ? parseSkipPages() : [])
                    .id("pdf-thumbnails-\(doc.pageCount)-\(horizontalShift)-\(verticalShift)-\(skipPagesEnabled)-\(rotationEnabled)-\(cuttingEnabled)-\(rotateClockwise)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            } else {
                emptyPreviewView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    
    private var presetsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Presety".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                // Add new preset button
                Button(action: {
                    isAddingNewPreset = true
                    newPresetName = ""
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!modificationsEnabled)
            }
            
            // Presets list
            VStack(spacing: 4) {
                ForEach(Array(presets.keys.sorted()), id: \.self) { presetName in
                    HStack {
                        Button(action: {
                            currentPreset = presetName
                            applyPreset(presetName)
                            savePresets() // Save the current preset selection
                        }) {
                            HStack {
                                Image(systemName: currentPreset == presetName ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(currentPreset == presetName ? .blue : .gray)
                                
                                Text(presetName)
                                    .foregroundColor(.primary)
                                    .font(.system(size: 14))
                                
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(currentPreset == presetName ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Delete button (only for custom presets)
                        if presetName != "Default" && presetName != "FedEx" {
                            Button(action: {
                                deletePreset(presetName)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(!modificationsEnabled)
                        }
                    }
                }
            }
            
            // Add new preset input
            if isAddingNewPreset {
                HStack {
                    TextField("Název nového presetu", text: $newPresetName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            addNewPreset()
                        }
                    
                    Button("Přidat") {
                        addNewPreset()
                    }
                    .disabled(newPresetName.isEmpty)
                    
                    Button("Zrušit") {
                        isAddingNewPreset = false
                        newPresetName = ""
                    }
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var skipPagesSection: some View {
        HStack {
            Text("Čísla stránek".localized + ":")
                .frame(width: 90, alignment: .leading)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("2,4,5,6", text: $skipPages)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 140)
                .focused($isSkipPagesFocused)
        }
    }
    
    private var rotationSection: some View {
        VStack(spacing: 8) {
            Toggle("Po směru hodinových ručiček".localized, isOn: $rotateClockwise)
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .font(.caption)
        }
    }
    
    
    private var openPDFButton: some View {
        Button("Otevřít PDF".localized) {
            isImporterPresented = true
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut("o", modifiers: .command)
    }
    
    
    private func printSection(doc: PDFDocument) -> some View {
        VStack(spacing: 12) {
            Text("Počet stránek".localized + ": \(finalPageCount)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Tisk".localized) {
                printDocument(doc)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .focused($isPrintButtonFocused)
            .keyboardShortcut(.defaultAction)
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }
    }
    
    private var emptyPreviewView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.6))
            Text("Žádný PDF není načten")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Klikněte na 'Otevřít PDF' pro načtení dokumentu")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    var body: some View {
        HStack(spacing: 20) {
            leftPanel
            rightPanel
        }
        .padding(24)
        .background(Color(NSColor.controlBackgroundColor))
                .onAppear {
                    loadSettings()
                    // Regeneruj PDF pouze pokud je již načten
                    if originalDocument != nil {
                        regeneratePDF()
                    }
                    // Automaticky zobraz dialog pro výběr PDF při otevření aplikace
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isImporterPresented = true
                    }
                }
        .onChange(of: horizontalShift) { newValue in
            print("🔄 Horizontální posun změněn na: \(newValue)")
            saveSettings()
            regeneratePDF()
        }
        .onChange(of: verticalShift) { newValue in
            print("🔄 Vertikální posun změněn na: \(newValue)")
            saveSettings()
            regeneratePDF()
        }
                .onChange(of: skipPages) { _ in
                    saveSettings()
                    // Preview se neaktualizuje při změně vynechání stránek - filter se aplikuje pouze při ukládání
                }
        .onChange(of: rotateToPortrait) { _ in
            saveSettings()
            regeneratePDF()
        }
        .onChange(of: disableCutting) { _ in
            saveSettings()
            regeneratePDF()
        }
        .onChange(of: rotateClockwise) { _ in
            saveSettings()
            regeneratePDF()
        }
        .onChange(of: rotationEnabled) { newValue in
            print("🔄 rotationEnabled změněno na: \(newValue)")
            saveSettings()
            regeneratePDF()
        }
        .onChange(of: cuttingEnabled) { _ in
            saveSettings()
            regeneratePDF()
        }
        .onChange(of: skipPagesEnabled) { _ in
            saveSettings()
            regeneratePDF()
        }
        .onChange(of: modificationsEnabled) { _ in
            saveSettings()
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [UTType.pdf],
            onCompletion: { result in
                switch result {
                case .success(let url):
                    print("✅ PDF soubor vybrán: \(url.path)")
                    
                    // Zkusíme získat přístup k souboru
                    guard url.startAccessingSecurityScopedResource() else {
                        print("❌ Nelze získat přístup k souboru")
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    if let originalDocument = PDFDocument(url: url) {
                        print("✅ PDF dokument načten, počet stránek: \(originalDocument.pageCount)")
                        
                        // Uložíme původní dokument pro regeneraci
                        self.originalDocument = originalDocument
                        
                        // Pro preview nepoužíváme vynechání stránek - zobrazíme všechny stránky
                        // Použijeme efektivní hodnoty podle stavu sekcí
                        let effectiveRotateToPortrait = rotationEnabled ? true : false
                        let effectiveDisableCutting = cuttingEnabled ? disableCutting : true
                        let effectiveRotateClockwise = rotationEnabled ? rotateClockwise : true
                        
                        print("🔧 Při načtení PDF - Enable stavy: rotationEnabled=\(rotationEnabled), cuttingEnabled=\(cuttingEnabled), skipPagesEnabled=\(skipPagesEnabled)")
                        print("🎯 Při načtení PDF - Efektivní hodnoty: rotateToPortrait=\(effectiveRotateToPortrait), disableCutting=\(effectiveDisableCutting), rotateClockwise=\(effectiveRotateClockwise)")
                        
                        if let processed = PDFCutter.cutToA6(document: originalDocument, horizontalShift: horizontalShift, verticalShift: verticalShift, skipPages: [], rotateToPortrait: effectiveRotateToPortrait, disableCutting: effectiveDisableCutting, rotateClockwise: effectiveRotateClockwise) {
                            print("✅ PDF úspěšně rozřezán na A6, nový počet stránek: \(processed.pageCount)")
                            cutDocument = processed
                            pageCount = processed.pageCount
                            
                            // Nastavíme fokus na tiskové tlačítko po načtení PDF
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                isSkipPagesFocused = false
                                isHorizontalShiftFocused = false
                                isVerticalShiftFocused = false
                                isPrintButtonFocused = true
                                print("🎯 Fokus nastaven na tiskové tlačítko po načtení PDF")
                            }
                        } else {
                            print("❌ Chyba při řezání PDF na A6")
                        }
                    } else {
                        print("❌ Nelze načíst PDF dokument")
                    }
                case .failure(let error):
                    print("❌ Chyba při výběru souboru: \(error.localizedDescription)")
                }
            }
        )
    }
    
    
    private func printDocument(_ document: PDFDocument) {
        print("🖨️ Otevírám tiskový dialog s aplikováním filtru vynechání stránek...")
        
        // Aplikujeme filtr vynechání stránek pouze pokud je skipPagesEnabled
        let skipPagesList = skipPagesEnabled ? parseSkipPages() : []
        print("📄 Seznam vynechaných stránek: \(skipPagesList) (skipPagesEnabled: \(skipPagesEnabled))")
        
        let filteredDocument = PDFDocument()
        var finalPageIndex = 0
        
        for pageIndex in 0..<document.pageCount {
            finalPageIndex += 1
            
            // Skip pages based on user input
            if skipPagesList.contains(finalPageIndex) {
                print("⏭️ Přeskakuji stránku \(finalPageIndex) při tisku")
                continue
            }
            
            if let page = document.page(at: pageIndex) {
                filteredDocument.insert(page, at: filteredDocument.pageCount)
                print("✅ Přidána stránka \(finalPageIndex) do tisku")
            }
        }
        
        print("📄 Tisk bude obsahovat \(filteredDocument.pageCount) stránek (původně \(document.pageCount))")
        
        // Vytvoříme dočasný soubor pro tisk
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("A6Cutter_Print_\(UUID().uuidString).pdf")
        
        do {
            // Uložíme filtrované PDF do dočasného souboru
            guard let data = filteredDocument.dataRepresentation() else {
                print("❌ Nelze získat data z filtrovaného PDF dokumentu")
                return
            }
            try data.write(to: tempURL)
            
            print("✅ Filtrované PDF uloženo do dočasného souboru pro tisk: \(tempURL.path)")
            
            // Otevřeme tiskový dialog pomocí NSWorkspace s filtrovaným PDF
            NSWorkspace.shared.open(tempURL)
            
            // Počkáme chvilku a pak otevřeme tiskový dialog
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Otevřeme tiskový dialog pomocí AppleScript
                let script = """
                tell application "Preview"
                    activate
                    tell application "System Events"
                        keystroke "p" using command down
                    end tell
                end tell
                """
                
                let appleScript = NSAppleScript(source: script)
                appleScript?.executeAndReturnError(nil)
                
                print("🖨️ Tiskový dialog otevřen s filtrovaným PDF")
            }
            
            // Smažeme dočasný soubor po 60 sekundách
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                try? FileManager.default.removeItem(at: tempURL)
                print("🗑️ Dočasný soubor pro tisk smazán")
            }
            
        } catch {
            print("❌ Chyba při ukládání filtrovaného PDF pro tisk: \(error)")
        }
    }
    
    // Funkce pro ukládání nastavení
    private func saveSettings() {
        UserDefaults.standard.set(horizontalShift, forKey: horizontalShiftKey)
        UserDefaults.standard.set(verticalShift, forKey: verticalShiftKey)
        UserDefaults.standard.set(skipPages, forKey: skipPagesKey)
        UserDefaults.standard.set(rotateToPortrait, forKey: rotateToPortraitKey)
        UserDefaults.standard.set(disableCutting, forKey: disableCuttingKey)
        UserDefaults.standard.set(rotateClockwise, forKey: rotateClockwiseKey)
        UserDefaults.standard.set(rotationEnabled, forKey: rotationEnabledKey)
        UserDefaults.standard.set(cuttingEnabled, forKey: cuttingEnabledKey)
        UserDefaults.standard.set(skipPagesEnabled, forKey: skipPagesEnabledKey)
        UserDefaults.standard.set(modificationsEnabled, forKey: modificationsEnabledKey)
        print("💾 Nastavení uložena")
    }
    
    // Funkce pro načítání nastavení
    private func loadSettings() {
        horizontalShift = UserDefaults.standard.object(forKey: horizontalShiftKey) as? Double ?? 0.0
        verticalShift = UserDefaults.standard.object(forKey: verticalShiftKey) as? Double ?? 0.0
        skipPages = UserDefaults.standard.string(forKey: skipPagesKey) ?? ""
        rotateToPortrait = UserDefaults.standard.object(forKey: rotateToPortraitKey) as? Bool ?? false
        disableCutting = UserDefaults.standard.object(forKey: disableCuttingKey) as? Bool ?? false
        rotateClockwise = UserDefaults.standard.object(forKey: rotateClockwiseKey) as? Bool ?? true
        rotationEnabled = UserDefaults.standard.object(forKey: rotationEnabledKey) as? Bool ?? false
        cuttingEnabled = UserDefaults.standard.object(forKey: cuttingEnabledKey) as? Bool ?? true
        skipPagesEnabled = UserDefaults.standard.object(forKey: skipPagesEnabledKey) as? Bool ?? false
        modificationsEnabled = UserDefaults.standard.object(forKey: modificationsEnabledKey) as? Bool ?? false
        
        // Load presets
        loadPresets()
        print("📂 Nastavení načtena")
    }
    
    private func loadPresets() {
        // Initialize presets if none exist
        if UserDefaults.standard.object(forKey: presetsKey) == nil {
            print("🔧 Inicializuji nové presety...")
            let defaultPreset: [String: Any] = [
                "horizontalShift": 0.0,
                "verticalShift": 0.0,
                "skipPages": "",
                "rotateToPortrait": false,
                "disableCutting": false,
                "rotateClockwise": true,
                "rotationEnabled": false,
                "cuttingEnabled": true,
                "skipPagesEnabled": false
            ]
            
            let fedExPreset: [String: Any] = [
                "horizontalShift": -15.0,
                "verticalShift": 30.0,
                "skipPages": "2,4,5,6",
                "rotateToPortrait": true,
                "disableCutting": false,
                "rotateClockwise": true,
                "rotationEnabled": true,
                "cuttingEnabled": true,
                "skipPagesEnabled": true
            ]
            
            presets = [
                "Default": defaultPreset,
                "FedEx": fedExPreset
            ]
            savePresets()
        } else {
            if let data = UserDefaults.standard.data(forKey: presetsKey),
               let loadedPresets = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
                presets = loadedPresets
                print("📂 Načteny presety: \(Array(presets.keys))")
            }
        }
        
        // Ensure Default and FedEx presets always exist
        if !presets.keys.contains("Default") {
            let defaultPreset: [String: Any] = [
                "horizontalShift": 0.0,
                "verticalShift": 0.0,
                "skipPages": "",
                "rotateToPortrait": false,
                "disableCutting": false,
                "rotateClockwise": true,
                "rotationEnabled": false,
                "cuttingEnabled": true,
                "skipPagesEnabled": false
            ]
            presets["Default"] = defaultPreset
        }
        
        if !presets.keys.contains("FedEx") {
            let fedExPreset: [String: Any] = [
                "horizontalShift": -15.0,
                "verticalShift": 30.0,
                "skipPages": "2,4,5,6",
                "rotateToPortrait": true,
                "disableCutting": false,
                "rotateClockwise": true,
                "rotationEnabled": true,
                "cuttingEnabled": true,
                "skipPagesEnabled": true
            ]
            presets["FedEx"] = fedExPreset
        }
        
        // Load current preset
        currentPreset = UserDefaults.standard.string(forKey: currentPresetKey) ?? "Default"
        
        print("🎯 Aktuální preset: \(currentPreset)")
        print("📋 Dostupné presety: \(Array(presets.keys.sorted()))")
        
        // Apply current preset
        applyPreset(currentPreset)
    }
    
    private func savePresets() {
        if let data = try? JSONSerialization.data(withJSONObject: presets) {
            UserDefaults.standard.set(data, forKey: presetsKey)
        }
        UserDefaults.standard.set(currentPreset, forKey: currentPresetKey)
    }
    
    private func applyPreset(_ presetName: String) {
        guard let preset = presets[presetName] else { return }
        
        horizontalShift = preset["horizontalShift"] as? Double ?? horizontalShift
        verticalShift = preset["verticalShift"] as? Double ?? verticalShift
        skipPages = preset["skipPages"] as? String ?? skipPages
        rotateToPortrait = preset["rotateToPortrait"] as? Bool ?? rotateToPortrait
        disableCutting = preset["disableCutting"] as? Bool ?? disableCutting
        rotateClockwise = preset["rotateClockwise"] as? Bool ?? rotateClockwise
        rotationEnabled = preset["rotationEnabled"] as? Bool ?? rotationEnabled
        cuttingEnabled = preset["cuttingEnabled"] as? Bool ?? cuttingEnabled
        skipPagesEnabled = preset["skipPagesEnabled"] as? Bool ?? skipPagesEnabled
        
        saveSettings()
        
        // If we have a loaded PDF, force complete reload to update preview
        if originalDocument != nil {
            print("🔄 Přenačítám PDF s novým presetem: \(presetName)")
            
            // Force complete PDF reload to trigger preview update
            let tempDocument = originalDocument
            originalDocument = nil
            cutDocument = nil
            pageCount = 0
            
            // Small delay to ensure UI updates, then reload
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.originalDocument = tempDocument
                self.regeneratePDF()
            }
        }
    }
    
    private func addNewPreset() {
        guard !newPresetName.isEmpty && !presets.keys.contains(newPresetName) else { return }
        
        // Create new preset with current settings
        let newPreset: [String: Any] = [
            "horizontalShift": horizontalShift,
            "verticalShift": verticalShift,
            "skipPages": skipPages,
            "rotateToPortrait": rotateToPortrait,
            "disableCutting": disableCutting,
            "rotateClockwise": rotateClockwise,
            "rotationEnabled": rotationEnabled,
            "cuttingEnabled": cuttingEnabled,
            "skipPagesEnabled": skipPagesEnabled
        ]
        
        presets[newPresetName] = newPreset
        currentPreset = newPresetName
        savePresets()
        
        isAddingNewPreset = false
        newPresetName = ""
    }
    
    private func deletePreset(_ presetName: String) {
        // Don't allow deletion of Default and FedEx presets
        guard presetName != "Default" && presetName != "FedEx" else { return }
        
        presets.removeValue(forKey: presetName)
        
        // If we deleted the current preset, switch to Default
        if currentPreset == presetName {
            currentPreset = "Default"
            applyPreset("Default")
        }
        
        savePresets()
    }
    
    // MARK: - Version and Build Info
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "Deve"
    }
    
    private var buildNumber: String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return build
        }
        return "dev"
    }
    
    private var gitHash: String {
        // V produkční verzi by toto bylo nastaveno během buildu
        // Pro dev verzi vrátíme "dev"
        if let hash = Bundle.main.infoDictionary?["GitHash"] as? String {
            return String(hash.prefix(7))
        }
        return "dev"
    }
    
    private var releaseNotes: String {
        """
        ### What's New in \(appVersion)
        
        - PDF cutting into A6-sized tiles
        - Customizable settings with live preview
        - Page rotation and skipping
        - Preset management (Default, FedEx)
        - Direct printing integration
        - Keyboard shortcuts (CMD+O, CMD+SHIFT+P)
        - Parametric cut shifts
        - Section enable/disable toggles
        """
    }
    
    private func parseSkipPages() -> [Int] {
        return skipPages.components(separatedBy: ",").compactMap { 
            Int($0.trimmingCharacters(in: .whitespaces)) 
        }
    }
    
    // Funkce pro regeneraci PDF při změně nastavení (bez vynechání stránek pro preview)
    private func regeneratePDF() {
        guard let original = originalDocument else { 
            print("⚠️ Regenerace PDF přeskočena - žádný původní dokument")
            return 
        }
        
        print("🔄 Regeneruji PDF s novými nastaveními (bez vynechání stránek pro preview)...")
        print("📊 Aktuální nastavení: hShift=\(horizontalShift), vShift=\(verticalShift), skip=\(skipPages), rotate=\(rotateToPortrait), disable=\(disableCutting), clockwise=\(rotateClockwise)")
        print("🔧 Enable stavy: rotationEnabled=\(rotationEnabled), cuttingEnabled=\(cuttingEnabled), skipPagesEnabled=\(skipPagesEnabled)")
        
        // Pro preview nepoužíváme vynechání stránek - zobrazíme všechny stránky
        // Použijeme enable/disable stavy místo původních toggleů
        let effectiveRotateToPortrait = rotationEnabled ? true : false  // Pokud je rotation enabled, vždy otáčej landscape na portrait
        let effectiveDisableCutting = cuttingEnabled ? disableCutting : true  // Pokud je cutting disabled, pak je řezání vypnuto
        let effectiveRotateClockwise = rotationEnabled ? rotateClockwise : true
        
        print("🎯 Efektivní hodnoty: rotateToPortrait=\(effectiveRotateToPortrait), disableCutting=\(effectiveDisableCutting), rotateClockwise=\(effectiveRotateClockwise)")
        
        if let processed = PDFCutter.cutToA6(document: original, horizontalShift: horizontalShift, verticalShift: verticalShift, skipPages: [], rotateToPortrait: effectiveRotateToPortrait, disableCutting: effectiveDisableCutting, rotateClockwise: effectiveRotateClockwise) {
            print("✅ PDF úspěšně regenerován s novými nastaveními (bez vynechání), nový počet stránek: \(processed.pageCount)")
            
            // Aktualizuj UI na hlavním vlákně
            DispatchQueue.main.async {
                print("🔄 Před aktualizací - cutDocument: \(self.cutDocument?.pageCount ?? 0) stránek")
                self.cutDocument = processed
                self.pageCount = processed.pageCount
                print("🔄 Po aktualizaci - cutDocument: \(self.cutDocument?.pageCount ?? 0) stránek")
                print("🔄 UI aktualizováno - cutDocument a pageCount nastaveny")
                
                // Nastavíme fokus na tiskové tlačítko po regeneraci PDF
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isSkipPagesFocused = false
                    self.isHorizontalShiftFocused = false
                    self.isVerticalShiftFocused = false
                    self.isPrintButtonFocused = true
                    print("🎯 Fokus nastaven na tiskové tlačítko po regeneraci PDF")
                }
            }
        } else {
            print("❌ Chyba při regeneraci PDF")
        }
    }
}

struct PDFDocumentWrapper: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    
    let document: PDFDocument
    let skipPages: [Int]
    
    init(document: PDFDocument, skipPages: [Int] = []) {
        self.document = document
        self.skipPages = skipPages
    }
    
    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadCorruptFile)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Aplikuj filter vynechání stránek při ukládání
        let filteredDocument = PDFDocument()
        var finalPageIndex = 0
        
        for pageIndex in 0..<document.pageCount {
            finalPageIndex += 1
            
            // Skip pages based on user input (čísla stránek v konečném výsledku)
            if skipPages.contains(finalPageIndex) {
                print("⏭️ Přeskakuji stránku \(finalPageIndex) při ukládání")
                continue
            }
            
            if let page = document.page(at: pageIndex) {
                filteredDocument.insert(page, at: filteredDocument.pageCount)
                print("✅ Přidána stránka \(finalPageIndex) do uloženého PDF")
            }
        }
        
        guard let data = filteredDocument.dataRepresentation() else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

internal struct PrintHelper {
    
    static func printDocument(_ document: PDFDocument) {
        print("🖨️ Spouštím tisk...")
        
        #if os(iOS)
        guard let data = document.dataRepresentation() else {
            print("❌ Nelze získat data z PDF")
            return
        }
        
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "PDF Print"
        printController.printInfo = printInfo
        printController.printingItem = data
        printController.present(animated: true, completionHandler: nil)
        #elseif os(macOS)
        // Pro macOS uložíme PDF do dočasného souboru a otevřeme v Preview
        guard let pdfData = document.dataRepresentation() else {
            print("❌ Nelze získat PDF data")
            return
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("A6Cutter_\(UUID().uuidString).pdf")
        
        do {
            try pdfData.write(to: tempURL)
            print("✅ PDF uloženo do: \(tempURL.path)")
            
            // Otevřeme PDF v Preview aplikaci
            NSWorkspace.shared.open(tempURL)
            
            // Počkáme chvilku a pak smažeme dočasný soubor
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                try? FileManager.default.removeItem(at: tempURL)
            }
            
        } catch {
            print("❌ Chyba při ukládání PDF: \(error.localizedDescription)")
        }
        #endif
    }
}

// Thumbnaily PDF komponenta
struct PDFThumbnailsView: View {
    let document: PDFDocument
    let skipPages: [Int]
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height
            
            VStack(spacing: 8) {
                Text("Náhled všech stránek".localized + " (\(document.pageCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .onAppear {
                        print("🔄 PDFThumbnailsView se aktualizuje - počet stránek: \(document.pageCount)")
                    }
                
                // Dynamicky vypočítáme počet sloupců a velikost thumbnailů - ZVĚTŠENÉ
                let columns = max(1, Int(availableWidth / 200)) // 200px per thumbnail including spacing (zvětšeno z 140px)
                let rows = max(1, Int(ceil(Double(document.pageCount) / Double(columns))))
                let thumbnailWidth = (availableWidth - CGFloat(columns - 1) * 12 - 24) / CGFloat(columns) // 12px spacing, 24px padding (zvětšeno)
                let thumbnailHeight = min(thumbnailWidth * 1.4, (availableHeight - 50) / CGFloat(rows)) // 1.4 aspect ratio, 50px for text (zvětšeno)
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns), spacing: 12) {
                        ForEach(0..<document.pageCount, id: \.self) { pageIndex in
                            let pageNumber = pageIndex + 1
                            let isSkipped = skipPages.contains(pageNumber)
                            
                            VStack(spacing: 4) {
                                if let page = document.page(at: pageIndex) {
                                    PDFThumbnailView(page: page)
                                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                                        .background(Color.white)
                                        .cornerRadius(6)
                                        .shadow(radius: 2)
                                        .clipped()
                                        .overlay(
                                            // Ztmavení pro vynechané stránky
                                            isSkipped ? 
                                            Rectangle()
                                                .fill(Color.black.opacity(0.6))
                                                .cornerRadius(6)
                                            : nil
                                        )
                                        .overlay(
                                            // Text "VYNECHÁNO" pro vynechané stránky
                                            isSkipped ?
                                            Text("VYNECHÁNO".localized)
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(4)
                                                .background(Color.red.opacity(0.8))
                                                .cornerRadius(4)
                                            : nil
                                        )
                                } else {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                                        .cornerRadius(6)
                                        .overlay(
                                            // Ztmavení pro vynechané stránky
                                            isSkipped ? 
                                            Rectangle()
                                                .fill(Color.black.opacity(0.6))
                                                .cornerRadius(6)
                                            : nil
                                        )
                                }
                                
                                Text("Str.".localized + " \(pageNumber)")
                                    .font(.caption2)
                                    .foregroundColor(isSkipped ? .red : .secondary)
                                    .fontWeight(isSkipped ? .bold : .regular)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .onDisappear {
            // Vyčisti resources při zmizení view
            print("🧹 PDFThumbnailsView se ukončuje")
        }
    }
}

// PDF thumbnail náhled
struct PDFThumbnailView: View {
    let page: PDFPage
    
    var body: some View {
        PDFThumbnailRepresentable(page: page)
    }
}

// PDF stránka náhled
struct PDFPageView: View {
    let page: PDFPage
    
    var body: some View {
        PDFPageRepresentable(page: page)
    }
}

// PDF thumbnail reprezentace pro macOS
struct PDFThumbnailRepresentable: NSViewRepresentable {
    let page: PDFPage
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        
        // Vytvoř nový dokument s jednou stránkou
        let document = PDFDocument()
        document.insert(page, at: 0)
        pdfView.document = document
        
        // Nastav vlastnosti pro thumbnail
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.scaleFactor = 0.3 // Menší velikost pro thumbnaily
        
        // Zakázat interakce pro thumbnaily
        pdfView.allowsDragging = false
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        // Aktualizace není potřeba, stránka se nemění
        // Ale ujistíme se, že je PDFView stále platný
        if nsView.document == nil {
            // Pokud se dokument ztratil, znovu ho vytvoř
            let document = PDFDocument()
            document.insert(page, at: 0)
            nsView.document = document
        }
    }
}

// PDF stránka reprezentace pro macOS
struct PDFPageRepresentable: NSViewRepresentable {
    let page: PDFPage
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument()
        pdfView.document?.insert(page, at: 0)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        // Aktualizace není potřeba, stránka se nemění
    }
}
