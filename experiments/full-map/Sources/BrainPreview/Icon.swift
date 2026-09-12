import AppKit
import ImageIO
import UniformTypeIdentifiers

func exportIcon(to folder: URL) throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for size in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let pixels = size * scale
            let edge = CGFloat(pixels)
            let ctx = CGContext(
                data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                bytesPerRow: pixels * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.addPath(
                CGPath(
                    roundedRect: CGRect(x: edge * 0.04, y: edge * 0.04, width: edge * 0.92, height: edge * 0.92),
                    cornerWidth: edge * 0.2, cornerHeight: edge * 0.2, transform: nil))
            ctx.setFillColor(NSColor(srgbRed: 0.68, green: 0.81, blue: 0.94, alpha: 1).cgColor)
            ctx.fillPath()
            FlyPainter.draw(
                in: ctx, at: CGPoint(x: edge / 2, y: edge / 2), heading: 0.8,
                time: 0, scale: Double(edge / 38), flying: false)
            let suffix = scale == 2 ? "@2x" : ""
            let file = folder.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
            guard let image = ctx.makeImage(),
                let dest = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil)
            else {
                throw CocoaError(.fileWriteUnknown)
            }
            CGImageDestinationAddImage(dest, image, nil)
            guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
        }
    }
}
