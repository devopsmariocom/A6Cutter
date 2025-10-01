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
    @State private var pageCount: Int = 0
    
    var body: some View {
        VStack(spacing: 16) {
            Text("A6Cutter")
                .font(.largeTitle)
                .bold()
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
                        
                        if let processed = PDFCutter.cutToA6(document: originalDocument) {
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
