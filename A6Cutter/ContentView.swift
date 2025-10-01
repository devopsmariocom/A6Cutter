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
        HStack(spacing: 16) {
            // Levá strana - uživatelské vstupy
            VStack(spacing: 12) {
                Text("A6Cutter")
                    .font(.largeTitle)
                    .bold()
                
                // Nastavení posunutí řezů
                VStack(spacing: 8) {
                    Text("Posunutí řezů")
                        .font(.headline)
                    
                    HStack {
                        Text("Horizontální:")
                            .frame(width: 80, alignment: .leading)
                            .font(.caption)
                        Slider(value: $horizontalShift, in: -100...100, step: 5)
                        Text("\(Int(horizontalShift))")
                            .frame(width: 30)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("Vertikální:")
                            .frame(width: 80, alignment: .leading)
                            .font(.caption)
                        Slider(value: $verticalShift, in: -100...100, step: 5)
                        Text("\(Int(verticalShift))")
                            .frame(width: 30)
                            .font(.caption)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                
                // Nastavení vynechání stránek
                VStack(spacing: 8) {
                    Text("Vynechání stránek")
                        .font(.headline)
                    
                    HStack {
                        Text("Vynechat:")
                            .frame(width: 80, alignment: .leading)
                            .font(.caption)
                        TextField("2,4,5,6", text: $skipPages)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 120)
                    }
                }
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
                
                // Nastavení otočení
                VStack(spacing: 8) {
                    Text("Otočení")
                        .font(.headline)
                    
                    Toggle("Landscape → Portrait", isOn: $rotateToPortrait)
                        .toggleStyle(SwitchToggleStyle())
                        .font(.caption)
                    
                    Toggle("Po směru hodinových ručiček", isOn: $rotateClockwise)
                        .toggleStyle(SwitchToggleStyle())
                        .font(.caption)
                }
                .padding(8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
                
                // Nastavení řezání
                VStack(spacing: 8) {
                    Text("Řezání")
                        .font(.headline)
                    
                    Toggle("Vypnout řezání", isOn: $disableCutting)
                        .toggleStyle(SwitchToggleStyle())
                        .font(.caption)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
                
                Button("Otevřít PDF") {
                    isImporterPresented = true
                }
                .buttonStyle(.borderedProminent)
                
                if let doc = cutDocument {
                    Text("Počet stránek: \(pageCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Uložit PDF") {
                        savePDF(doc)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(width: 280)
            
            // Pravá strana - preview
            VStack(spacing: 12) {
                Text("Náhled výsledku")
                    .font(.headline)
                
                if let doc = cutDocument {
                    PDFThumbnailsView(document: doc)
                        .id("pdf-thumbnails-\(doc.pageCount)-\(horizontalShift)-\(verticalShift)")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    VStack {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Žádný PDF není načten")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .onAppear {
            loadSettings()
            // Regeneruj PDF pouze pokud je již načten
            if originalDocument != nil {
                regeneratePDF()
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
        guard let original = originalDocument else { 
            print("⚠️ Regenerace PDF přeskočena - žádný původní dokument")
            return 
        }
        
        print("🔄 Regeneruji PDF s novými nastaveními...")
        print("📊 Aktuální nastavení: hShift=\(horizontalShift), vShift=\(verticalShift), skip=\(skipPages), rotate=\(rotateToPortrait), disable=\(disableCutting), clockwise=\(rotateClockwise)")
        
        // Parse skip pages from string
        let skipPagesList = skipPages.components(separatedBy: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        
        if let processed = PDFCutter.cutToA6(document: original, horizontalShift: horizontalShift, verticalShift: verticalShift, skipPages: skipPagesList, rotateToPortrait: rotateToPortrait, disableCutting: disableCutting, rotateClockwise: rotateClockwise) {
            print("✅ PDF úspěšně regenerován s novými nastaveními, nový počet stránek: \(processed.pageCount)")
            
            // Aktualizuj UI na hlavním vlákně
            DispatchQueue.main.async {
                print("🔄 Před aktualizací - cutDocument: \(self.cutDocument?.pageCount ?? 0) stránek")
                self.cutDocument = processed
                self.pageCount = processed.pageCount
                print("🔄 Po aktualizaci - cutDocument: \(self.cutDocument?.pageCount ?? 0) stránek")
                print("🔄 UI aktualizováno - cutDocument a pageCount nastaveny")
            }
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

// Thumbnaily PDF komponenta
struct PDFThumbnailsView: View {
    let document: PDFDocument
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Náhled všech stránek (\(document.pageCount))")
                .font(.caption)
                .foregroundColor(.secondary)
                .onAppear {
                    print("🔄 PDFThumbnailsView se aktualizuje - počet stránek: \(document.pageCount)")
                }
            
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 8) {
                    ForEach(0..<document.pageCount, id: \.self) { pageIndex in
                        VStack(spacing: 4) {
                            if let page = document.page(at: pageIndex) {
                                PDFThumbnailView(page: page)
                                    .frame(width: 120, height: 160)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .shadow(radius: 2)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 120, height: 160)
                                    .cornerRadius(6)
                            }
                            
                            Text("Str. \(pageIndex + 1)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
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
        pdfView.document = PDFDocument()
        pdfView.document?.insert(page, at: 0)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.scaleFactor = 0.3 // Menší velikost pro thumbnaily
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        // Aktualizace není potřeba, stránka se nemění
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
