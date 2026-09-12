import Foundation

/// A read-only copy of a completed model step. No animation values are added.
public struct ActivityReading {
    public let step: UInt64
    public let time: Double
    public let rates: [Float]
    public let inputLeft: Double
    public let inputRight: Double
    public let outputLeft: Double
    public let outputRight: Double
    public let groupMeans: [Double]
    public let activeCells: Int
    public var foodInput: Double { (inputLeft + inputRight) / 2 }
    public var output: Double { (outputLeft + outputRight) / 2 }

    public init(circuit: SmellCircuit) {
        step = circuit.stepCount; time = circuit.elapsedTime
        rates = circuit.rates
        inputLeft = circuit.inputLeft; inputRight = circuit.inputRight
        outputLeft = circuit.left; outputRight = circuit.right
        var totals = [Double](repeating: 0, count: 3)
        var counts = [Int](repeating: 0, count: 3)
        var active = 0
        for i in rates.indices {
            let kind = circuit.data.kinds[i]
            totals[kind] += Double(rates[i]); counts[kind] += 1
            if rates[i] > 0.01 { active += 1 }
        }
        groupMeans = totals.indices.map { totals[$0] / Double(max(1, counts[$0])) }
        activeCells = active
    }
}

public struct ActivityPoint: Codable {
    public let step: UInt64
    public let time: Double
    public let foodInput: Double
    public let output: Double
}

/// Values saved alongside each frame so the public recording can be checked.
public struct ActivityFrame: Codable, Equatable {
    public let step: UInt64
    public let time: Double
    public let inputLeft: Double
    public let inputRight: Double
    public let outputLeft: Double
    public let outputRight: Double
    public let activeCells: Int
    public let position: [Double]
    public let heading: Double
    public let state: String
    public let eaten: Int
    public let food: [[Double]]

    public init(reading: ActivityReading, world: FlyWorld) {
        step = reading.step; time = reading.time
        inputLeft = reading.inputLeft; inputRight = reading.inputRight
        outputLeft = reading.outputLeft; outputRight = reading.outputRight
        activeCells = reading.activeCells
        position = [world.position.x, world.position.y]; heading = world.heading
        state = world.state.rawValue; eaten = world.eaten
        food = world.food.map { [$0.position.x, $0.position.y, $0.amount, $0.age] }
    }
}

/// Keeps model samples. Repainting a paused view cannot add a sample.
public final class ActivityHistory {
    public private(set) var points: [ActivityPoint] = []
    public let duration: Double
    public init(duration: Double = 10) { self.duration = duration }

    public func append(_ reading: ActivityReading) {
        if let last = points.last {
            if reading.step < last.step { points.removeAll() }
            else if reading.step == last.step { return }
        }
        points.append(ActivityPoint(step: reading.step, time: reading.time,
                                    foodInput: reading.foodInput, output: reading.output))
        points.removeAll { $0.time < reading.time - duration }
    }
}

/// A schematic arrangement, not anatomical coordinates. One position per source cell.
/// Side, class, and source order set the positions; the layout never changes with time.
public struct ActivityLayout {
    public let positions: [Point]
    public let connections: [Int]

    public init(data: CircuitData, connectionLimit: Int = 600) {
        var result = [Point](repeating: Point(0, 0), count: data.ids.count)
        for kind in 0...2 {
            for side in -1...1 {
                let cells = data.ids.indices.filter { data.kinds[$0] == kind && data.sides[$0] == side }
                let center: Point, radius: Point
                switch kind {
                case 0:
                    center = Point(0.5 + Double(side) * 0.28, side == 0 ? 0.84 : 0.77)
                    radius = side == 0 ? Point(0.073, 0.1) : Point(0.19, 0.16)
                case 2:
                    center = Point(0.5 + Double(side) * 0.15, 0.41)
                    radius = side == 0 ? Point(0.016, 0.024) : Point(0.125, 0.10)
                default:
                    center = Point(0.5 + Double(side) * 0.25, 0.115)
                    radius = side == 0 ? Point(0.035, 0.06) : Point(0.155, 0.105)
                }
                for (order, index) in cells.enumerated() {
                    let theta = Double(order) * .pi * (3 - sqrt(5))
                    let distance = sqrt((Double(order) + 0.5) / Double(cells.count))
                    result[index] = center + Point(cos(theta) * radius.x, sin(theta) * radius.y) * distance
                }
            }
        }
        positions = result
        // Show the strongest cross-class edges. Keep the original edge index.
        let ranked = data.from.indices.filter { data.kinds[data.from[$0]] != data.kinds[data.to[$0]] }
            .sorted { data.counts[$0] == data.counts[$1] ? $0 < $1 : data.counts[$0] > data.counts[$1] }
        connections = Array(ranked.prefix(max(0, connectionLimit)))
    }
}

/// A fixed example for the public recording. Only the food event is scheduled.
/// All subsequent movement and cell values come from the same app model.
public final class ActivityDemo {
    public static let fps = 20
    public static let frames = 240
    public static let foodFrame = 30
    public static let seed: UInt64 = 7
    public let world: FlyWorld
    public let history = ActivityHistory()
    public private(set) var frame = 0

    public init(data: CircuitData) throws {
        let circuit = try SmellCircuit(data: data)
        world = FlyWorld(areas: [Area(x: 0, y: 0, width: 280, height: 350)],
                         seed: Self.seed, circuit: circuit)
        history.append(ActivityReading(circuit: circuit))
    }

    @discardableResult
    public func advance() -> ActivityReading {
        if frame == Self.foodFrame {
            // The event records the same public dropFood call used by the app.
            let point = world.areas[0].clamp(world.position + Point(-110, -65), inset: 35)
            world.dropFood(at: point)
        }
        world.step(dt: 1.0 / Double(Self.fps))
        frame += 1
        let reading = ActivityReading(circuit: world.circuit!)
        history.append(reading)
        return reading
    }
}
