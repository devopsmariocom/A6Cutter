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
    @State private var isPreviewPresented = false
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
    
    private var leftPanel: some View {
        VStack(spacing: 16) {
            cutShiftsSection
            skipPagesSection
            rotationSection
            cuttingSection
            
            Spacer()
            
            openPDFButton
            if let doc = cutDocument {
                savePDFSection(doc: doc)
            }
        }
        .frame(width: 300)
    }
    
    private var rightPanel: some View {
        VStack(spacing: 16) {
            if let doc = cutDocument {
                PDFThumbnailsView(document: doc, skipPages: parseSkipPages())
                    .id("pdf-thumbnails-\(doc.pageCount)-\(horizontalShift)-\(verticalShift)")
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
    
    private var cutShiftsSection: some View {
        VStack(spacing: 12) {
            Text("Posunutí řezů")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Horizontální:")
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
                    Text("Vertikální:")
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
        .frame(width: 300, height: 120) // Pevná šířka a výška
        .padding(16)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(12)
    }
    
    private var skipPagesSection: some View {
        VStack(spacing: 12) {
            Text("Vynechání stránek")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Text("Vynechat:")
                    .frame(width: 90, alignment: .leading)
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("2,4,5,6", text: $skipPages)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 140)
            }
        }
        .frame(width: 300, height: 120) // Pevná šířka a výška
        .padding(16)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(12)
    }
    
    private var rotationSection: some View {
        VStack(spacing: 12) {
            Text("Otočení")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                Toggle("Landscape → Portrait", isOn: $rotateToPortrait)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .font(.caption)
                
                Toggle("Po směru hodinových ručiček", isOn: $rotateClockwise)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .font(.caption)
            }
        }
        .frame(width: 300, height: 120) // Pevná šířka a výška
        .padding(16)
        .background(Color.green.opacity(0.08))
        .cornerRadius(12)
    }
    
    private var cuttingSection: some View {
        VStack(spacing: 12) {
            Text("Řezání")
                .font(.headline)
                .foregroundColor(.primary)
            
            Toggle("Vypnout řezání", isOn: $disableCutting)
                .toggleStyle(SwitchToggleStyle(tint: .orange))
                .font(.caption)
        }
        .frame(width: 300, height: 120) // Pevná šířka a výška
        .padding(16)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
    }
    
    private var openPDFButton: some View {
        Button("Otevřít PDF") {
            isImporterPresented = true
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
    
    private func savePDFSection(doc: PDFDocument) -> some View {
        VStack(spacing: 8) {
            Text("Počet stránek: \(pageCount)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Button("Uložit PDF") {
                    savePDF(doc)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                
                Button("Náhled v Preview") {
                    previewInPreview(doc)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
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
                        if let processed = PDFCutter.cutToA6(document: originalDocument, horizontalShift: horizontalShift, verticalShift: verticalShift, skipPages: [], rotateToPortrait: rotateToPortrait, disableCutting: disableCutting, rotateClockwise: rotateClockwise) {
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
            document: cutDocument != nil ? PDFDocumentWrapper(document: cutDocument!, skipPages: skipPages.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }) : nil,
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
    
    private func previewInPreview(_ document: PDFDocument) {
        print("👁️ Otevírám PDF v Preview s aplikováním filtru vynechání stránek...")
        
        // Aplikujeme stejný filtr jako při ukládání
        let skipPagesList = parseSkipPages()
        let filteredDocument = PDFDocument()
        var finalPageIndex = 0
        
        for pageIndex in 0..<document.pageCount {
            finalPageIndex += 1
            
            // Skip pages based on user input (čísla stránek v konečném výsledku)
            if skipPagesList.contains(finalPageIndex) {
                print("⏭️ Přeskakuji stránku \(finalPageIndex) v preview")
                continue
            }
            
            if let page = document.page(at: pageIndex) {
                filteredDocument.insert(page, at: filteredDocument.pageCount)
                print("✅ Přidána stránka \(finalPageIndex) do preview")
            }
        }
        
        print("📄 Preview bude obsahovat \(filteredDocument.pageCount) stránek (původně \(document.pageCount))")
        
        // Vytvoříme dočasný soubor
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("A6Cutter_Preview_\(UUID().uuidString).pdf")
        
        do {
            // Uložíme filtrované PDF do dočasného souboru
            guard let data = filteredDocument.dataRepresentation() else {
                print("❌ Nelze získat data z filtrovaného PDF dokumentu")
                return
            }
            try data.write(to: tempURL)
            
            print("✅ Filtrované PDF uloženo do dočasného souboru: \(tempURL.path)")
            
            // Otevřeme v Preview
            NSWorkspace.shared.open(tempURL)
            
            // Smažeme dočasný soubor po 30 sekundách
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                try? FileManager.default.removeItem(at: tempURL)
                print("🗑️ Dočasný soubor smazán: \(tempURL.path)")
            }
            
        } catch {
            print("❌ Chyba při ukládání filtrovaného PDF pro preview: \(error)")
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
        print("💾 Nastavení uložena")
    }
    
    // Funkce pro načítání nastavení
    private func loadSettings() {
        horizontalShift = UserDefaults.standard.object(forKey: horizontalShiftKey) as? Double ?? -15.0
        verticalShift = UserDefaults.standard.object(forKey: verticalShiftKey) as? Double ?? 30.0
        skipPages = UserDefaults.standard.string(forKey: skipPagesKey) ?? "2,4,5,6"
        rotateToPortrait = UserDefaults.standard.object(forKey: rotateToPortraitKey) as? Bool ?? true
        disableCutting = UserDefaults.standard.object(forKey: disableCuttingKey) as? Bool ?? false
        rotateClockwise = UserDefaults.standard.object(forKey: rotateClockwiseKey) as? Bool ?? true
        print("📂 Nastavení načtena")
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
        
        // Pro preview nepoužíváme vynechání stránek - zobrazíme všechny stránky
        if let processed = PDFCutter.cutToA6(document: original, horizontalShift: horizontalShift, verticalShift: verticalShift, skipPages: [], rotateToPortrait: rotateToPortrait, disableCutting: disableCutting, rotateClockwise: rotateClockwise) {
            print("✅ PDF úspěšně regenerován s novými nastaveními (bez vynechání), nový počet stránek: \(processed.pageCount)")
            
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
                Text("Náhled všech stránek (\(document.pageCount))")
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
                                            Text("VYNECHÁNO")
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
                                
                                Text("Str. \(pageNumber)")
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
