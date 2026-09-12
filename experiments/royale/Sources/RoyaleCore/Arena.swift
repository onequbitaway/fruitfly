import Foundation

public struct Vector: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
    public static let zero = Vector(0, 0)
    public static func + (a: Self, b: Self) -> Self { Self(a.x + b.x, a.y + b.y) }
    public static func - (a: Self, b: Self) -> Self { Self(a.x - b.x, a.y - b.y) }
    public static func * (a: Self, b: Double) -> Self { Self(a.x * b, a.y * b) }
    public var length: Double { hypot(x, y) }
    public var angle: Double { atan2(y, x) }
    public var unit: Self { length > 0.0001 ? self * (1 / length) : Self(1, 0) }
}

struct Random {
    var state: UInt64
    mutating func next() -> Double {
        state &+= 0x9e37_79b9_7f4a_7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        return Double(z ^ (z >> 31)) / Double(UInt64.max)
    }
}

public struct Fighter: Codable, Sendable {
    public let id: Int
    public let name: String
    public var position: Vector
    public var heading: Double
    public var health: Double = 100
    public var kills: Int = 0
    public var hitAt: Double = -10
    public var diedAt: Double?
    public var cooldown: Double = 0
    public var alive: Bool { diedAt == nil }
}
public struct Food: Codable, Sendable {
    public let id: Int
    public var position: Vector
    public var amount: Double = 1
}
public struct Hit: Codable, Sendable {
    public let id: Int
    public let time: Double
    public let position: Vector
    public let direction: Vector
    public let fatal: Bool
}
public struct ArenaEvent: Codable, Sendable {
    public let time: Double
    public let text: String
}

/// Inputs to the game controller. Values must come from a calculated brain sample.
public struct NeuralReading: Sendable {
    public var turn: Double
    public var activity: Double
    public init(turn: Double = 0, activity: Double = 0) {
        self.turn = turn.isFinite ? min(1, max(-1, turn)) : 0
        self.activity = activity.isFinite ? min(1, max(0, activity)) : 0
    }
}

/// All combat, movement, health, and ring rules are fictional game rules.
public struct Arena {
    public static let names = ["Pip", "Gnat", "Ruby", "Zip", "Midge", "Buzz", "Dot", "Fuzz", "Fig", "Moth"]
    public private(set) var flies: [Fighter]
    public private(set) var food: [Food] = []
    public private(set) var hits: [Hit] = []
    public private(set) var events: [ArenaEvent] = []
    public private(set) var time: Double = 0
    public private(set) var winner: Int?
    public let seed: UInt64
    private var random: Random
    private var nextFood = 0
    private var nextHit = 0
    public var living: Int { flies.filter(\.alive).count }
    public var radius: Double { max(0, 290 - max(0, time - 8) * 4.4) }
    public var complete: Bool { winner != nil }

    public init(seed: UInt64 = 42) {
        self.seed = seed
        random = Random(state: seed)
        flies = (0..<10).map { id in
            let angle = Double(id) * .pi * 2 / 10 + .pi / 2
            return Fighter(
                id: id, name: Self.names[id],
                position: Vector(cos(angle), sin(angle)) * 246,
                heading: angle + .pi, cooldown: Double(id) * 0.027)
        }
        for point in [Vector(-130, -100), Vector(130, -100), Vector(-130, 100), Vector(130, 100)] {
            dropFood(at: point)
        }
    }

    @discardableResult
    public mutating func dropFood(at point: Vector) -> Bool {
        guard !complete, point.x.isFinite, point.y.isFinite, point.length < max(14, radius - 8),
            point.length < 286
        else { return false }
        nextFood += 1
        if food.count == 8 { food.removeFirst() }
        food.append(Food(id: nextFood, position: point))
        return true
    }

    public func scent(for id: Int) -> (left: Float, right: Float, contact: Bool) {
        let fly = flies[id]
        guard fly.alive,
            let target = food.min(by: {
                ($0.position - fly.position).length < ($1.position - fly.position).length
            })
        else { return (0, 0, false) }
        let delta = target.position - fly.position
        let value = 120 * exp(-delta.length / 240)
        let side = sin(delta.angle - fly.heading)
        return (Float(value * (0.75 + side * 0.25)), Float(value * (0.75 - side * 0.25)), delta.length < 16)
    }

