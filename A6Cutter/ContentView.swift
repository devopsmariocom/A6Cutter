import SwiftUI
import PDFKit
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ContentView: View {
    @State private var isImporterPresented = false
    @State private var isSaverPresented = false
    @State private var cutDocument: PDFDocument?
    @State private var originalDocument: PDFDocument?
    @State private var pageCount: Int = 0
    
    // UserDefaults klíče pro ukládání nastavení
    private let horizontalShiftKey = "horizontalShift"
    private let verticalShiftKey = "verticalShift"
    private let skipPagesKey = "skipPages"
    private let rotateToPortraitKey = "rotateToPortrait"
    private let disableCuttingKey = "disableCutting"
    private let rotateClockwiseKey = "rotateClockwise"
    
    // Parametry pro posunutí řezů
    @State private var horizontalShift: Double = 60.0
    @State private var verticalShift: Double = 0.0
    
    // Parametry pro vynechání stránek
    @State private var skipPages: String = "2,4,5,6"
    
    // Parametr pro otočení z landscape na portrait
    @State private var rotateToPortrait: Bool = true
    
    // Parametr pro vypnutí řezání
    @State private var disableCutting: Bool = false
    
    // Parametr pro směr otáčení
    @State private var rotateClockwise: Bool = true
    
    var body: some View {
        VStack(spacing: 16) {
            Text("A6Cutter")
                .font(.largeTitle)
                .bold()
            
            // Nastavení posunutí řezů
            VStack(spacing: 12) {
                Text("Nastavení posunutí řezů")
                    .font(.headline)
                
                HStack {
                    Text("Horizontální posun:")
                        .frame(width: 120, alignment: .leading)
                    Slider(value: $horizontalShift, in: -100...100, step: 5)
                    Text("\(Int(horizontalShift))")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Vertikální posun:")
                        .frame(width: 120, alignment: .leading)
                    Slider(value: $verticalShift, in: -100...100, step: 5)
                    Text("\(Int(verticalShift))")
                        .frame(width: 40)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Nastavení vynechání stránek
            VStack(spacing: 12) {
                Text("Nastavení vynechání stránek")
                    .font(.headline)
                
                HStack {
                    Text("Vynechat stránky:")
                        .frame(width: 120, alignment: .leading)
                    TextField("2,4,5,6", text: $skipPages)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 150)
                }
                
                Text("Zadejte čísla stránek oddělená čárkou (např. 2,4,5,6)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            
            // Nastavení otočení
            VStack(spacing: 12) {
                Text("Nastavení otočení")
                    .font(.headline)
                
                HStack {
                    Toggle("Otočit z landscape na portrait", isOn: $rotateToPortrait)
                        .toggleStyle(SwitchToggleStyle())
                }
                
                HStack {
                    Toggle("Otočit po směru hodinových ručiček", isOn: $rotateClockwise)
                        .toggleStyle(SwitchToggleStyle())
                }
                
                Text("Automaticky otočí landscape PDF na portrait před řezáním")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
            
            // Nastavení vypnutí řezání
            VStack(spacing: 12) {
                Text("Nastavení řezání")
                    .font(.headline)
                
                HStack {
                    Toggle("Vypnout řezání (pouze otočení)", isOn: $disableCutting)
                        .toggleStyle(SwitchToggleStyle())
                }
                
                Text("Pouze otočí PDF bez řezání na A6 dlaždice")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            
            Button("Otevřít PDF") {
                isImporterPresented = true
            }
            if let doc = cutDocument {
                Text("Počet A6 stránek: \(pageCount)")
            }
            HStack {
                Button("Uložit PDF") {
                    if let doc = cutDocument {
                        savePDF(doc)
                    }
                }
                .disabled(cutDocument == nil)
            }
        }
        .padding()
        .onAppear {
            loadSettings()
        }
        .onChange(of: horizontalShift) { _ in
            saveSettings()
            regeneratePDF()
        }
        .onChange(of: verticalShift) { _ in
            saveSettings()
            regeneratePDF()
        }
        .onChange(of: skipPages) { _ in
            saveSettings()
            regeneratePDF()
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
                        
                        // Parse skip pages from string
                        let skipPagesList = skipPages.components(separatedBy: ",")
                            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                        
                        if let processed = PDFCutter.cutToA6(document: originalDocument, horizontalShift: horizontalShift, verticalShift: verticalShift, skipPages: skipPagesList, rotateToPortrait: rotateToPortrait, disableCutting: disableCutting, rotateClockwise: rotateClockwise) {
                            print("✅ PDF úspěšně rozřezán na A6, nový počet stránek: \(processed.pageCount)")
                            cutDocument = processed
                            pageCount = processed.pageCount
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
        .fileExporter(
            isPresented: $isSaverPresented,
            document: cutDocument != nil ? PDFDocumentWrapper(document: cutDocument!) : nil,
            contentType: .pdf,
            defaultFilename: "A6Cutter_Output"
        ) { result in
            switch result {
            case .success(let url):
                print("✅ PDF uloženo do: \(url.path)")
            case .failure(let error):
                print("❌ Chyba při ukládání: \(error.localizedDescription)")
            }
        }
    }
    
    private func savePDF(_ document: PDFDocument) {
        isSaverPresented = true
    }
    
    // Funkce pro ukládání nastavení
    private func saveSettings() {
        UserDefaults.standard.set(horizontalShift, forKey: horizontalShiftKey)
        UserDefaults.standard.set(verticalShift, forKey: verticalShiftKey)
        UserDefaults.standard.set(skipPages, forKey: skipPagesKey)
        UserDefaults.standard.set(rotateToPortrait, forKey: rotateToPortraitKey)
        UserDefaults.standard.set(disableCutting, forKey: disableCuttingKey)
        UserDefaults.standard.set(rotateClockwise, forKey: rotateClockwiseKey)
        print("💾 Nastavení uložena")
    }
    
    // Funkce pro načítání nastavení
    private func loadSettings() {
        horizontalShift = UserDefaults.standard.object(forKey: horizontalShiftKey) as? Double ?? 60.0
        verticalShift = UserDefaults.standard.object(forKey: verticalShiftKey) as? Double ?? 0.0
        skipPages = UserDefaults.standard.string(forKey: skipPagesKey) ?? "2,4,5,6"
        rotateToPortrait = UserDefaults.standard.object(forKey: rotateToPortraitKey) as? Bool ?? true
        disableCutting = UserDefaults.standard.object(forKey: disableCuttingKey) as? Bool ?? false
        rotateClockwise = UserDefaults.standard.object(forKey: rotateClockwiseKey) as? Bool ?? true
        print("📂 Nastavení načtena")
    }
    
    // Funkce pro regeneraci PDF při změně nastavení
    private func regeneratePDF() {
        guard let original = originalDocument else { return }
        
        print("🔄 Regeneruji PDF s novými nastaveními...")
        
        // Parse skip pages from string
        let skipPagesList = skipPages.components(separatedBy: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        
        if let processed = PDFCutter.cutToA6(document: original, horizontalShift: horizontalShift, verticalShift: verticalShift, skipPages: skipPagesList, rotateToPortrait: rotateToPortrait, disableCutting: disableCutting, rotateClockwise: rotateClockwise) {
            print("✅ PDF úspěšně regenerován s novými nastaveními, nový počet stránek: \(processed.pageCount)")
            cutDocument = processed
            pageCount = processed.pageCount
        } else {
            print("❌ Chyba při regeneraci PDF")
        }
    }
}

struct PDFDocumentWrapper: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    
    let document: PDFDocument
    
    init(document: PDFDocument) {
        self.document = document
    }
    
    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadCorruptFile)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = document.dataRepresentation() else {
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
