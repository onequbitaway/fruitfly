import AppKit

func exportIcon(to folder: URL) throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for size in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let pixels = size * scale
            let edge = CGFloat(pixels)
            let ctx = CGContext(
                data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: pixels * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.addPath(
                CGPath(
                    roundedRect: CGRect(x: edge * 0.04, y: edge * 0.04, width: edge * 0.92, height: edge * 0.92),
                    cornerWidth: edge * 0.2, cornerHeight: edge * 0.2, transform: nil))
            ctx.setFillColor(Palette.paper.cgColor)
            ctx.fillPath()
            ctx.setStrokeColor(Palette.blood.cgColor)
            ctx.setLineWidth(edge * 0.028)
            ctx.strokeEllipse(in: CGRect(x: edge * 0.15, y: edge * 0.15, width: edge * 0.7, height: edge * 0.7))
            FlyPainter.draw(
                in: ctx, at: CGPoint(x: edge / 2, y: edge / 2), heading: 0.8,
                time: 0, scale: Double(edge / 48), flying: true)
            let suffix = scale == 2 ? "@2x" : ""
            try savePNG(ctx.makeImage()!, to: folder.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
        }
    }
}