    public mutating func step(_ readings: [NeuralReading], dt: Double = 0.1) {
        guard !complete, readings.count == 10, dt.isFinite, dt > 0, dt <= 0.1 else { return }
        time += dt
        hits.removeAll { time - $0.time > 4 }
        // A round starts with all ten flies visibly in a ring.
        guard time > 3 else { return }
        let previous = flies
        for i in flies.indices where flies[i].alive {
            let f = previous[i]
            let rival = previous.filter { $0.alive && $0.id != i }.min {
                ($0.position - f.position).length < ($1.position - f.position).length
            }
            let crumb = food.min { ($0.position - f.position).length < ($1.position - f.position).length }
            var target = rival?.position ?? .zero
            if let crumb, (crumb.position - f.position).length < 140 || time < 8 || f.health < 60 {
                target = crumb.position
            }
            if f.position.length > max(20, radius - 18) { target = .zero }
            let offset = target - f.position
            let orbit = sin(time * 2.1 + Double(i) * 2.4) * 0.2
            let desired = offset.angle + orbit + readings[i].turn * 0.45
            let difference = atan2(sin(desired - f.heading), cos(desired - f.heading))
            flies[i].heading += difference * min(1, dt * 7)
            let speed = 70 + readings[i].activity * 35 + Double(i % 3) * 4
            var movement = Vector(cos(flies[i].heading), sin(flies[i].heading)) * min(offset.length, speed * dt)
            for other in previous where other.alive && other.id != i {
                let away = f.position - other.position
                if away.length < 28 { movement = movement + away.unit * ((28 - away.length) * dt * 8) }
            }
            flies[i].position = f.position + movement
            if flies[i].position.length > 291 { flies[i].position = flies[i].position.unit * 291 }
            flies[i].cooldown -= dt
        }
        // Seeded order avoids giving fly zero the first attack on every step.
        let order = flies.indices.sorted { a, b in
            ((a + Int(time * 10)) % 10) < ((b + Int(time * 10)) % 10)
        }
        for i in order where flies[i].alive && living > 1 {
            if flies[i].position.length > radius {
                damage(i, amount: dt * 24, attacker: nil, direction: flies[i].position.unit * -1)
            }
            guard flies[i].alive, living > 1, flies[i].cooldown <= 0 else { continue }
            guard
                let victim = flies.filter({ $0.alive && $0.id != i }).min(by: {
                    ($0.position - flies[i].position).length < ($1.position - flies[i].position).length
                }), (victim.position - flies[i].position).length < 36
            else { continue }
            let strike = 10 + random.next() * 9
            flies[i].cooldown = 0.65 + random.next() * 0.4
            damage(
                victim.id, amount: strike, attacker: i,
                direction: (victim.position - flies[i].position).unit)
        }
        for j in food.indices {
            for i in flies.indices where flies[i].alive && food[j].amount > 0 {
                if (flies[i].position - food[j].position).length < 16 {
                    let portion = min(food[j].amount, dt * 0.12)
                    food[j].amount -= portion
                    flies[i].health = min(100, flies[i].health + portion * 36)
                }
            }
        }
        food.removeAll { $0.amount <= 0 }
        if living == 1, let last = flies.first(where: \.alive) {
            winner = last.id
            events.append(ArenaEvent(time: time, text: "\(last.name) wins the round."))
        }
        if events.count > 20 { events.removeFirst(events.count - 20) }
    }

    private mutating func damage(_ victim: Int, amount: Double, attacker: Int?, direction: Vector) {
        guard flies[victim].alive else { return }
        flies[victim].health = max(0, flies[victim].health - amount)
        if attacker != nil {
            flies[victim].position = flies[victim].position + direction * 12
            if flies[victim].position.length > 291 { flies[victim].position = flies[victim].position.unit * 291 }
        }
        let fatal = flies[victim].health <= 0
        // Ring damage emits at most one burst per half-second per fly.
        if attacker != nil || fatal || time - flies[victim].hitAt > 0.5 {
            flies[victim].hitAt = time
            nextHit += 1
            hits.append(
                Hit(id: nextHit, time: time, position: flies[victim].position, direction: direction, fatal: fatal))
        }
        if fatal {
            flies[victim].diedAt = time
            if let attacker {
                flies[attacker].kills += 1
                events.append(
                    ArenaEvent(time: time, text: "\(flies[attacker].name) knocked out \(flies[victim].name)."))
            } else {
                events.append(ArenaEvent(time: time, text: "The ring caught \(flies[victim].name)."))
            }
        }
    }
}
