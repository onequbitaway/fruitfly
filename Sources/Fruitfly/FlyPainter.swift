import AppKit
import FlyCore

enum FlyPainter {
    static func draw(in ctx: CGContext, at point: CGPoint, heading: Double,
                     time: Double, scale: Double, flying: Bool, eating: Bool = false) {
        ctx.saveGState()
        ctx.translateBy(x: point.x, y: point.y)
        ctx.rotate(by: heading - .pi / 2)
        ctx.scaleBy(x: scale, y: scale)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        // The sprite is vector art, so it stays sharp on Retina screens.
        ctx.setShadow(offset: CGSize(width: 2, height: -3), blur: flying ? 6 : 2,
                      color: NSColor.black.withAlphaComponent(0.25).cgColor)
        ellipse(ctx, CGRect(x: -3, y: -9, width: 6, height: 16), color: NSColor(white: 0.2, alpha: 0.6))
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        // Three jointed legs on each side.
        for side in [-1.0, 1.0] {
            for leg in 0..<3 {
                let y = 3.0 - Double(leg) * 4
                let foot = flying ? 0.4 * sin(time * 12 + Double(leg)) : sin(time * (eating ? 5 : 1.4) + Double(leg))
                ctx.setStrokeColor(NSColor(white: 0.16, alpha: 0.9).cgColor)
                ctx.setLineWidth(0.65)
                ctx.beginPath()
                ctx.move(to: CGPoint(x: side * 2.5, y: y))
                ctx.addLine(to: CGPoint(x: side * (6.8 + foot), y: y + (leg == 0 ? 3 : -2)))
                ctx.addLine(to: CGPoint(x: side * (9.2 + foot), y: y + (leg == 0 ? 5 : -5)))
                ctx.strokePath()
            }
        }

        // Translucent wings with fine veins.
        for side in [-1.0, 1.0] {
            ctx.saveGState()
            let spread = flying ? 1.05 + sin(time * 137) * 0.16 : 0.57
            ctx.scaleBy(x: side * spread, y: 1)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 1.3, y: 2))
            path.addCurve(to: CGPoint(x: 14.5, y: -10), control1: CGPoint(x: 15, y: 4), control2: CGPoint(x: 20, y: -5))
            path.addCurve(to: CGPoint(x: 1.3, y: 2), control1: CGPoint(x: 8, y: -16), control2: CGPoint(x: 1, y: -7))
            ctx.addPath(path)
            ctx.setFillColor(NSColor(red: 0.85, green: 0.9, blue: 0.95, alpha: flying ? 0.57 : 0.68).cgColor)
            ctx.setStrokeColor(NSColor(red: 0.4, green: 0.45, blue: 0.5, alpha: 0.48).cgColor)
            ctx.setLineWidth(0.45)
            ctx.drawPath(using: .fillStroke)
            ctx.setStrokeColor(NSColor(white: 0.5, alpha: 0.4).cgColor)
            ctx.setLineWidth(0.3)
            ctx.beginPath(); ctx.move(to: CGPoint(x: 2, y: 1)); ctx.addLine(to: CGPoint(x: 14, y: -9)); ctx.strokePath()
            ctx.beginPath(); ctx.move(to: CGPoint(x: 7, y: -3)); ctx.addLine(to: CGPoint(x: 10, y: -11)); ctx.strokePath()
            ctx.restoreGState()
        }

        shadedEllipse(ctx, CGRect(x: -3.6, y: -11, width: 7.2, height: 13),
                      light: NSColor(red: 0.4, green: 0.32, blue: 0.23, alpha: 1), dark: NSColor(white: 0.12, alpha: 1))
        for y in [-7.8, -5.1, -2.5] {
            ctx.setStrokeColor(NSColor(white: 0.08, alpha: 0.65).cgColor)
            ctx.setLineWidth(0.8)
            ctx.beginPath(); ctx.move(to: CGPoint(x: -2.8, y: y)); ctx.addQuadCurve(to: CGPoint(x: 2.8, y: y), control: CGPoint(x: 0, y: y - 1)); ctx.strokePath()
        }
        shadedEllipse(ctx, CGRect(x: -4, y: -1.5, width: 8, height: 9), light: NSColor(white: 0.34, alpha: 1), dark: NSColor(white: 0.09, alpha: 1))
        ellipse(ctx, CGRect(x: -3.6, y: 5.5, width: 7.2, height: 5.3), color: NSColor(white: 0.13, alpha: 1))
        for side in [-1.0, 1.0] {
            shadedEllipse(ctx, CGRect(x: side * 2.4 - 1.6, y: 6.2, width: 3.2, height: 4.4),
                          light: NSColor(red: 0.69, green: 0.24, blue: 0.15, alpha: 1), dark: NSColor(red: 0.33, green: 0.09, blue: 0.06, alpha: 1))
            ctx.setStrokeColor(NSColor(white: 0.13, alpha: 1).cgColor); ctx.setLineWidth(0.5)
            ctx.beginPath(); ctx.move(to: CGPoint(x: side, y: 10)); ctx.addLine(to: CGPoint(x: side * 2, y: 12.4)); ctx.strokePath()
        }
        if eating {
            ctx.setStrokeColor(NSColor(red: 0.42, green: 0.25, blue: 0.12, alpha: 1).cgColor)
            ctx.setLineWidth(0.8); ctx.beginPath(); ctx.move(to: CGPoint(x: 0, y: 10))
            ctx.addLine(to: CGPoint(x: sin(time * 8) * 0.4, y: 13)); ctx.strokePath()
        }
        ctx.restoreGState()
    }

    static func crumb(in ctx: CGContext, at point: CGPoint, amount: Double, age: Double) {
        ctx.saveGState()
        ctx.translateBy(x: point.x, y: point.y)
        if age < 0.9 {
            ctx.setStrokeColor(NSColor.systemOrange.withAlphaComponent((1 - age / 0.9) * 0.5).cgColor)
            ctx.setLineWidth(1)
            let radius = 8 + age * 24
            ctx.strokeEllipse(in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        }
        let scale = max(0.15, sqrt(max(0, amount)))
        ctx.scaleBy(x: scale, y: scale)
        ctx.setShadow(offset: CGSize(width: 0, height: -1), blur: 2, color: NSColor.black.withAlphaComponent(0.2).cgColor)
        for (x, y, r) in [(-3.0, 1.0, 3.0), (2.0, 3.0, 2.7), (1.0, -2.0, 3.2), (-5.0, -3.0, 1.3), (5.0, 0.0, 1.2)] {
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 1.7)
            shadedEllipse(ctx, rect, light: NSColor(red: 1, green: 0.85, blue: 0.48, alpha: 1), dark: NSColor(red: 0.67, green: 0.4, blue: 0.14, alpha: 1))
        }
        ctx.restoreGState()
    }

    static func icon(size: CGFloat = 20) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            draw(in: ctx, at: CGPoint(x: rect.midX, y: rect.midY), heading: .pi / 2,
                 time: 0, scale: Double(size / 28), flying: false)
            return true
        }
        image.isTemplate = false
        return image
    }

    static func ellipse(_ ctx: CGContext, _ rect: CGRect, color: NSColor) {
        ctx.setFillColor(color.cgColor); ctx.fillEllipse(in: rect)
    }
    private static func shadedEllipse(_ ctx: CGContext, _ rect: CGRect, light: NSColor, dark: NSColor) {
        ctx.saveGState()
        ctx.addEllipse(in: rect); ctx.clip()
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [light.cgColor, dark.cgColor] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
        }
        ctx.restoreGState()
    }
}
