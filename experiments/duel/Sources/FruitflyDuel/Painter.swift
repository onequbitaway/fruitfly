import AppKit
import DuelCore

enum Palette {
  static func hex(_ value: Int) -> NSColor {
    NSColor(
      red: CGFloat(value >> 16 & 255) / 255, green: CGFloat(value >> 8 & 255) / 255,
      blue: CGFloat(value & 255) / 255, alpha: 1)
  }
  static let paper = hex(0xF1FAFC), pond = hex(0xD8F0F3), ink = hex(0x164459), muted = hex(0x527680)
  static let leaf = hex(0x388768), blood = hex(0xD74443), violet = hex(0x6850B9)
  static func fly(_ id: Int) -> NSColor { id == 0 ? blood : violet }
}

enum DuelPainter {
  static let size = CGSize(width: 1280, height: 900)
  static func text(
    _ value: String, _ x: Double, _ y: Double, _ size: Double, color: NSColor = Palette.ink,
    bold: Bool = false, align: NSTextAlignment = .left, width: Double = 1200
  ) {
    let style = NSMutableParagraphStyle()
    style.alignment = align
    let font =
      NSFont(name: bold ? "AvenirNext-Heavy" : "AvenirNext-Medium", size: size)
      ?? NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    (value as NSString).draw(
      in: CGRect(x: x, y: y, width: width, height: size * 2.5),
      withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
  }
  static func line(_ ctx: CGContext, _ points: [CGPoint], color: NSColor, width: Double) {
    guard let first = points.first else { return }
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(width)
    ctx.beginPath()
    ctx.move(to: first)
    for p in points.dropFirst() { ctx.addLine(to: p) }
    ctx.strokePath()
  }
  static func ellipse(_ ctx: CGContext, _ rect: CGRect, _ color: NSColor) {
    ctx.setFillColor(color.cgColor)
    ctx.fillEllipse(in: rect)
  }
  static func draw(
    _ ctx: CGContext, frame: DuelFrame?, mode: DuelMode, blood: Bool = true, paused: Bool = false,
    status: String = "", index: Int? = nil, replay: Bool = false
  ) {
    ctx.setFillColor(Palette.paper.cgColor)
    ctx.fill(CGRect(origin: .zero, size: size))
    text("Fruitfly Duel", 38, 22, 36, bold: true)
    text("Two flies. Three lives. One winner.", 40, 72, 16, color: Palette.muted)
    if replay {
      text(
        mode.rawValue + " replay · 3× model time", 730, 37, 19, color: Palette.muted, align: .right,
        width: 510)
    }
    let stageRect = CGRect(x: 24, y: 125, width: 1232, height: 526)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: stageRect, cornerWidth: 24, cornerHeight: 24, transform: nil))
    ctx.clip()
    let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(),
      colors: [Palette.paper.cgColor, Palette.pond.cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
      gradient, start: CGPoint(x: 0, y: 150), end: CGPoint(x: 0, y: 650), options: [])
    // Pond rings and reeds stay faint behind the stage.
    for i in 0..<5 {
      ctx.setStrokeColor(Palette.ink.withAlphaComponent(0.06).cgColor)
      ctx.setLineWidth(2)
      ctx.strokeEllipse(
        in: CGRect(x: Double(i) * 290 - 70, y: 600 + Double(i % 2) * 23, width: 340, height: 40))
    }
    for side in [0.0, 1.0] {
      for i in 0..<5 {
        let x = side == 0 ? 40 + Double(i) * 16 : 1240 - Double(i) * 16
        line(
          ctx,
          [
            CGPoint(x: x, y: 670),
            CGPoint(x: x + (side == 0 ? 30 : -30), y: 460 + Double(i % 3) * 25),
          ], color: Palette.leaf.withAlphaComponent(0.15), width: 5)
      }
    }
    guard let frame else {
      text(status, 160, 340, 25, color: Palette.muted, align: .center, width: 960)
      ctx.restoreGState()
      return
    }
    let match = frame.frames[min(frame.frames.count - 1, max(0, index ?? frame.frames.count - 1))]
    let scale = 0.72
    func world(_ point: Point) -> CGPoint {
      CGPoint(x: 640 + point.x * scale, y: 534 - point.y * scale)
    }
    for p in match.stage.platforms {
      let x = 640 + (p.x - p.width / 2) * scale
      let y = 534 - (p.y + p.height / 2) * scale
      let w = p.width * scale
      let h = p.height * scale
      let leaf = CGMutablePath()
      leaf.move(to: CGPoint(x: x, y: y))
      leaf.addLine(to: CGPoint(x: x + w, y: y))
      leaf.addCurve(
        to: CGPoint(x: x, y: y), control1: CGPoint(x: x + w * 0.92, y: y + max(22, h) * 1.8),
        control2: CGPoint(x: x + w * 0.22, y: y + max(20, h) * 1.6))
      ctx.addPath(leaf)
      ctx.setFillColor(
        (p.kind == "ground" ? Palette.leaf : Palette.leaf.withAlphaComponent(0.9)).cgColor)
      ctx.fillPath()
      line(
        ctx, [CGPoint(x: x + 3, y: y + 1), CGPoint(x: x + w - 3, y: y + 1)],
        color: Palette.hex(0x79BB85), width: 5)
      line(
        ctx, [CGPoint(x: x + 12, y: y + 8), CGPoint(x: x + w - 20, y: y + 10)],
        color: Palette.paper.withAlphaComponent(0.2), width: 1.5)
      for i in 1..<6 {
        let vx = x + w * Double(i) / 6
        line(
          ctx, [CGPoint(x: vx, y: y + 8), CGPoint(x: vx + w * 0.07, y: y + max(12, h * 0.55))],
          color: Palette.paper.withAlphaComponent(0.15), width: 1)
      }
    }
    for e in frame.effects {
      let age = Double(match.frame - e.frame) / 60
      guard age >= 0, let position = e.position else { continue }
      let p = world(position)
      if e.type == "ko", age < 0.85 {
        let x = max(45, min(1235, p.x))
        let y = max(155, min(620, p.y))
        ctx.setStrokeColor(Palette.fly(e.slot ?? 0).withAlphaComponent(1 - age / 0.85).cgColor)
        ctx.setLineWidth(9 * (1 - age / 0.85))
        ctx.strokeEllipse(
          in: CGRect(
            x: x - 25 - age * 90, y: y - 25 - age * 90, width: 50 + age * 180,
            height: 50 + age * 180))
        text(
          "Ring out!", x - 90, max(155, y - 80), 24, color: Palette.fly(e.slot ?? 0), bold: true,
          align: .center, width: 180)
      }
      if ["hit", "throw", "shield-hit"].contains(e.type), age < 0.65 {
        let tint = e.type == "shield-hit" ? Palette.violet : Palette.blood
        if age < 0.18 {
          for i in 0..<8 {
            let angle = Double(i) * Double.pi / 4
            line(
              ctx,
              [
                CGPoint(x: p.x + cos(angle) * 12, y: p.y + sin(angle) * 12),
                CGPoint(
                  x: p.x + cos(angle) * (30 + age * 120), y: p.y + sin(angle) * (30 + age * 120)),
              ], color: tint.withAlphaComponent(1 - age / 0.18), width: 3)
          }
        }
        if blood && e.type != "shield-hit" {
          for i in 0..<14 {
            let angle = Double(i) * 2.399 + Double(e.frame % 17)
            let speed = 60 + Double(i % 5) * 25
            let dx = cos(angle) * speed * age
            let dy = sin(angle) * speed * age + 120 * age * age
            ellipse(
              ctx,
              CGRect(x: p.x + dx, y: p.y + dy, width: 3 + Double(i % 3), height: 3 + Double(i % 3)),
              tint.withAlphaComponent(1 - age / 0.65))
          }
        }
      }
    }
    for f in match.fighters where f.stocks > 0 && f.state != "ko" {
      let p = world(f.position)
      if !stageRect.insetBy(dx: 28, dy: 32).contains(p) {
        let q = CGPoint(x: max(60, min(1220, p.x)), y: max(164, min(610, p.y)))
        ellipse(ctx, CGRect(x: q.x - 15, y: q.y - 15, width: 30, height: 30), Palette.fly(f.slot))
        text(f.name, q.x - 35, q.y - 9, 13, color: .white, bold: true, align: .center, width: 70)
        continue
      }
      if f.grounded {
        ellipse(
          ctx, CGRect(x: p.x - 23, y: p.y + f.size.height * scale / 2 - 2, width: 46, height: 7),
          Palette.ink.withAlphaComponent(0.14))
      }
      if f.state == "shield" {
        ellipse(
          ctx, CGRect(x: p.x - 42, y: p.y - 42, width: 84, height: 84),
          Palette.fly(f.slot).withAlphaComponent(0.14))
        ctx.setStrokeColor(Palette.fly(f.slot).withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: p.x - 42, y: p.y - 42, width: 84, height: 84))
      }
      ctx.saveGState()
      if f.invulnerableFrames > 0 { ctx.setAlpha(match.frame % 8 < 4 ? 0.45 : 0.8) }
      fly(
        ctx, at: p, face: f.facing, time: Double(match.frame) / 60, air: !f.grounded,
        attack: f.currentMove != nil, hurt: f.hitstunFrames > 0, accent: Palette.fly(f.slot),
        scale: 1.0)
      ctx.restoreGState()
      text(
        f.name, p.x - 50, p.y - 69, 17, color: Palette.fly(f.slot), bold: true, align: .center,
        width: 100)
      if let move = f.currentMove, f.moveFrame < 16 {
        text(
          move.replacingOccurrences(of: "-", with: " "), p.x - 80, p.y + 36, 12,
          color: Palette.muted, align: .center, width: 160)
      }
    }
    if match.phase == "countdown" {
      text(
        "\(max(1,Int(ceil(Double(match.countdownFrames)/60))))", 500, 210, 90, bold: true,
        align: .center, width: 280)
    } else if match.complete {
      ctx.setFillColor(Palette.paper.withAlphaComponent(0.92).cgColor)
      ctx.fill(CGRect(x: 390, y: 190, width: 500, height: 115))
      text(
        "\(match.winner == 0 ? "Pip" : "Zip") wins", 390, 195, 54,
        color: Palette.fly(match.winner ?? 0), bold: true, align: .center, width: 500)
      text(
        "Start a new match to fight again.", 390, 269, 17, color: Palette.muted, align: .center,
        width: 500)
    } else if paused {
      text("Paused", 430, 205, 44, bold: true, align: .center, width: 420)
    }
    let seconds = Int(ceil((match.remainingTimeMs ?? 0) / 1000))
    text(
      match.suddenDeath ? "Sudden death" : String(format: "%d:%02d", seconds / 60, seconds % 60),
      980, 142, 24, bold: true, align: .right, width: 240)
    ctx.restoreGState()
    for i in 0..<2 {
      let f = match.fighters[i]
      let base = i == 0 ? 42.0 : 690.0
      let tint = Palette.fly(i)
      text(f.name, base, 680, 23, color: tint, bold: true)
      text("\(Int(f.percent))%", base, 709, 64, color: tint, bold: true)
      for stock in 0..<3 {
        ellipse(
          ctx, CGRect(x: base + Double(stock) * 24, y: 798, width: 14, height: 14),
          stock < f.stocks ? tint : tint.withAlphaComponent(0.16))
      }
      if frame.activity.indices.contains(i) {
        let activity = frame.activity[i]
        let brainX = base + 173
        let brainY = 688.0
        for p in activity.points {
          let active = p.rate > 0
          ellipse(
            ctx,
            CGRect(
              x: brainX + p.x * 169, y: brainY + p.y * 112, width: active ? 2.1 : 1.5,
              height: active ? 2.1 : 1.5),
            active
              ? tint.withAlphaComponent(min(1, 0.25 + Double(p.rate) / 150))
              : Palette.ink.withAlphaComponent(0.09))
        }
        text(
          "\(activity.activeCells.formatted()) active cells", base + 366, 705, 17,
          color: Palette.ink, bold: true, width: 240)
        text(
          "\(mode.cells.formatted()) cells per fly", base + 366, 737, 14, color: Palette.muted,
          width: 240)
        text(
          String(format: "Model time %.1f s", activity.time), base + 366, 762, 14,
          color: Palette.muted, width: 240)
      }
    }
    line(
      ctx, [CGPoint(x: 640, y: 690), CGPoint(x: 640, y: 813)],
      color: Palette.ink.withAlphaComponent(0.1), width: 1)
    text("Calculated brain activity. Programmed fight rules.", 40, 849, 15, color: Palette.muted)
    text(
      replay
        ? "Super Bash Folds engine · MIT"
        : (frame.calculationSeconds > 0.115 ? "Model runs below real time" : mode.rawValue)
          + " · Space: pause · R: new match", 700, 849, 14, color: Palette.muted, align: .right,
      width: 540)
    if !status.isEmpty
      && (status.contains("failed") || status.contains("Could not") || status.contains("stopped"))
    {
      text(status, 45, 108, 14, color: Palette.blood, width: 1170)
    }
  }

  static func fly(
    _ ctx: CGContext, at p: CGPoint, face: Int, time: Double, air: Bool, attack: Bool, hurt: Bool,
    accent: NSColor, scale: Double
  ) {
    ctx.saveGState()
    ctx.translateBy(x: p.x, y: p.y)
    ctx.scaleBy(x: scale * Double(face), y: scale)
    if hurt { ctx.rotate(by: sin(time * 23) * 0.5) }
    ctx.setLineCap(.round)
    // Three pairs of jointed legs. The near legs are heavier.
    for side in 0..<2 {
      for leg in 0..<3 {
        let x = Double(leg) * 8 - 9
        let reach = attack && leg == 2 ? 25.0 : 10.0
        let step = air ? -3 : sin(time * 17 + Double(leg) * 2) * 4
        line(
          ctx,
          [
            CGPoint(x: x, y: 9), CGPoint(x: x + reach - 6, y: 18 + step),
            CGPoint(x: x + reach + 4, y: 26 + step),
          ], color: Palette.ink.withAlphaComponent(side == 0 ? 0.4 : 0.9),
          width: side == 0 ? 1 : 1.7)
      }
    }
    ellipse(ctx, CGRect(x: -28, y: -5, width: 35, height: 24), Palette.hex(0x785C3A))
    for x in [-19.0, -11, -3] {
      line(
        ctx, [CGPoint(x: x, y: -3), CGPoint(x: x + 3, y: 16)], color: Palette.hex(0x493926),
        width: 2)
    }
    ellipse(ctx, CGRect(x: -9, y: -12, width: 28, height: 30), Palette.ink)
    for wing in 0..<2 {
      let wingPath = CGMutablePath()
      let flap = air ? sin(time * 137 + Double(wing)) * 10 : sin(time * 30) * 3
      wingPath.move(to: CGPoint(x: 2, y: -4))
      wingPath.addCurve(
        to: CGPoint(x: -38 + Double(wing) * 14, y: -37 - flap - Double(wing) * 7),
        control1: CGPoint(x: -2, y: -38), control2: CGPoint(x: -43, y: -59 - flap))
      wingPath.addCurve(
        to: CGPoint(x: 2, y: -4), control1: CGPoint(x: -49, y: -17),
        control2: CGPoint(x: -14, y: -3))
      ctx.addPath(wingPath)
      ctx.setFillColor(NSColor.white.withAlphaComponent(0.74).cgColor)
      ctx.setStrokeColor(Palette.muted.withAlphaComponent(0.55).cgColor)
      ctx.setLineWidth(1)
      ctx.drawPath(using: .fillStroke)
      line(
        ctx, [CGPoint(x: 0, y: -6), CGPoint(x: -31 + Double(wing) * 10, y: -33 - flap)],
        color: Palette.muted.withAlphaComponent(0.35), width: 0.7)
    }
    ellipse(ctx, CGRect(x: 11, y: -14, width: 22, height: 23), Palette.hex(0x283B3F))
    ellipse(ctx, CGRect(x: 21, y: -12, width: 16, height: 19), accent)
    ellipse(ctx, CGRect(x: 25, y: -9, width: 5, height: 5), NSColor.white.withAlphaComponent(0.58))
    line(
      ctx, [CGPoint(x: 29, y: -12), CGPoint(x: 36, y: -22), CGPoint(x: 39, y: -21)],
      color: Palette.ink, width: 1.2)
    line(ctx, [CGPoint(x: 32, y: 5), CGPoint(x: 39, y: 9)], color: Palette.ink, width: 1.5)
    if attack {
      line(
        ctx, [CGPoint(x: 37, y: 15), CGPoint(x: 49, y: 9), CGPoint(x: 53, y: -1)],
        color: accent.withAlphaComponent(0.7), width: 3)
    }
    ctx.restoreGState()
  }
}
