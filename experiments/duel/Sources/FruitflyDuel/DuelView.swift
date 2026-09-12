import AppKit
import DuelCore

final class DuelView: NSView {
  let controller: DuelController
  private let pause = NSButton(title: "Pause", target: nil, action: nil)
  private let restart = NSButton(title: "New match", target: nil, action: nil)
  private let modes = NSSegmentedControl(
    labels: ["Simple", "Full map"], trackingMode: .selectOne, target: nil, action: nil)
  private let blood = NSButton(checkboxWithTitle: "Blood effects", target: nil, action: nil)
  private var timer: Timer?
  private var received = ProcessInfo.processInfo.systemUptime
  override var isFlipped: Bool { true }
  override var acceptsFirstResponder: Bool { true }
  init(controller: DuelController) {
    self.controller = controller
    super.init(frame: CGRect(origin: .zero, size: DuelPainter.size))
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
    modes.setToolTip("3,745 cells per fly. Uses a smell cue for opponent direction.", forSegment: 0)
    modes.setToolTip(
      "166,700 cells per fly. Uses vision cells for opponent direction.", forSegment: 1)
    blood.state = .on
    pause.setAccessibilityLabel("Pause or resume the match")
    restart.setAccessibilityLabel("Start a new match with two flies")
    controller.changed = { [weak self] in
      guard let self else { return }
      self.received = ProcessInfo.processInfo.systemUptime
      self.pause.title = self.controller.running ? "Pause" : "Resume"
      self.needsDisplay = true
      if let frame = self.controller.frame {
        self.setAccessibilityValue(
          frame.match.fighters.map {
            "\($0.name): \(Int($0.percent)) percent damage, \($0.stocks) lives"
          }.joined(separator: ". "))
      }
    }
    timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
      self?.needsDisplay = true
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
  var scale: Double { min(bounds.width / 1280, bounds.height / 900) }
  var origin: CGPoint {
    CGPoint(x: (bounds.width - 1280 * scale) / 2, y: (bounds.height - 900 * scale) / 2)
  }
  override func layout() {
    super.layout()
    let controls: [(NSView, CGRect)] = [
      (pause, CGRect(x: 646, y: 38, width: 82, height: 30)),
      (restart, CGRect(x: 735, y: 38, width: 106, height: 30)),
      (modes, CGRect(x: 854, y: 38, width: 210, height: 30)),
      (blood, CGRect(x: 1080, y: 38, width: 160, height: 30)),
    ]
    for (view, rect) in controls {
      view.frame = CGRect(
        x: origin.x + rect.minX * scale, y: origin.y + rect.minY * scale, width: rect.width * scale,
        height: rect.height * scale)
    }
  }
  override func draw(_ dirtyRect: NSRect) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    ctx.setFillColor(Palette.paper.cgColor)
    ctx.fill(bounds)
    ctx.saveGState()
    ctx.translateBy(x: origin.x, y: origin.y)
    ctx.scaleBy(x: scale, y: scale)
    let frame = controller.frame
    // Play the six actual physics frames from the latest brain sample.
    // A slow solver holds the last frame; it never invents activity.
    let duration = max(0.1, frame?.calculationSeconds ?? 0.1)
    let elapsed = ProcessInfo.processInfo.systemUptime - received
    let index =
      controller.running && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
      ? Int(elapsed / duration * Double(frame?.frames.count ?? 1)) : nil
    DuelPainter.draw(
      ctx, frame: frame, mode: controller.mode, blood: controller.blood,
      paused: !controller.running, status: controller.status, index: index)
    ctx.restoreGState()
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
