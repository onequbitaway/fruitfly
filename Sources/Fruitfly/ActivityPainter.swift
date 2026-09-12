import AppKit
import CoreText
import FlyCore

/// Used by the live window and the public recording. Drawing reads model values only.
enum ActivityPainter {
    private struct TextKey: Hashable {
        let string: String
        let size: CGFloat
        let weight: CGFloat
        let color: NSColor
        let mono: Bool
    }
    private static var textLines: [TextKey: (CTLine, CGFloat)] = [:]
    static let background = NSColor(red: 0.043, green: 0.082, blue: 0.14, alpha: 1)
    static let foreground = NSColor(red: 0.89, green: 0.94, blue: 0.99, alpha: 1)
    static let secondary = NSColor(red: 0.53, green: 0.64, blue: 0.75, alpha: 1)
    static let colors = [
        NSColor(red: 0.25, green: 0.84, blue: 0.84, alpha: 1),
        NSColor(red: 1, green: 0.68, blue: 0.42, alpha: 1),
        NSColor(red: 0.67, green: 0.61, blue: 0.96, alpha: 1)
    ]

    static func draw(in ctx: CGContext, rect: CGRect, data: CircuitData, layout: ActivityLayout,
                     reading: ActivityReading, history: ActivityHistory, mode: String, cellCache: ActivityCellCache? = nil) {
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.translateBy(x: rect.minX, y: rect.minY)
        let w = rect.width, h = rect.height
        ctx.setFillColor(background.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        text("Brain activity", at: CGPoint(x: 24, y: h - 43), size: 24, weight: .semibold)
        text(mode, at: CGPoint(x: 25, y: h - 65), size: 11, color: secondary)
        text(String(format: "%.2f s", reading.time), at: CGPoint(x: w - 106, y: h - 40), size: 19, mono: true)
        text("\(data.ids.count.formatted()) cells", at: CGPoint(x: w - 108, y: h - 64), size: 11, color: secondary)

        let legendY = h - 91
        for (column, kind) in [0, 2, 1].enumerated() {
            let x = 26 + Double(column) * (w - 48) / 3
            ctx.setFillColor(colors[kind].cgColor)
            ctx.fillEllipse(in: CGRect(x: x, y: legendY + 3, width: 5, height: 5))
            let name = ["Smell cells", "Output cells", "Local cells"][kind]
            text(name, at: CGPoint(x: x + 11, y: legendY), size: 11, color: secondary)
            text(String(format: "%.2f", reading.groupMeans[kind]),
                 at: CGPoint(x: x + 94, y: legendY), size: 11, color: colors[kind], mono: true)
        }

        let graph = CGRect(x: 24, y: 191, width: w - 48, height: max(110, h - 300))
        if let cellCache {
            cellCache.draw(in: ctx, rect: graph, data: data, layout: layout, reading: reading)
        } else {
            drawCells(in: ctx, rect: graph, data: data, layout: layout, reading: reading)
        }

        text("\(reading.activeCells.formatted()) cells above 0.01", at: CGPoint(x: 25, y: 163), size: 11, color: secondary)
        text("Model value", at: CGPoint(x: w - 180, y: 163), size: 10, color: secondary)
        for bucket in 0..<16 {
            ctx.setFillColor(nodeColor(kind: 0, bucket: bucket).cgColor)
            ctx.fill(CGRect(x: w - 101 + Double(bucket) * 3.5, y: 165, width: 3.5, height: 6))
        }
        text("0", at: CGPoint(x: w - 112, y: 162), size: 9, color: secondary)
        text("1", at: CGPoint(x: w - 40, y: 162), size: 9, color: secondary)

        drawHistory(in: ctx, rect: CGRect(x: 42, y: 58, width: w - 68, height: 67), history: history)
        text("Food input", at: CGPoint(x: 25, y: 137), size: 10, color: colors[0])
        text("Circuit output", at: CGPoint(x: 104, y: 137), size: 10, color: colors[1])
        text("Last 10 seconds", at: CGPoint(x: w - 116, y: 137), size: 10, color: secondary)
        text("One dot per cell. Positions are schematic.", at: CGPoint(x: 25, y: 28), size: 10, color: secondary)
        text("\(layout.connections.count) measured connections shown", at: CGPoint(x: 25, y: 12), size: 10, color: secondary)
        ctx.restoreGState()
    }

    static func drawCells(in ctx: CGContext, rect: CGRect, data: CircuitData,
                          layout: ActivityLayout, reading: ActivityReading) {
        let positions = layout.positions.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
        // Lines are fixed measured connections. Opacity follows the source cell.
        // These are not invented travelling spikes or anatomical axons.
        let edgePaths = (0..<16).map { _ in CGMutablePath() }
        for index in layout.connections {
            let from = data.from[index], to = data.to[index]
            let a = positions[from], b = positions[to]
            let bucket = Int(max(0, min(15, reading.rates[from] * 15)))
            let path = edgePaths[bucket]
            path.move(to: a)
            path.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2 + (b.y - a.y) * 0.12, y: (a.y + b.y) / 2))
        }
        ctx.setLineWidth(0.45)
        for bucket in 0..<16 {
            ctx.setStrokeColor(NSColor(red: 0.43, green: 0.65, blue: 0.80,
                                       alpha: 0.025 + Double(bucket) / 15 * 0.13).cgColor)
            ctx.addPath(edgePaths[bucket]); ctx.strokePath()
        }
        let radius = max(0.75, min(1.45, rect.width / 480))
        let paths = (0..<48).map { _ in CGMutablePath() }
        for i in positions.indices {
            // A fixed 16-level color scale. No gain changes between frames.
            let bucket = Int(max(0, min(15, reading.rates[i] * 15)))
            let p = positions[i]
            paths[data.kinds[i] * 16 + bucket].addEllipse(in: CGRect(x: p.x - radius, y: p.y - radius,
                                                                   width: radius * 2, height: radius * 2))
        }
        for kind in 0..<3 {
            for bucket in 0..<16 {
                ctx.setFillColor(nodeColor(kind: kind, bucket: bucket).cgColor)
                ctx.addPath(paths[kind * 16 + bucket]); ctx.fillPath()
            }
        }
    }

    private static func nodeColor(kind: Int, bucket: Int) -> NSColor {
        let t = Double(bucket) / 15
        let c = colors[kind].usingColorSpace(.deviceRGB)!
        return NSColor(red: 0.12 + (c.redComponent - 0.12) * t,
                       green: 0.20 + (c.greenComponent - 0.20) * t,
                       blue: 0.29 + (c.blueComponent - 0.29) * t, alpha: 1)
    }

    private static func drawHistory(in ctx: CGContext, rect: CGRect, history: ActivityHistory) {
        guard let last = history.points.last else { return }
        let end = max(history.duration, last.time), start = end - history.duration
        ctx.setLineWidth(0.5)
        for value in [0.0, 0.5, 1.0] {
            let y = rect.minY + value * rect.height
            ctx.setStrokeColor(secondary.withAlphaComponent(0.17).cgColor)
            ctx.move(to: CGPoint(x: rect.minX, y: y)); ctx.addLine(to: CGPoint(x: rect.maxX, y: y)); ctx.strokePath()
            text(String(format: "%.1f", value), at: CGPoint(x: rect.minX - 23, y: y - 4), size: 8, color: secondary)
        }
        ctx.saveGState(); ctx.clip(to: rect.insetBy(dx: -1, dy: -1))
        for kind in [0, 1] {
            let path = CGMutablePath()
            for (i, point) in history.points.enumerated() {
                let value = kind == 0 ? point.foodInput : point.output
                let p = CGPoint(x: rect.minX + (point.time - start) / history.duration * rect.width,
                                y: rect.minY + value * rect.height)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            ctx.setStrokeColor(colors[kind].cgColor); ctx.setLineWidth(1.5)
            ctx.addPath(path); ctx.strokePath()
        }
        ctx.restoreGState()
    }

    static func text(_ string: String, at point: CGPoint, size: CGFloat,
                     weight: NSFont.Weight = .regular, color: NSColor = foreground, mono: Bool = false) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let key = TextKey(string: string, size: size, weight: weight.rawValue, color: color, mono: mono)
        let entry: (CTLine, CGFloat)
        if let saved = textLines[key] { entry = saved }
        else {
            let font = mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor
            ]
            entry = (CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes)), -font.descender)
            // Bound memory as the model clock adds new labels.
            if textLines.count >= 512 { textLines.removeAll(keepingCapacity: true) }
            textLines[key] = entry
        }
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: point.x, y: point.y + entry.1)
        CTLineDraw(entry.0, ctx)
        ctx.restoreGState()
    }
}

/// Reuse the cell picture only when every model value and the view size match.
/// The live clock and history still draw from the latest completed step.
final class ActivityCellCache {
    private var rates: [Float] = []
    private var size = CGSize.zero
    private var scale: CGFloat = 0
    private var image: CGImage?

    func draw(in ctx: CGContext, rect: CGRect, data: CircuitData, layout: ActivityLayout, reading: ActivityReading) {
        let pixelScale = max(1, abs(ctx.ctm.a))
        if image == nil || size != rect.size || scale != pixelScale || rates != reading.rates {
            let width = Int(ceil(rect.width * pixelScale)), height = Int(ceil(rect.height * pixelScale))
            if let buffer = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                buffer.scaleBy(x: pixelScale, y: pixelScale)
                ActivityPainter.drawCells(in: buffer, rect: CGRect(origin: .zero, size: rect.size),
                                          data: data, layout: layout, reading: reading)
                image = buffer.makeImage()
                rates = reading.rates; size = rect.size; scale = pixelScale
            } else { image = nil }
        }
        if let image { ctx.draw(image, in: rect) }
        else { ActivityPainter.drawCells(in: ctx, rect: rect, data: data, layout: layout, reading: reading) }
    }
}
