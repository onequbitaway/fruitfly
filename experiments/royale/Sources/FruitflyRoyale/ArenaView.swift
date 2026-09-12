import AppKit
import RoyaleCore

final class ArenaView: NSView {
    let controller: RoyaleController
    private let pause = NSButton(title: "Pause", target: nil, action: nil)
    private let restart = NSButton(title: "New round", target: nil, action: nil)
    private let modes = NSSegmentedControl(
        labels: ["Simple", "Full map"], trackingMode: .selectOne, target: nil, action: nil)
    private let blood = NSButton(checkboxWithTitle: "Blood effects", target: nil, action: nil)
    private var timer: Timer?
    private var frameReceived = ProcessInfo.processInfo.systemUptime
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    init(controller: RoyaleController) {
        self.controller = controller
        super.init(frame: CGRect(origin: .zero, size: ArenaPainter.size))
        for button in [pause, restart, blood] {
            button.target = self
            addSubview(button)
        }
        pause.action = #selector(togglePause)
        restart.action = #selector(newRound)
        blood.action = #selector(toggleBlood)
        for button in [pause, restart] { button.bezelStyle = .rounded }
        modes.target = self
        modes.action = #selector(selectBrainMode)
        modes.selectedSegment = controller.mode == .simple ? 0 : 1
        addSubview(modes)
        modes.setToolTip("3,745 cells per fly. Uses less memory.", forSegment: 0)
        modes.setToolTip("166,700 cells per fly. Uses more memory and may run slowly.", forSegment: 1)
        blood.state = .on
        pause.setAccessibilityLabel("Pause or resume the round")
        restart.setAccessibilityLabel("Start a new round with ten flies")
        controller.changed = { [weak self] in
            guard let self else { return }
            self.frameReceived = ProcessInfo.processInfo.systemUptime
            self.pause.title = self.controller.running ? "Pause" : "Resume"
            self.needsDisplay = true
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    var scale: CGFloat { min(bounds.width / ArenaPainter.size.width, bounds.height / ArenaPainter.size.height) }
    var origin: CGPoint {
        CGPoint(
            x: (bounds.width - ArenaPainter.size.width * scale) / 2,
            y: (bounds.height - ArenaPainter.size.height * scale) / 2)
    }
    override func layout() {
        super.layout()
        let values: [(NSView, CGRect)] = [
            (pause, CGRect(x: 44, y: 126, width: 92, height: 28)),
            (restart, CGRect(x: 145, y: 126, width: 108, height: 28)),
            (modes, CGRect(x: 300, y: 126, width: 194, height: 28)),
            (blood, CGRect(x: 531, y: 126, width: 155, height: 28)),
        ]
        for (view, rect) in values {
            view.frame = CGRect(
                x: origin.x + rect.minX * scale, y: origin.y + rect.minY * scale,
                width: rect.width * scale, height: rect.height * scale)
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(Palette.paper.cgColor)
        ctx.fill(bounds)
        ctx.saveGState()
        ctx.translateBy(x: origin.x, y: origin.y)
        ctx.scaleBy(x: scale, y: scale)
        let reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let blend =
            controller.running && !reducedMotion
            ? min(
                1,
                (ProcessInfo.processInfo.systemUptime - frameReceived)
                    / max(0.1, controller.frame?.calculationSeconds ?? 0.1)) : 1
        let elapsed =
            controller.running && !reducedMotion ? min(0.1, ProcessInfo.processInfo.systemUptime - frameReceived) : 0
        ArenaPainter.draw(
            ctx, frame: controller.frame, mode: controller.mode, selected: controller.selected,
            blood: controller.blood, paused: !controller.running, status: controller.status,
            effectTime: (controller.frame?.arena.time ?? 0) + elapsed, previous: controller.previousFrame, blend: blend)
        ctx.restoreGState()
    }
    override func mouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        let p = CGPoint(x: (local.x - origin.x) / scale, y: (local.y - origin.y) / scale)
        if p.x >= 850, p.y >= 226, p.y < 598 {
            controller.selected = min(9, max(0, Int((p.y - 228) / 37)))
            needsDisplay = true
            return
        }
        let world = Vector(p.x - ArenaPainter.center.x, p.y - ArenaPainter.center.y)
        if event.clickCount == 2 {
            controller.dropFood(world)
            return
        }
        if let nearest = controller.frame?.arena.flies.min(by: {
            ($0.position - world).length < ($1.position - world).length
        }), (nearest.position - world).length < 28 {
            controller.selected = nearest.id
            needsDisplay = true
        }
    }
    override func keyDown(with event: NSEvent) {
        switch event.charactersIgnoringModifiers?.lowercased() {
        case " ": togglePause()
        case "r": newRound()
        case "b":
            blood.state = blood.state == .on ? .off : .on
            toggleBlood()
        default: super.keyDown(with: event)
        }
    }
    @objc func togglePause() {
        controller.running.toggle()
        pause.title = controller.running ? "Pause" : "Resume"
        needsDisplay = true
    }
    @objc func newRound() { controller.newRound() }
    @objc func selectBrainMode() { controller.setMode(modes.selectedSegment == 0 ? .simple : .full) }
    @objc func toggleBlood() {
        controller.blood = blood.state == .on
        needsDisplay = true
    }
}
