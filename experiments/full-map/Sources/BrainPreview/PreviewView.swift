import AppKit
import BrainCore

final class PreviewView: NSView {
    let controller: PreviewController
    private var map: MapDrawing?
    private var lastMode: BrainMode?
    private var focus: Int?
    private var controls: [String: NSButton] = [:]
    private let modes = NSSegmentedControl(
        labels: ["Simple", "Full map"], trackingMode: .selectOne, target: nil, action: nil)
    var recorded = false
    var arena: CGRect { CGRect(x: 24, y: bounds.height - 405, width: 248, height: 220) }
    var rightX: CGFloat { bounds.width - 262 }
    var mapRect: CGRect { CGRect(x: 294, y: 305, width: rightX - 312, height: bounds.height - 412) }
    init(controller: PreviewController) {
        self.controller = controller
        super.init(frame: NSRect(x: 0, y: 0, width: 1260, height: 820))
        appearance = NSAppearance(named: .darkAqua)
        modes.target = self
        modes.action = #selector(selectBrainMode)
        modes.selectedSegment = 1
        addSubview(modes)
        for title in ["Drop food", "Pause", "Reset", "Clear food", "Smell", "Taste", "Visual", "Feeding"] {
            let b = NSButton(title: title, target: self, action: #selector(action(_:)))
            b.bezelStyle = .rounded
            b.font = .systemFont(ofSize: 12)
            b.identifier = NSUserInterfaceItemIdentifier(title)
            if title == "Drop food" { b.bezelColor = Ink.groups[0] }
            addSubview(b)
            controls[title] = b
        }
        let block = NSButton(checkboxWithTitle: "Block MN9 feeding cells", target: self, action: #selector(action(_:)))
        block.font = .systemFont(ofSize: 12)
        block.identifier = NSUserInterfaceItemIdentifier("Block")
        addSubview(block)
        controls["Block"] = block
        controller.onChange = { [weak self] in self?.refresh() }
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        let top = bounds.height
        modes.frame = NSRect(x: 24, y: top - 148, width: 248, height: 30)
        let names = [["Drop food", "Pause"], ["Reset", "Clear food"], ["Smell", "Taste"], ["Visual", "Feeding"]]
        let ys: [CGFloat] = [top - 481, top - 519, top - 608, top - 646]
        for row in names.indices {
            for col in 0..<2 {
                controls[names[row][col]]?.frame = NSRect(
                    x: 22 + CGFloat(col) * 128, y: ys[row], width: 124, height: 32)
            }
        }
        controls["Block"]?.frame = NSRect(x: 24, y: top - 687, width: 251, height: 24)
    }
    func refresh() {
        if let metadata = controller.metadata, map == nil || lastMode != controller.mode {
            map = MapDrawing(metadata: metadata)
            lastMode = controller.mode
            focus = nil
        }
        if controller.loading { map = nil }
        modes.selectedSegment = controller.mode == .full ? 1 : 0
        modes.isEnabled = !controller.loading
        for (name, b) in controls {
            b.isEnabled = !controller.loading && controller.error == nil
            if ["Taste", "Visual", "Feeding", "Block"].contains(name) && controller.mode == .simple {
                b.isEnabled = false
            }
        }
        controls["Pause"]?.title = controller.paused ? "Resume" : "Pause"
        controls["Block"]?.state = controller.blockFeeding ? .on : .off
        needsDisplay = true
    }
    @objc private func selectBrainMode() {
        guard !recorded else { return }
        controller.load(modes.selectedSegment == 0 ? .simple : .full)
    }
    @objc private func action(_ button: NSButton) {
        guard !recorded else { return }
        switch button.identifier?.rawValue {
        case "Drop food": controller.dropFood()
        case "Pause": controller.pause()
        case "Reset": controller.reset()
        case "Clear food": controller.clearFood()
        case "Block": controller.block()
        case let name?: controller.test(name)
        default: break
        }
    }
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if arena.contains(point) && event.clickCount == 2 {
            controller.dropFood(x: Double((point.x - arena.minX) * 270 / arena.width), y: Double(point.y - arena.minY))
        }
        if point.x >= rightX && point.y < bounds.height - 147 && point.y > bounds.height - 147 - 9 * 39 {
            let group = Int((bounds.height - 147 - point.y) / 39)
            focus = focus == group ? nil : group
            needsDisplay = true
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(Ink.background.cgColor)
        ctx.fill(bounds)
        let h = bounds.height
        Ink.label("fruitfly", 24, h - 56, 28, Ink.text, .semibold)
        Ink.label("/  inside the map", 145, h - 53, 21, Ink.muted, .light)
        Ink.label(
            recorded ? "RECORDED MODEL RUN" : "LOCAL PREVIEW", bounds.width - 195, h - 44, 10, Ink.groups[0], .semibold)
        Ink.label("MaleCNS · experimental model", bounds.width - 218, h - 65, 10, Ink.muted)
        Ink.line(ctx, CGPoint(x: 24, y: h - 88), CGPoint(x: bounds.width - 24, y: h - 88))
        Ink.line(ctx, CGPoint(x: 285, y: 100), CGPoint(x: 285, y: h - 108))
        Ink.line(ctx, CGPoint(x: rightX - 14, y: 100), CGPoint(x: rightX - 14, y: h - 108))
        Ink.label(
            controller.mode == .full ? "166,700 cells · full mapped network" : "3,745 cells · smell network", 24,
            h - 172, 11, Ink.muted)
        drawTrial(ctx)
        Ink.label(controller.trial.phase, 24, h - 432, 12, Ink.text, .medium)
        Ink.label("Food left: \(Int(max(0,controller.trial.foodAmount)*100))%", 24, h - 450, 10, Ink.muted)
        Ink.label("TEST ONE INPUT", 24, h - 556, 10, Ink.muted, .semibold)
        Ink.label("Two seconds of direct stimulation", 24, h - 573, 10, Ink.muted)
        Ink.label("Approach follows a pet rule.", 24, 106, 10, Ink.muted)
        if let snapshot = controller.snapshot, let map, let metadata = controller.metadata {
            let running = controller.paused ? "Paused" : (recorded ? "Model time" : "Running")
            Ink.label("\(running) · \(String(format:"%.1f",snapshot.time)) s", 310, h - 124, 13, Ink.text, .medium)
            Ink.label("\(snapshot.activeCells.formatted()) cells fired in the last 0.1 s", 310, h - 145, 11, Ink.muted)
            Ink.label(
                focus.map { "Showing: \(metadata.groupNames[$0])" } ?? "All cell classes", rightX - 182, h - 124, 10,
                Ink.muted)
            map.draw(
                ctx, rect: CGRect(x: mapRect.minX, y: mapRect.minY, width: mapRect.width, height: mapRect.height - 48),
                snapshot: snapshot, focus: focus)
            drawGroups(ctx, metadata, snapshot)
            drawTrace(ctx)
            Ink.label(controller.inputLabel, 310, 277, 12, Ink.text, .medium)
            Ink.label(
                "\(snapshot.directCells) input cells · \(controller.connections.formatted()) connections", 310, 256, 10,
                Ink.muted)
            Ink.label(
                "\(controller.processor) · \(Int(snapshot.computationSeconds*1000)) ms to calculate 100 ms", 310, 108,
                10, Ink.muted)
        } else {
            Ink.label(
                controller.error == nil ? "Loading the mapped network…" : "Could not load the model", 310, h - 155, 17,
                Ink.text, .medium)
            if let error = controller.error {
                drawWrapped(error, in: CGRect(x: 310, y: h - 280, width: 500, height: 95))
            } else {
                Ink.label("The first run prepares the graphics program.", 310, h - 180, 12, Ink.muted)
            }
        }
        Ink.line(ctx, CGPoint(x: 24, y: 85), CGPoint(x: bounds.width - 24, y: 85))
        Ink.label("Each lit point uses calculated spikes. No stage-based glow.", 24, 56, 12, Ink.text)
        Ink.label(
            "Full map includes the brain and nerve cord. It is not a validated whole-fly model. No learning or fullness model.",
            24, 33, 11, Ink.muted)
    }
    private func drawTrial(_ ctx: CGContext) {
        let r = arena
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: 9, cornerHeight: 9, transform: nil))
        ctx.clip()
        ctx.setFillColor(Ink.panel.cgColor)
        ctx.fill(r)
        ctx.setFillColor(Ink.muted.withAlphaComponent(0.16).cgColor)
        for x in stride(from: 12.0, to: Double(r.width), by: 20) {
            for y in stride(from: 12.0, to: Double(r.height), by: 20) {
                ctx.fillEllipse(in: CGRect(x: r.minX + x, y: r.minY + y, width: 1.2, height: 1.2))
            }
        }
        ctx.translateBy(x: r.minX, y: r.minY)
        ctx.scaleBy(x: r.width / 270, y: 1)
        let t = controller.trial
        if let x = t.foodX, let y = t.foodY {
            FlyPainter.crumb(in: ctx, at: CGPoint(x: x, y: y), amount: t.foodAmount, age: 1)
        }
        FlyPainter.draw(
            in: ctx, at: CGPoint(x: t.x, y: t.y), heading: t.heading, time: t.time, scale: 1.2, flying: !t.atFood,
            eating: t.phase.hasPrefix("Eating"))
        ctx.restoreGState()
        Ink.label("Double-click to drop food", r.minX + 12, r.minY + 12, 10, Ink.muted)
    }
    private func drawGroups(_ ctx: CGContext, _ metadata: BrainMetadata, _ s: BrainSnapshot) {
        Ink.label("CELLS THAT FIRED", rightX, bounds.height - 124, 10, Ink.muted, .semibold)
        Ink.label("Last 0.1 s · click a class to isolate", rightX, bounds.height - 142, 10, Ink.muted)
        var counts = [Int](repeating: 0, count: 9)
        for g in metadata.groups { counts[g] += 1 }
        for g in 0..<9 {
            let y = bounds.height - 173 - CGFloat(g) * 39
            ctx.setFillColor(Ink.groups[g].cgColor)
            ctx.fillEllipse(in: CGRect(x: rightX, y: y + 3, width: 6, height: 6))
            Ink.label(metadata.groupNames[g], rightX + 13, y, 12, Ink.groups[g], focus == g ? .bold : .regular)
            Ink.label("\(s.groupActive[g].formatted()) / \(counts[g].formatted())", rightX + 13, y - 17, 10, Ink.muted)
            Ink.label(String(format: "%.1f Hz", s.groupMeanHz[g]), rightX + 171, y - 17, 10, Ink.muted)
        }
        let y = bounds.height - 566
        Ink.line(ctx, CGPoint(x: rightX, y: y + 22), CGPoint(x: bounds.width - 24, y: y + 22))
        Ink.label("NAMED OUTPUT CELLS", rightX, y, 10, Ink.muted, .semibold)
        Ink.label("Steering · DNa02", rightX, y - 29, 12, Ink.text)
        Ink.label(
            String(format: "Left %.0f     Right %.0f Hz", s.steeringLeftHz, s.steeringRightHz), rightX, y - 49, 17,
            Ink.groups[5], .medium)
        Ink.label("Feeding · MN9", rightX, y - 83, 12, Ink.text)
        Ink.label(String(format: "%.0f Hz", s.feedingHz), rightX, y - 110, 25, Ink.groups[6], .medium)
        Ink.label(
            controller.mode == .full ? "MN9 rate controls food use." : "These cells are absent in Simple.", rightX,
            y - 130, 10, Ink.muted)
        Ink.label("Hz = spikes per second", rightX, 108, 10, Ink.muted)
    }
    private func drawTrace(_ ctx: CGContext) {
        let r = CGRect(x: 310, y: 145, width: rightX - 338, height: 80)
        Ink.label("CLASS MEAN · 0–200+ Hz", r.minX, r.maxY + 9, 9, Ink.muted)
        for i in 0...2 {
            let y = r.minY + CGFloat(i) * r.height / 2
            Ink.line(ctx, CGPoint(x: r.minX, y: y), CGPoint(x: r.maxX, y: y))
        }
        guard let last = controller.history.last else { return }
        let begin = max(0, last.time - 10)
        for g in 0..<9 where focus == nil || focus == g {
            let path = CGMutablePath()
            var first = true
            for t in controller.history {
                let p = CGPoint(
                    x: r.minX + (t.time - begin) / 10 * r.width, y: r.minY + min(200, t.means[g]) / 200 * r.height)
                if first {
                    path.move(to: p)
                    first = false
                } else {
                    path.addLine(to: p)
                }
            }
            ctx.addPath(path)
            ctx.setStrokeColor(Ink.groups[g].withAlphaComponent(0.9).cgColor)
            ctx.setLineWidth(1.2)
            ctx.strokePath()
        }
        Ink.label(String(format: "%.1f s", begin), r.minX, r.minY - 18, 9, Ink.muted)
        Ink.label("10-second window", r.maxX - 96, r.minY - 18, 9, Ink.muted)
    }
    private func drawWrapped(_ text: String, in rect: CGRect) {
        (text as NSString).draw(
            in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: Ink.muted])
    }
}
