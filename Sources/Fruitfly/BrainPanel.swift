import AppKit
import FlyCore

final class BrainPanel: NSPanel, NSWindowDelegate {
    let activityView: BrainActivityView
    var onClose: (() -> Void)?

    init(circuit: SmellCircuit) {
        activityView = BrainActivityView(circuit: circuit)
        super.init(contentRect: NSRect(x: 0, y: 0, width: 650, height: 600),
                   styleMask: [.titled, .closable, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
        title = "Fruitfly · Brain activity"
        contentView = activityView
        minSize = NSSize(width: 560, height: 560)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        delegate = self
        if let screen = NSScreen.main {
            setFrameTopLeftPoint(NSPoint(x: screen.visibleFrame.maxX - 680, y: screen.visibleFrame.maxY - 50))
        }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        orderOut(nil); onClose?(); return false
    }
}

final class BrainActivityView: NSView {
    private let circuit: SmellCircuit
    private let cellLayout: ActivityLayout
    private let history = ActivityHistory()
    private let cellCache = ActivityCellCache()
    private(set) var reading: ActivityReading
    private var paused = false
    private let foodButton = NSButton(title: "Drop food nearby", target: nil, action: nil)
    private let pauseButton = NSButton(title: "Pause", target: nil, action: nil)
    var onFood: (() -> Void)?
    var onPause: (() -> Void)?
    override var isOpaque: Bool { true }

    init(circuit: SmellCircuit) {
        self.circuit = circuit
        cellLayout = ActivityLayout(data: circuit.data)
        reading = ActivityReading(circuit: circuit)
        super.init(frame: NSRect(x: 0, y: 0, width: 650, height: 600))
        history.append(reading)
        appearance = NSAppearance(named: .darkAqua)
        for button in [foodButton, pauseButton] {
            button.bezelStyle = .rounded; button.target = self
            addSubview(button)
        }
        foodButton.action = #selector(dropFood)
        pauseButton.action = #selector(togglePause)
        setAccessibilityLabel("Live activity from the Fruitfly smell circuit")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func layout() {
        super.layout()
        foodButton.frame = NSRect(x: 20, y: 10, width: 150, height: 28)
        pauseButton.frame = NSRect(x: 182, y: 10, width: 90, height: 28)
    }
    func refresh(paused: Bool) {
        guard reading.step != circuit.stepCount || self.paused != paused else { return }
        self.paused = paused
        reading = ActivityReading(circuit: circuit)
        history.append(reading)
        pauseButton.title = paused ? "Resume" : "Pause"
        setAccessibilityValue(String(format: "Food input %.2f. Circuit output %.2f. %d cells above 0.01. %@",
                                     reading.foodInput, reading.output, reading.activeCells, paused ? "Paused." : "Live model."))
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(ActivityPainter.background.cgColor); ctx.fill(bounds)
        ActivityPainter.draw(in: ctx, rect: CGRect(x: 0, y: 46, width: bounds.width, height: bounds.height - 46),
                             data: circuit.data, layout: cellLayout, reading: reading, history: history,
                             mode: paused ? "Paused model · values held" : "Live model · food changes the input", cellCache: cellCache)
    }
    @objc private func dropFood() { onFood?() }
    @objc private func togglePause() { onPause?() }
}
