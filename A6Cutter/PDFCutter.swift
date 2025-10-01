import Foundation
import PDFKit
import CoreGraphics

enum PDFCutter {
    /// Cut a PDF document into A6 tiles preserving orientation.
    static func cutToA6(document: PDFDocument) -> PDFDocument? {
        let outputDocument = PDFDocument()
        
        // A6 size in mm
        let a6WidthMM: CGFloat = 105
        let a6HeightMM: CGFloat = 148
        
        // Convert mm to points (72 dpi)
        func mmToPoints(_ mm: CGFloat) -> CGFloat {
            return mm / 25.4 * 72
        }
        
        let pageCount = document.pageCount
        
        for pageIndex in 0..<pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            
            // Determine A6 tile size in points, preserving the orientation of the page
            let pageIsLandscape = pageRect.width > pageRect.height
            
            let a6WidthPts = mmToPoints(pageIsLandscape ? a6HeightMM : a6WidthMM)
            let a6HeightPts = mmToPoints(pageIsLandscape ? a6WidthMM : a6HeightMM)
            
            // Calculate how many tiles fit horizontally and vertically
            var cols = Int(floor(pageRect.width / a6WidthPts))
            var rows = Int(floor(pageRect.height / a6HeightPts))
            
            if cols == 0 || rows == 0 {
                // Ensure at least one tile in each direction, adjust tile size accordingly
                cols = max(1, Int(ceil(pageRect.width / a6WidthPts)))
                rows = max(1, Int(ceil(pageRect.height / a6HeightPts)))
            }
            
            let tileWidth = pageRect.width / CGFloat(cols)
            let tileHeight = pageRect.height / CGFloat(rows)
            
            for row in 0..<rows {
                for col in 0..<cols {
                    let cropRect = CGRect(
                        x: pageRect.minX + CGFloat(col) * tileWidth,
                        y: pageRect.minY + CGFloat(row) * tileHeight,
                        width: tileWidth,
                        height: tileHeight
                    )
                    
                    guard let tilePDFData = renderTile(from: page, cropRect: cropRect, tileSize: CGSize(width: tileWidth, height: tileHeight)),
                          let tileDocument = PDFDocument(data: tilePDFData),
                          let tilePage = tileDocument.page(at: 0) else {
                        continue
                    }
                    
                    outputDocument.insert(tilePage, at: outputDocument.pageCount)
                }
            }
        }
        
        return outputDocument.pageCount > 0 ? outputDocument : nil
    }
    
    /// Render a cropped tile of a PDF page to PDF data.
    private static func renderTile(from page: PDFPage, cropRect: CGRect, tileSize: CGSize) -> Data? {
        let mutableData = NSMutableData()
        guard let dataConsumer = CGDataConsumer(data: mutableData as CFMutableData) else { return nil }
        
        var mediaBox = CGRect(origin: .zero, size: tileSize)
        guard let context = CGContext(consumer: dataConsumer, mediaBox: &mediaBox, nil) else { return nil }
        
        context.beginPDFPage(nil)
        context.saveGState()
        
        // Transform page content to fit tile size and crop
        let drawTransform = page.getDrawingTransform(.mediaBox, rect: CGRect(origin: .zero, size: tileSize), rotate: 0, preserveAspectRatio: false)
        context.concatenate(drawTransform)
        context.translateBy(x: -cropRect.minX, y: -cropRect.minY)
        
        page.draw(with: .mediaBox, to: context)
        
        context.restoreGState()
        context.endPDFPage()
        context.closePDF()
        
        return mutableData as Data
    }
}
