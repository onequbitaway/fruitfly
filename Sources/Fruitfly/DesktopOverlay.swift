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
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
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
