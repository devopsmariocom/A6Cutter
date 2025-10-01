import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isImporterPresented = false
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
                Button("Tisk") {
                    if let doc = cutDocument {
                        PrintHelper.print(document: doc)
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
                    if let originalDocument = PDFDocument(url: url) {
                        let processed = PDFCutter.cutToA6(document: originalDocument)
                        cutDocument = processed
                        pageCount = processed.pageCount
                    }
                case .failure:
                    break
                }
            }
        )
    }
}

internal struct PrintHelper {
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif
    
    static func print(document: PDFDocument) {
        guard let data = document.dataRepresentation() else {
            return
        }
        
        #if os(iOS)
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "PDF Print"
        printController.printInfo = printInfo
        printController.printingItem = data
        printController.present(animated: true, completionHandler: nil)
        #elseif os(macOS)
        let pdfView = PDFView(frame: .zero)
        pdfView.document = document
        let printOperation = NSPrintOperation(view: pdfView)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.run()
        #endif
    }
}

// Dummy PDFCutter implementation for compilation
struct PDFCutter {
    static func cutToA6(document: PDFDocument) -> PDFDocument {
        return document
    }
}
