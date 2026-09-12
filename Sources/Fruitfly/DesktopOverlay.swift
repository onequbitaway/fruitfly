import AppKit
import FlyCore

final class DesktopPanel: NSPanel {
    var placingFood = false
    override var canBecomeKey: Bool { placingFood }
    override var canBecomeMain: Bool { false }

    init(screen: NSScreen, world: FlyWorld) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        isMovable = false
        contentView = DesktopView(frame: NSRect(origin: .zero, size: screen.frame.size), world: world, origin: screen.frame.origin)
        setAccessibilityElement(false)
    }
}

final class DesktopView: NSView {
    let world: FlyWorld
    let origin: CGPoint
    var size: Double = 1.3
    var showBrain = false
    var placingFood = false
    var onPlaceFood: ((Point) -> Void)?
    var onCancel: (() -> Void)?
    private var lastFlyRect = CGRect.zero
    private var lastFoodRects: [CGRect] = []

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { placingFood }

    init(frame: NSRect, world: FlyWorld, origin: CGPoint) {
        self.world = world; self.origin = origin
        super.init(frame: frame)
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func refresh() {
        let point = local(world.position)
        let radius = 32 * size
        var rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        if showBrain { rect = rect.union(brainRect(at: point)) }
        setNeedsDisplay(lastFlyRect.union(rect))
        lastFlyRect = rect
        for r in lastFoodRects { setNeedsDisplay(r) }
        lastFoodRects = world.food.map {
            let p = local($0.position)
            return CGRect(x: p.x - 40, y: p.y - 40, width: 80, height: 80)
        }
        for r in lastFoodRects { setNeedsDisplay(r) }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(dirtyRect)
        if placingFood {
            let text = "Click to drop food. Press Esc to cancel."
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 15, weight: .medium), .foregroundColor: NSColor.white]
            let textSize = (text as NSString).size(withAttributes: attrs)
            let box = NSRect(x: bounds.midX - textSize.width / 2 - 22, y: bounds.maxY - 100, width: textSize.width + 44, height: 48)
            NSColor(white: 0.13, alpha: 0.94).setFill()
            NSBezierPath(roundedRect: box, xRadius: 24, yRadius: 24).fill()
            (text as NSString).draw(at: NSPoint(x: box.minX + 22, y: box.minY + 15), withAttributes: attrs)
        }
        for food in world.food {
            FlyPainter.crumb(in: ctx, at: local(food.position), amount: food.amount, age: food.age)
        }
        let point = local(world.position)
        if bounds.insetBy(dx: -60, dy: -60).contains(point) {
            FlyPainter.draw(in: ctx, at: point, heading: world.heading, time: world.time, scale: size,
                            flying: world.state != .resting && world.state != .eating,
                            eating: world.state == .eating)
            if showBrain { drawBrain(in: ctx, at: point) }
        }
    }

    private func brainRect(at p: CGPoint) -> CGRect {
        let x = min(bounds.maxX - 174, max(8, p.x + 27))
        let y = min(bounds.maxY - 65, max(8, p.y - 65))
        return CGRect(x: x, y: y, width: 166, height: 58)
    }

    private func drawBrain(in ctx: CGContext, at p: CGPoint) {
        let box = brainRect(at: p)
        NSColor(white: 0.12, alpha: 0.92).setFill()
        NSBezierPath(roundedRect: box, xRadius: 12, yRadius: 12).fill()
        let title = world.circuit == nil ? "Brain data unavailable" : "Smell circuit"
        (title as NSString).draw(at: NSPoint(x: box.minX + 12, y: box.minY + 34), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white
        ])
        guard let circuit = world.circuit else { return }
        for i in 0..<22 {
            let index = i * circuit.rates.count / 22
            let rate = CGFloat(circuit.rates[index])
            let height = 3 + rate * 14
            ctx.setFillColor(NSColor(red: 0.45 + 0.35 * rate, green: 0.62 + 0.25 * rate, blue: 1, alpha: 0.5 + 0.5 * rate).cgColor)
            ctx.fill(CGRect(x: box.minX + 12 + Double(i) * 6.5, y: box.minY + 11, width: 3.5, height: height))
        }
    }

    private func local(_ p: Point) -> CGPoint { CGPoint(x: p.x - origin.x, y: p.y - origin.y) }

    override func resetCursorRects() {
        if placingFood { addCursorRect(bounds, cursor: .crosshair) }
    }
    override func mouseDown(with event: NSEvent) {
        guard placingFood else { return }
        let point = convert(event.locationInWindow, from: nil)
        onPlaceFood?(Point(point.x + origin.x, point.y + origin.y))
    }
    override func rightMouseDown(with event: NSEvent) { if placingFood { onCancel?() } }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } else { super.keyDown(with: event) }
    }
}
