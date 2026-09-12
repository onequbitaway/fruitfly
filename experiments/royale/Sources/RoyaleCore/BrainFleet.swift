import BrainCore
import Foundation

public enum FleetMode: String, CaseIterable, Codable {
    case simple = "Simple"
    case full = "Full map"
    public var cellsPerFly: Int { self == .simple ? 3745 : 166700 }
}

public struct BrainPoint: Sendable {
    public let x: Double
    public let y: Double
    public let rate: Float
}
public struct FlyActivity: Codable, Sendable {
    public let id: Int
    public let modelTime: Double
    public let activeCells: Int
    public let totalSpikes: UInt64
    public let meanHz: Double
    public let odorLeft: Float
    public let odorRight: Float
    public let rateHash: String
}
public struct FleetFrame {
    public let arena: Arena
    public let activity: [FlyActivity]
    public let points: [[BrainPoint]]
    public let calculationSeconds: Double
}

/// Ten separate states use the same released graph. Dead flies stop advancing.
public final class BrainFleet {
    public let mode: FleetMode
    public let models: [BrainModel]
    public private(set) var arena: Arena
    private var snapshots: [BrainSnapshot]
    private let positions: [(Int, Double, Double)]
    private var lastCost = 0.0

    public init(folder: URL, mode: FleetMode, seed: UInt64 = 42) throws {
        self.mode = mode
        arena = Arena(seed: seed)
        models = try (0..<10).map { id in
            let model = try BrainModel(folder: folder, mode: mode == .simple ? .simple : .full, useGPU: mode == .full)
            model.reset(seed: seed &+ UInt64(id) &* 104729)
            return model
        }
        snapshots = models.map { $0.snapshot() }
        // Use real cell-body positions. Skip unknown positions; draw a fixed
        // subset for legibility. Every cell still runs in every model step.
        let known = models[0].metadata.positions.enumerated().compactMap { index, p -> (Int, Double, Double)? in
            guard let p else { return nil }
            return (index, Double(p[0]), Double(p[2]))
        }
        let minX = known.map { $0.1 }.min() ?? 0
        let maxX = known.map { $0.1 }.max() ?? 1
        let minY = known.map { $0.2 }.min() ?? 0
        let maxY = known.map { $0.2 }.max() ?? 1
        let stride = max(1, known.count / 1500)
        positions = known.enumerated().filter { $0.offset % stride == 0 }.map { _, p in
            (p.0, (p.1 - minX) / max(1, maxX - minX), (p.2 - minY) / max(1, maxY - minY))
        }
    }

    @discardableResult public func dropFood(at point: Vector) -> Bool { arena.dropFood(at: point) }

    public func advance() throws -> FleetFrame {
        guard !arena.complete else { return frame() }
        let start = ProcessInfo.processInfo.systemUptime
        var readings = [NeuralReading](repeating: NeuralReading(), count: 10)
        let inputs = models.indices.map { i -> BrainInput in
            let scent = arena.scent(for: i)
            return BrainInput(odorLeft: scent.left, odorRight: scent.right, taste: scent.contact ? 150 : 0)
        }
        let living = arena.flies.map(\.alive)
        let lock = NSLock()
        var results = snapshots
        var failure: Error?
        DispatchQueue.concurrentPerform(iterations: models.count) { i in
            guard living[i] else { return }
            do {
                let sample = try models[i].advance(inputs[i])
                lock.lock()
                results[i] = sample
                lock.unlock()
            } catch {
                lock.lock()
                failure = error
                lock.unlock()
            }
        }
        if let failure { throw failure }
        snapshots = results
        for i in models.indices where arena.flies[i].alive {
            let sample = snapshots[i]
            // Calculated smell-cell means and DNa02 rates influence steering. The goal
            // and fight rules remain programmed, as in the desktop pet.
            let metadata = models[i].metadata
            var left = 0.0
            var right = 0.0
            var nl = 0
            var nr = 0
            for index in metadata.channels["odor"] ?? [] {
                if metadata.sides[index] == -1 {
                    left += Double(sample.rates[index])
                    nl += 1
                }
                if metadata.sides[index] == 1 {
                    right += Double(sample.rates[index])
                    nr += 1
                }
            }
            let odorTurn = (left / Double(max(1, nl)) - right / Double(max(1, nr))) / 120
            let motorTurn = Double(sample.steeringLeftHz - sample.steeringRightHz) / 200
            readings[i] = NeuralReading(
                turn: odorTurn + motorTurn,
                activity: Double(sample.activeCells) / Double(models[i].cells) * 3)
        }
        arena.step(readings)
        lastCost = ProcessInfo.processInfo.systemUptime - start
        return frame()
    }

    public func frame() -> FleetFrame {
        let activity = snapshots.enumerated().map { id, s in
            FlyActivity(
                id: id, modelTime: s.time, activeCells: s.activeCells, totalSpikes: s.totalSpikes,
                meanHz: s.rates.reduce(0.0) { $0 + Double($1) } / Double(s.rates.count),
                odorLeft: s.inputs.odorLeft, odorRight: s.inputs.odorRight, rateHash: Self.hash(s.rates))
        }
        let points = snapshots.map { s in positions.map { BrainPoint(x: $0.1, y: $0.2, rate: s.rates[$0.0]) } }
        return FleetFrame(arena: arena, activity: activity, points: points, calculationSeconds: lastCost)
    }

    public static func hash(_ rates: [Float]) -> String {
        var value: UInt64 = 14_695_981_039_346_656_037
        rates.withUnsafeBytes { bytes in
            for byte in bytes { value = (value ^ UInt64(byte)) &* 1_099_511_628_211 }
        }
        return String(value, radix: 16)
    }
}
