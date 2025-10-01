import Foundation
import PDFKit
import CoreGraphics

enum PDFCutter {
    /// Cut a PDF document into A6 tiles preserving orientation.
    static func cutToA6(document: PDFDocument, horizontalShift: Double = 0.0, verticalShift: Double = 0.0, skipPages: [Int] = [], rotateToPortrait: Bool = false, disableCutting: Bool = false, rotateClockwise: Bool = true) -> PDFDocument? {
        print("🔧 Začínám zpracování PDF...")
        let outputDocument = PDFDocument()
        
        // KROK 1: Otočení landscape na portrait (pokud je požadováno)
        if rotateToPortrait {
            print("🔄 KROK 1: Otočuji landscape stránky na portrait...")
        }
        
        // KROK 2: Řezání stránek (pokud není vypnuto)
        if disableCutting {
            print("✂️ KROK 2: Řezání je vypnuto - pouze otočení")
        } else {
            print("✂️ KROK 2: Řezání stránek na A6 dlaždice...")
        }
        
        // KROK 3: Vynechání stránek podle filtru
        print("⏭️ KROK 3: Vynechání stránek podle filtru: \(skipPages)")
        
        // A6 size in mm
        let a6WidthMM: CGFloat = 105
        let a6HeightMM: CGFloat = 148
        
        // Convert mm to points (72 dpi)
        func mmToPoints(_ mm: CGFloat) -> CGFloat {
            return mm / 25.4 * 72
        }
        
        let pageCount = document.pageCount
        print("📄 Počet stránek v původním PDF: \(pageCount)")
        
        for pageIndex in 0..<pageCount {
            guard let page = document.page(at: pageIndex) else { 
                print("⚠️ Nelze načíst stránku \(pageIndex)")
                continue 
            }
            var pageRect = page.bounds(for: .mediaBox)
            print("📐 Stránka \(pageIndex): \(pageRect.width) x \(pageRect.height) bodů")
            
            // KROK 1: Rotate landscape pages to portrait if requested
            if rotateToPortrait && pageRect.width > pageRect.height {
                let rotationDirection = rotateClockwise ? 90 : -90
                let directionText = rotateClockwise ? "po směru hodinových ručiček" : "proti směru hodinových ručiček"
                print("🔄 KROK 1: Otočuji stránku \(pageIndex + 1) z landscape na portrait (\(directionText))")
                // Rotate the page by 90 degrees in the specified direction
                page.rotation = (page.rotation + rotationDirection) % 360
                // Update pageRect after rotation
                pageRect = page.bounds(for: .mediaBox)
                print("📐 Po otočení: \(pageRect.width) x \(pageRect.height) bodů")
            }
            
            // KROK 2: Pokud je řezání vypnuto, pouze přidáme stránku
            if disableCutting {
                print("✂️ KROK 2: Přidávám stránku \(pageIndex + 1) bez řezání")
                outputDocument.insert(page, at: outputDocument.pageCount)
                continue
            }
            
            // Determine A6 tile size in points
            // For A4 landscape documents, we want landscape A6 tiles (148x105mm)
            // For A4 portrait documents, we want portrait A6 tiles (105x148mm)
            let pageIsLandscape = pageRect.width > pageRect.height
            
            // A6 landscape dimensions (148x105mm)
            let a6LandscapeWidthPts = mmToPoints(148)   // A6 landscape width
            let a6LandscapeHeightPts = mmToPoints(105)  // A6 landscape height
            
            // A6 portrait dimensions (105x148mm) 
            let a6PortraitWidthPts = mmToPoints(105)    // A6 portrait width
            let a6PortraitHeightPts = mmToPoints(148)   // A6 portrait height
            
            // Use landscape A6 for landscape pages, portrait A6 for portrait pages
            let a6WidthPts = pageIsLandscape ? a6LandscapeWidthPts : a6PortraitWidthPts
            let a6HeightPts = pageIsLandscape ? a6LandscapeHeightPts : a6PortraitHeightPts
            
            // Calculate how many A6 tiles fit horizontally and vertically
            let cols = max(1, Int(ceil(pageRect.width / a6WidthPts)))
            let rows = max(1, Int(ceil(pageRect.height / a6HeightPts)))
            
            // Use actual A6 dimensions for tiles
            let tileWidth = a6WidthPts
            let tileHeight = a6HeightPts
            
            let orientation = pageIsLandscape ? "landscape" : "portrait"
            print("🔲 A6 \(orientation) rozměry: \(a6WidthPts) x \(a6HeightPts) bodů")
            print("📊 Rozdělení: \(cols) x \(rows) dlaždic, velikost dlaždice: \(tileWidth) x \(tileHeight)")
            
            // Parametric shifts for cut lines
            print("📏 Horizontální posun: \(horizontalShift) bodů")
            print("📏 Vertikální posun: \(verticalShift) bodů")
            print("⏭️ Vynechávám stránky: \(skipPages)")
            
            var tileIndex = 0
            for row in 0..<rows {
                for col in 0..<cols {
                    tileIndex += 1
                    
                    // Poznámka: Vynechání stránek se provádí až po řezání v KROKU 3
                    
                    let cropRect = CGRect(
                        x: pageRect.minX + CGFloat(col) * a6WidthPts + CGFloat(horizontalShift),
                        y: pageRect.minY + CGFloat(row) * a6HeightPts + CGFloat(verticalShift),
                        width: a6WidthPts,
                        height: a6HeightPts
                    )
                    
                    guard let tilePDFData = renderTile(from: page, cropRect: cropRect, tileSize: CGSize(width: tileWidth, height: tileHeight)),
                          let tileDocument = PDFDocument(data: tilePDFData),
                          let tilePage = tileDocument.page(at: 0) else {
                        continue
                    }
                    
                    outputDocument.insert(tilePage, at: outputDocument.pageCount)
                    print("✅ Přidána stránka \(tileIndex)")
                }
            }
        }
        
        // KROK 3: Aplikujeme vynechání stránek na konečný výsledek (PO ŘEZÁNÍ)
        if !skipPages.isEmpty {
            print("⏭️ KROK 3: Aplikuji vynechání stránek na konečný výsledek (PO ŘEZÁNÍ)")
            let finalDocument = PDFDocument()
            var finalPageIndex = 0
            
            for pageIndex in 0..<outputDocument.pageCount {
                finalPageIndex += 1
                
                // Skip pages based on user input (čísla stránek v konečném výsledku)
                if skipPages.contains(finalPageIndex) {
                    print("⏭️ Přeskakuji stránku \(finalPageIndex) v konečném výsledku")
                    continue
                }
                
                if let page = outputDocument.page(at: pageIndex) {
                    finalDocument.insert(page, at: finalDocument.pageCount)
                    print("✅ Přidána stránka \(finalPageIndex) do konečného výsledku")
                }
            }
            
            let finalPageCount = finalDocument.pageCount
            print("✅ Dokončeno! Celkem vytvořeno \(finalPageCount) stránek")
            return finalPageCount > 0 ? finalDocument : nil
        }
        
        let finalPageCount = outputDocument.pageCount
        print("✅ Dokončeno! Celkem vytvořeno \(finalPageCount) stránek")
        return finalPageCount > 0 ? outputDocument : nil
    }
    
    /// Render a cropped tile of a PDF page to PDF data.
    private static func renderTile(from page: PDFPage, cropRect: CGRect, tileSize: CGSize) -> Data? {
        let mutableData = NSMutableData()
        guard let dataConsumer = CGDataConsumer(data: mutableData as CFMutableData) else { return nil }
        
        var mediaBox = CGRect(origin: .zero, size: tileSize)
        guard let context = CGContext(consumer: dataConsumer, mediaBox: &mediaBox, nil) else { return nil }
        
        context.beginPDFPage(nil)
        context.saveGState()
        
        // Calculate scale to maintain aspect ratio
        let scaleX = tileSize.width / cropRect.width
        let scaleY = tileSize.height / cropRect.height
        
        // Apply transformations: scale and translate to crop the desired region
        context.scaleBy(x: scaleX, y: scaleY)
        context.translateBy(x: -cropRect.minX, y: -cropRect.minY)
        
        page.draw(with: .mediaBox, to: context)
        
        context.restoreGState()
        context.endPDFPage()
        context.closePDF()
        
        return mutableData as Data
    }
}
