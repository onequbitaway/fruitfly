import AppKit
import BrainCore
import CoreText

enum Ink {
    static let background = NSColor(srgbRed: 0.043, green: 0.082, blue: 0.14, alpha: 1)
    static let panel = NSColor(srgbRed: 0.075, green: 0.13, blue: 0.20, alpha: 1)
    static let text = NSColor(srgbRed: 0.89, green: 0.94, blue: 0.99, alpha: 1)
    static let muted = NSColor(srgbRed: 0.55, green: 0.66, blue: 0.76, alpha: 1)
    static let groups = [
        NSColor(srgbRed: 0.25, green: 0.84, blue: 0.84, alpha: 1),
        NSColor(srgbRed: 1, green: 0.68, blue: 0.42, alpha: 1), NSColor(srgbRed: 0.48, green: 0.68, blue: 1, alpha: 1),
        NSColor(srgbRed: 0.67, green: 0.61, blue: 0.96, alpha: 1),
        NSColor(srgbRed: 0.86, green: 0.56, blue: 0.83, alpha: 1),
        NSColor(srgbRed: 0.55, green: 0.84, blue: 0.57, alpha: 1),
        NSColor(srgbRed: 1, green: 0.48, blue: 0.47, alpha: 1),
        NSColor(srgbRed: 0.65, green: 0.71, blue: 0.77, alpha: 1),
        NSColor(srgbRed: 0.69, green: 0.76, blue: 0.44, alpha: 1),
    ]
    private struct Key: Hashable {
        let string: String
        let size: CGFloat
        let weight: CGFloat
        let color: NSColor
    }
    private static var lines: [Key: (CTLine, CGFloat)] = [:]
    static func label(
        _ string: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat = 12, _ color: NSColor = text,
        _ weight: NSFont.Weight = .regular
    ) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let key = Key(string: string, size: size, weight: weight.rawValue, color: color)
        let entry: (CTLine, CGFloat)
        if let saved = lines[key] {
            entry = saved
        } else {
            let font = NSFont.systemFont(ofSize: size, weight: weight)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
            ]
            entry = (
                CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attrs)), -font.descender
            )
            if lines.count > 600 { lines.removeAll(keepingCapacity: true) }
            lines[key] = entry
        }
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: x, y: y + entry.1)
        CTLineDraw(entry.0, ctx)
        ctx.restoreGState()
    }
    static func line(_ ctx: CGContext, _ a: CGPoint, _ b: CGPoint, _ color: NSColor = muted) {
        ctx.setStrokeColor(color.withAlphaComponent(0.2).cgColor)
        ctx.setLineWidth(0.7)
        ctx.move(to: a)
        ctx.addLine(to: b)
        ctx.strokePath()
    }
}

/// One point per known cell-body position. Missing coordinates are never invented.
final class MapDrawing {
    let metadata: BrainMetadata
    var coordinates: [CGPoint?] = []
    var known = 0
    private var cached: CGImage?
    private var size = CGSize.zero
    init(metadata: BrainMetadata) { self.metadata = metadata }
    func prepare(size: CGSize) {
        guard self.size != size else { return }
        self.size = size
        let brain = CGRect(x: 10, y: 115, width: size.width - 115, height: size.height - 130)
        let cord = CGRect(x: size.width - 95, y: 30, width: 85, height: size.height - 120)
        func map(_ p: [Int]) -> CGPoint {
            if p[2] < 55000 {
                return CGPoint(
                    x: brain.minX + Double(p[0]) / 100000 * brain.width,
                    y: brain.maxY - (Double(p[2]) - 6000) / 49000 * brain.height)
            }
            return CGPoint(
                x: cord.minX + (Double(p[0]) - 27000) / 49000 * cord.width,
                y: cord.maxY - (Double(p[2]) - 55000) / 80000 * cord.height)
        }
        coordinates = metadata.positions.map { $0.map(map) }
        known = coordinates.compactMap { $0 }.count
        let scale: CGFloat = 2
        guard
            let ctx = CGContext(
                data: nil, width: Int(size.width * scale), height: Int(size.height * scale), bitsPerComponent: 8,
                bytesPerRow: Int(size.width * scale) * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return }
        ctx.scaleBy(x: scale, y: scale)
        ctx.setFillColor(NSColor(srgbRed: 0.12, green: 0.19, blue: 0.27, alpha: 1).cgColor)
        for p in coordinates.compactMap({ $0 }) {
            ctx.fillEllipse(in: CGRect(x: p.x - 0.5, y: p.y - 0.5, width: 1, height: 1))
        }
        cached = ctx.makeImage()
    }
    func draw(_ ctx: CGContext, rect: CGRect, snapshot: BrainSnapshot, focus: Int?) {
        prepare(size: rect.size)
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.translateBy(x: rect.minX, y: rect.minY)
        if let cached { ctx.draw(cached, in: CGRect(origin: .zero, size: rect.size)) }
        let colors = (0..<9).map { group in
            (0..<12).map { level in Ink.groups[group].withAlphaComponent(0.22 + 0.78 * Double(level) / 11).cgColor }
        }
        for i in snapshot.rates.indices {
            guard snapshot.rates[i] > 0, let p = coordinates[i], focus == nil || metadata.groups[i] == focus else {
                continue
            }
            let level = min(11, max(1, Int(snapshot.rates[i] / 100 * 11)))
            ctx.setFillColor(colors[metadata.groups[i]][level])
            ctx.fillEllipse(in: CGRect(x: p.x - 0.8, y: p.y - 0.8, width: 1.6, height: 1.6))
        }
        Ink.label("Brain", 18, rect.height - 22, 12, Ink.muted)
        Ink.label("Nerve cord", rect.width - 100, rect.height - 75, 10, Ink.muted)
        Ink.label("Published cell-body positions", 18, 84, 11, Ink.muted)
        Ink.label(
            "\(known.formatted()) plotted · \((metadata.ids.count-known).formatted()) have no recorded position", 18,
            64, 10, Ink.muted)
        Ink.label("All cells are included in the calculation.", 18, 46, 10, Ink.muted)
        Ink.label("Brightness: 0–100+ spikes/second", 18, 16, 10, Ink.muted)
        for level in 0..<12 {
            ctx.setFillColor(Ink.groups[0].withAlphaComponent(Double(level) / 11).cgColor)
            ctx.fill(CGRect(x: 230 + CGFloat(level) * 5, y: 20, width: 5, height: 6))
        }
        ctx.restoreGState()
    }
}
