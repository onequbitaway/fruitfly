import AppKit
import SwiftUI

enum PreviewRenderer {
    static func saveView(_ view: NSView, to path: String) throws {
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw NSError(domain: "Fruitfly.Preview", code: 1)
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "Fruitfly.Preview", code: 2)
        }
        try png.write(to: URL(fileURLWithPath: path))
    }

    static func saveIcon(to directory: String) throws {
        let folder = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for size in [16, 32, 128, 256, 512] {
            for multiplier in [1, 2] {
                let pixels = size * multiplier
                guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                    let graphics = NSGraphicsContext(bitmapImageRep: rep) else { continue }
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = graphics
                let ctx = graphics.cgContext
                let edge = Double(pixels)
                let r = CGRect(x: edge * 0.06, y: edge * 0.06, width: edge * 0.88, height: edge * 0.88)
                NSColor(red: 0.88, green: 0.93, blue: 1, alpha: 1).setFill()
                NSBezierPath(roundedRect: r, xRadius: edge * 0.2, yRadius: edge * 0.2).fill()
                FlyPainter.draw(in: ctx, at: CGPoint(x: edge * 0.5, y: edge * 0.5), heading: 0.98, time: 0, scale: edge / 39, flying: false)
                NSGraphicsContext.restoreGraphicsState()
                if let png = rep.representation(using: .png, properties: [:]) {
                    let suffix = multiplier == 2 ? "@2x" : ""
                    try png.write(to: folder.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
                }
            }
        }
    }

    /// Draw only this app's own views. No desktop or other app is captured.
    static func save(to path: String, controller: PetController) throws {
        let width = 1080, height = 680
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return }
        NSColor(red: 0.93, green: 0.96, blue: 0.99, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        ("A little life\non your desktop." as NSString).draw(in: NSRect(x: 64, y: 395, width: 470, height: 155), withAttributes: [
            .font: NSFont.systemFont(ofSize: 47, weight: .semibold), .foregroundColor: NSColor(red: 0.15, green: 0.21, blue: 0.31, alpha: 1)
        ])
        ("Drop a crumb. Meet your new pet." as NSString).draw(at: NSPoint(x: 67, y: 359), withAttributes: [
            .font: NSFont.systemFont(ofSize: 18), .foregroundColor: NSColor(red: 0.37, green: 0.43, blue: 0.53, alpha: 1)
        ])
        FlyPainter.draw(in: ctx, at: CGPoint(x: 205, y: 210), heading: 0.6, time: 1, scale: 4.3, flying: true)
        FlyPainter.crumb(in: ctx, at: CGPoint(x: 413, y: 229), amount: 1, age: 0.4)
        ("Actual fly, enlarged" as NSString).draw(at: NSPoint(x: 137, y: 100), withAttributes: [
            .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor(red: 0.37, green: 0.43, blue: 0.53, alpha: 1)
        ])
        image.unlockFocus()
        let hosting = NSHostingView(rootView: ControlPanel(controller: controller).background(Color(nsColor: .windowBackgroundColor)))
        let fitting = hosting.fittingSize
        hosting.frame = NSRect(x: 0, y: 0, width: 310, height: max(440, fitting.height))
        hosting.layoutSubtreeIfNeeded()
        if let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            let panelImage = NSImage(size: hosting.bounds.size)
            panelImage.addRepresentation(bitmap)
            image.lockFocus()
            panelImage.draw(in: NSRect(x: 675, y: 110, width: 310, height: hosting.bounds.height))
            image.unlockFocus()
        }
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try png.write(to: URL(fileURLWithPath: path))
        print("Saved app preview: \(path)")
    }
}
