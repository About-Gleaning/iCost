import SwiftUI
import UIKit

@MainActor
enum ChartExporter {
    static func exportPNG(view: AnyView, fileName: String) {
        let renderer = ImageRenderer(content: view)
        if let uiImage = renderer.uiImage {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
            if let data = uiImage.pngData() { try? data.write(to: url) }
        }
    }
    static func exportPDF(view: AnyView, fileName: String) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 320, height: 240)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        try? renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            let hosting = UIHostingController(rootView: view)
            hosting.view.frame = pageRect
            hosting.view.drawHierarchy(in: pageRect, afterScreenUpdates: true)
        }
    }
}
