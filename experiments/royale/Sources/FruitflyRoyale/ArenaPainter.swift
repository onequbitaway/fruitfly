import AppKit
import RoyaleCore

enum Palette {
    static func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(
            red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }
    static let paper = color(0xE5EEF2), ink = color(0x193746), muted = color(0x567280)
    static let dish = color(0xC9DCE3), ring = color(0x2B7184), blood = color(0xB82440)
    static let food = color(0xEAA34B)
    static let colors: [NSColor] = [
        color(0x287C97), color(0x854A91), color(0xBE3D57), color(0x446AB0),
        color(0x5D7C3E), color(0xA56F20), color(0x32695B), color(0xA55A37), color(0x704E76), color(0x4C637D),
    ]
}

enum ArenaPainter {
    static let size = CGSize(width: 1280, height: 900)
    static let center = CGPoint(x: 425, y: 486)

    static func font(_ size: CGFloat, bold: Bool = false, condensed: Bool = false) -> NSFont {
        NSFont(
            name: condensed ? "AvenirNextCondensed-Heavy" : (bold ? "AvenirNext-DemiBold" : "AvenirNext-Regular"),
            size: size) ?? NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
    }
    static func text(
        _ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat,
        color: NSColor = Palette.ink, bold: Bool = false, condensed: Bool = false
    ) {
        (value as NSString).draw(
            at: CGPoint(x: x, y: y),
            withAttributes: [
                .font: font(size, bold: bold, condensed: condensed),
                .foregroundColor: color,
            ])
    }
    static func line(_ ctx: CGContext, _ a: CGPoint, _ b: CGPoint, color: NSColor, width: CGFloat = 1) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.move(to: a)
        ctx.addLine(to: b)
        ctx.strokePath()
    }
    static func circle(_ ctx: CGContext, _ p: CGPoint, _ r: CGFloat, _ fill: NSColor) {
        ctx.setFillColor(fill.cgColor)
        ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
    }
    static func point(_ v: Vector) -> CGPoint { CGPoint(x: center.x + v.x, y: center.y + v.y) }

    static func draw(
        _ ctx: CGContext, frame: FleetFrame?, mode: FleetMode, selected: Int, blood: Bool,
        paused: Bool, status: String, effectTime: Double? = nil,
        previous: FleetFrame? = nil, blend: Double = 1
    ) {
        ctx.setFillColor(Palette.paper.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        text("Fruitfly Royale", 42, 24, 56, bold: true, condensed: true)
        text("Ten flies. One survivor.", 46, 93, 20, color: Palette.muted)
        text("\(mode.cellsPerFly.formatted()) cells in each fly", 864, 41, 18, bold: true)
        text("Independent brains. Shared arena.", 864, 70, 16, color: Palette.muted)
        line(ctx, CGPoint(x: 42, y: 166), CGPoint(x: 1238, y: 166), color: Palette.ring.withAlphaComponent(0.25))
        guard let frame else {
            text(status, 180, 448, 24, bold: true)
            text("The full map needs more memory and time.", 180, 488, 16, color: Palette.muted)
            return
        }
        let arena = frame.arena
        let time = effectTime ?? arena.time
        text("\(arena.living) left", 48, 188, 30, bold: true, condensed: true)
        text(String(format: "%02d:%02d", Int(arena.time) / 60, Int(arena.time) % 60), 743, 194, 21, bold: true)

        // A circular glass dish. The red outer area is unsafe as the ring closes.
        circle(ctx, center, 306, .white.withAlphaComponent(0.65))
        circle(ctx, center, 300, Palette.ring.withAlphaComponent(0.16))
        circle(ctx, center, 295, Palette.dish)
        circle(ctx, center, 290, Palette.blood.withAlphaComponent(arena.time > 8 ? 0.12 : 0.03))
        circle(ctx, center, arena.radius, Palette.dish)
        ctx.saveGState()
        ctx.addEllipse(in: CGRect(x: center.x - 290, y: center.y - 290, width: 580, height: 580))
        ctx.clip()
        // Grid marks convey distance within the dish.
        for d in stride(from: -280.0, through: 280.0, by: 40) {
            line(
                ctx, CGPoint(x: center.x + d, y: center.y - 290), CGPoint(x: center.x + d, y: center.y + 290),
                color: Palette.ring.withAlphaComponent(0.065))
            line(
                ctx, CGPoint(x: center.x - 290, y: center.y + d), CGPoint(x: center.x + 290, y: center.y + d),
                color: Palette.ring.withAlphaComponent(0.065))
        }
        if blood { drawBlood(ctx, hits: arena.hits, time: time) }
        for fly in arena.flies where !fly.alive {
            ctx.saveGState()
            ctx.setAlpha(0.42)
            FlyPainter.draw(
                in: ctx, at: point(fly.position), heading: fly.heading + .pi, time: 0, scale: 1.05, flying: false)
            ctx.restoreGState()
        }
        for food in arena.food {
            FlyPainter.crumb(in: ctx, at: point(food.position), amount: food.amount, age: 2)
        }
        for fly in arena.flies where fly.alive {
            let old = previous?.arena.flies[fly.id].position ?? fly.position
            let p = point(old + (fly.position - old) * blend)
            let color = Palette.colors[fly.id]
            if fly.id == selected {
                ctx.setStrokeColor(color.withAlphaComponent(0.8).cgColor)
                ctx.setLineWidth(1.5)
                ctx.strokeEllipse(in: CGRect(x: p.x - 26, y: p.y - 26, width: 52, height: 52))
            }
            circle(ctx, CGPoint(x: p.x, y: p.y + 16), 12, color.withAlphaComponent(0.12))
            FlyPainter.draw(
                in: ctx, at: p, heading: fly.heading, time: paused ? arena.time : time,
                scale: 1.35, flying: arena.time > 3 && !arena.complete)
            ctx.setFillColor(Palette.ink.withAlphaComponent(0.15).cgColor)
            ctx.fill(CGRect(x: p.x - 16, y: p.y - 29, width: 32, height: 3))
            ctx.setFillColor(color.cgColor)
            ctx.fill(CGRect(x: p.x - 16, y: p.y - 29, width: 32 * fly.health / 100, height: 3))
            text("\(fly.id + 1)", p.x + 17, p.y - 8, 11, color: color, bold: true)
        }
        ctx.restoreGState()
        ctx.setStrokeColor((arena.time > 8 ? Palette.blood : Palette.ring).withAlphaComponent(0.85).cgColor)
        ctx.setLineWidth(2)
        ctx.strokeEllipse(
            in: CGRect(
                x: center.x - arena.radius, y: center.y - arena.radius,
                width: arena.radius * 2, height: arena.radius * 2))
        if arena.time < 3 {
            text("\(max(1, Int(ceil(3 - arena.time))))", 399, 426, 74, bold: true, condensed: true)
            text("Get ready", 382, 510, 18, bold: true)
        } else if let winner = arena.winner {
            ctx.setFillColor(Palette.paper.withAlphaComponent(0.94).cgColor)
            ctx.fill(CGRect(x: 248, y: 434, width: 354, height: 102))
            text(
                "\(arena.flies[winner].name) wins", 282, 440, 48, color: Palette.colors[winner], bold: true,
                condensed: true)
            text("Last fly in the ring", 330, 502, 16, color: Palette.muted)
        } else if paused {
            text("Paused", 360, 451, 42, bold: true, condensed: true)
        }
        text(
            arena.time < 8 ? "The ring closes after 8 seconds." : "Stay inside the ring.", 281, 802, 16,
            color: arena.time < 8 ? Palette.muted : Palette.blood, bold: true)
        text("Double-click the dish to drop food. Click a fly to follow it.", 46, 842, 15, color: Palette.muted)

        // A fixed roster lets users follow one fly through a crowded fight.
        text("The flies", 864, 187, 24, bold: true, condensed: true)
        text("Health", 1045, 196, 12, color: Palette.muted)
        text("Active cells", 1140, 196, 12, color: Palette.muted)
        for fly in arena.flies {
            let y = 228.0 + Double(fly.id) * 37
            let color = Palette.colors[fly.id]
            if fly.id == selected {
                ctx.setFillColor(NSColor.white.withAlphaComponent(0.65).cgColor)
                ctx.fill(CGRect(x: 852, y: y - 2, width: 387, height: 34))
            }
            circle(ctx, CGPoint(x: 875, y: y + 13), 10, fly.alive ? color : Palette.muted.withAlphaComponent(0.3))
            text("\(fly.id + 1)", fly.id == 9 ? 868 : 871, y + 4, 11, color: .white, bold: true)
            text(fly.name, 898, y + 1, 18, color: fly.alive ? Palette.ink : Palette.muted, bold: fly.id == selected)
            if fly.alive {
                ctx.setFillColor(Palette.ink.withAlphaComponent(0.09).cgColor)
                ctx.fill(CGRect(x: 1028, y: y + 11, width: 70, height: 5))
                ctx.setFillColor(color.cgColor)
                ctx.fill(CGRect(x: 1028, y: y + 11, width: 70 * fly.health / 100, height: 5))
                text(frame.activity[fly.id].activeCells.formatted(), 1143, y + 4, 14, color: color, bold: true)
            } else {
                text("Out", 1051, y + 4, 13, color: Palette.muted)
                text("Stopped", 1143, y + 4, 12, color: Palette.muted)
            }
        }
        line(ctx, CGPoint(x: 864, y: 610), CGPoint(x: 1238, y: 610), color: Palette.ring.withAlphaComponent(0.2))
        let fly = arena.flies[selected]
        let activity = frame.activity[selected]
        text("\(fly.name)’s brain", 864, 625, 23, bold: true, condensed: true)
        text(fly.alive ? "Calculated spikes" : "Last sample before knockout", 864, 658, 13, color: Palette.muted)
        for point in frame.points[selected] {
            let p = CGPoint(x: 1064 + point.x * 164, y: 631 + point.y * 118)
            circle(
                ctx, p, point.rate > 0 ? 1.25 : 0.8,
                point.rate > 0
                    ? Palette.colors[selected].withAlphaComponent(min(1, 0.25 + CGFloat(point.rate) / 120))
                    : Palette.ring.withAlphaComponent(0.1))
        }
        text(String(format: "%.1f Hz mean", activity.meanHz), 864, 691, 17, bold: true)
        text("\(fly.kills) knockouts", 864, 721, 15, color: Palette.muted)
        let speed = min(1, 0.1 / max(0.1, frame.calculationSeconds))
        text(String(format: "Model pace: %.2f×", speed), 864, 770, 14, color: Palette.muted)
        text("Brain wiring: MaleCNS. Combat: game rules.", 864, 795, 12, color: Palette.muted)
        if status.hasPrefix("Calculation stopped") {
            text("Calculation stopped. Start a new round.", 864, 837, 15, color: Palette.blood, bold: true)
        } else if let event = arena.events.last {
            text(event.text, 864, 837, 16, color: Palette.ink, bold: true)
        }
    }

    static func drawBlood(_ ctx: CGContext, hits: [Hit], time: Double) {
        for hit in hits {
            let age = max(0, time - hit.time)
            guard age < 4 else { continue }
            let base = point(hit.position)
            let count = hit.fatal ? 32 : 13
            for index in 0..<count {
                // Effect randomness is a pure function of the hit ID. It never
                // consumes the game or brain seeds, even when blood is disabled.
                let noise = sin(Double(hit.id * 317 + index * 91)) * 43758.5453
                let unit = noise - floor(noise)
                let angle = hit.direction.angle + (unit - 0.5) * (hit.fatal ? 6.28 : 3.8)
                let speed = (hit.fatal ? 65.0 : 40.0) * (0.3 + unit)
                let travel = speed * min(age, 0.65) * exp(-min(age, 0.65) * 1.3)
                let p = CGPoint(x: base.x + cos(angle) * travel, y: base.y + sin(angle) * travel + min(age, 0.7) * 4)
                let alpha = CGFloat(min(1, (4 - age) / 2))
                circle(ctx, p, (hit.fatal ? 2.3 : 1.5) * (0.5 + unit), Palette.blood.withAlphaComponent(alpha * 0.8))
            }
        }
    }
}
