import AppKit
import CryptoKit
import ImageIO
import UniformTypeIdentifiers
import FlyCore

enum ActivityRecorder {
    static let width = 1000, height = 640
    static let sourceFiles = [
        "Sources/FlyCore/SmellCircuit.swift", "Sources/FlyCore/FlyWorld.swift", "Sources/FlyCore/Geometry.swift",
        "Sources/FlyCore/ActivityReading.swift", "Sources/Fruitfly/ActivityPainter.swift",
        "Sources/Fruitfly/ActivityRecorder.swift", "Sources/Fruitfly/FlyPainter.swift",
        "Sources/FlyCore/Resources/smell-circuit.json"
    ]

    static func save(to directory: String, sourceRoot: String) throws {
        let folder = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try CircuitData.bundled()
        let demo = try ActivityDemo(data: data)
        let layout = ActivityLayout(data: data)
        let gifURL = folder.appendingPathComponent("brain-activity.gif")
        guard let gif = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString,
                                                        ActivityDemo.frames, nil) else { throw error("Cannot create GIF") }
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let delay = 1.0 / Double(ActivityDemo.fps)
        let options = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay,
                                                       kCGImagePropertyGIFUnclampedDelayTime: delay]] as CFDictionary
        var raw = Data()
        var frames: [ActivityFrame] = []
        for frame in 0..<ActivityDemo.frames {
            try autoreleasepool {
                let reading = demo.advance()
                frames.append(ActivityFrame(reading: reading, world: demo.world))
                for rate in reading.rates {
                    var bits = rate.bitPattern.littleEndian
                    withUnsafeBytes(of: &bits) { raw.append(contentsOf: $0) }
                }
                let image = try render(demo: demo, data: data, layout: layout, reading: reading)
                CGImageDestinationAddImage(gif, image, options)
                if [0, 50, 160, 239].contains(frame) {
                    let name = frame == 50 ? "brain-activity.png" : "frame-\(frame).png"
                    guard let png = CGImageDestinationCreateWithURL(folder.appendingPathComponent(name) as CFURL,
                            UTType.png.identifier as CFString, 1, nil) else { throw error("Cannot create PNG") }
                    CGImageDestinationAddImage(png, image, nil)
                    guard CGImageDestinationFinalize(png) else { throw error("Cannot write PNG") }
                }
            }
            if frame % 40 == 0 { print("Recorded \(frame + 1)/\(ActivityDemo.frames) frames"); fflush(stdout) }
        }
        guard CGImageDestinationFinalize(gif) else { throw error("Cannot write GIF") }
        let rawURL = folder.appendingPathComponent("cell-activity.f32")
        try raw.write(to: rawURL)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(frames).write(to: folder.appendingPathComponent("activity-frames.json"))
        var hashes: [String: String] = [:]
        for path in sourceFiles {
            hashes[path] = try hash(URL(fileURLWithPath: sourceRoot).appendingPathComponent(path))
        }
        let manifest: [String: Any] = [
            "description": "Recorded model run. Values are simulated, not measured in a living fly.",
            "frames": ActivityDemo.frames, "fps": ActivityDemo.fps, "seed": ActivityDemo.seed,
            "width": width, "height": height, "playbackSpeed": 1,
            "foodAtSeconds": Double(ActivityDemo.foodFrame) / Double(ActivityDemo.fps),
            "cellCount": data.ids.count, "rateFormat": "IEEE 754 float32, little endian, frame then cell",
            "cellOrder": "ids array in Sources/FlyCore/Resources/smell-circuit.json",
            "positions": "Schematic. Not anatomical coordinates.",
            "colors": "Fixed 0 to 1 scale. 16 levels: floor(rate * 15). No changing gain.",
            "connections": "600 strongest retained connections between different cell classes. Opacity uses the source cell value.",
            "sourceSHA256": hashes,
            "fileSHA256": ["brain-activity.gif": try hash(gifURL), "cell-activity.f32": try hash(rawURL),
                           "activity-frames.json": try hash(folder.appendingPathComponent("activity-frames.json"))]
        ]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            .write(to: folder.appendingPathComponent("activity-manifest.json"))
        print("Saved recording and all \(frames.count * data.ids.count) cell values to \(directory)")
    }

    private static func render(demo: ActivityDemo, data: CircuitData, layout: ActivityLayout,
                               reading: ActivityReading) throws -> CGImage {
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw error("Cannot create frame") }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }
        ctx.setFillColor(ActivityPainter.background.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ActivityPainter.text("Drop food. Watch the circuit respond.", at: CGPoint(x: 28, y: 589), size: 27, weight: .semibold)
        ActivityPainter.text("FRUITFLY  /  A desktop pet with a small smell circuit", at: CGPoint(x: 30, y: 564), size: 11,
                             color: ActivityPainter.secondary)
        ctx.setStrokeColor(ActivityPainter.secondary.withAlphaComponent(0.2).cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: 324, y: 34)); ctx.addLine(to: CGPoint(x: 324, y: 542)); ctx.strokePath()
        ActivityPainter.draw(in: ctx, rect: CGRect(x: 326, y: 12, width: 674, height: 538), data: data,
                             layout: layout, reading: reading, history: demo.history, mode: "Recorded model · 1× replay")
        let world = demo.world
        ActivityPainter.text("THE FLY", at: CGPoint(x: 30, y: 516), size: 11, weight: .semibold, color: ActivityPainter.secondary)
        let status = demo.frame <= ActivityDemo.foodFrame ? "No food yet" : world.state.rawValue
        ActivityPainter.text(status, at: CGPoint(x: 30, y: 483), size: 23, weight: .medium)
        let field = CGRect(x: 22, y: 117, width: 280, height: 350)
        ctx.setFillColor(NSColor(red: 0.065, green: 0.112, blue: 0.18, alpha: 1).cgColor)
        ctx.addPath(CGPath(roundedRect: field, cornerWidth: 16, cornerHeight: 16, transform: nil)); ctx.fillPath()
        ctx.saveGState(); ctx.clip(to: field); ctx.translateBy(x: field.minX, y: field.minY)
        for crumb in world.food {
            FlyPainter.crumb(in: ctx, at: CGPoint(x: crumb.position.x, y: crumb.position.y), amount: crumb.amount, age: crumb.age)
        }
        FlyPainter.draw(in: ctx, at: CGPoint(x: world.position.x, y: world.position.y), heading: world.heading,
                        time: world.time, scale: 1.7, flying: world.state != .resting && world.state != .eating,
                        eating: world.state == .eating)
        ctx.restoreGState()
        ActivityPainter.text(demo.frame <= ActivityDemo.foodFrame ? "Food drops at 1.50 s" : "Food dropped at 1.50 s",
                             at: CGPoint(x: 30, y: 91), size: 12, color: ActivityPainter.colors[0])
        ActivityPainter.text("\(world.eaten) crumb eaten · Fly enlarged", at: CGPoint(x: 30, y: 68), size: 11, color: ActivityPainter.secondary)
        ActivityPainter.text("Actual model values. Saved for checking.", at: CGPoint(x: 30, y: 35), size: 10, color: ActivityPainter.secondary)
        guard let result = ctx.makeImage() else { throw error("Cannot finish frame") }
        return result
    }

    private static func hash(_ url: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }
    private static func error(_ message: String) -> NSError {
        NSError(domain: "Fruitfly.ActivityRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
