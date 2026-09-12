import BrainKernel
import Foundation

public enum BrainMode: String, CaseIterable {
    case simple = "Simple"
    case full = "Full map"
}
public struct BrainMetadata: Decodable {
    public let dataset: String
    public let ids: [UInt64]
    public let types: [Int]
    public let typeNames: [String]
    public let groups: [Int]
    public let groupNames: [String]
    public let sides: [Int]
    public let positions: [[Int]?]
    public let channels: [String: [Int]]
    public let selection: String
    public let positionMeaning: String
    public func type(at index: Int) -> String { typeNames[types[index]] }
}
public struct BrainInput: Codable {
    public var odorLeft: Float = 0
    public var odorRight: Float = 0
    public var taste: Float = 0
    public var visualLeft: Float = 0
    public var visualRight: Float = 0
    public var feeding: Float = 0
    public init(
        odorLeft: Float = 0, odorRight: Float = 0, taste: Float = 0,
        visualLeft: Float = 0, visualRight: Float = 0, feeding: Float = 0
    ) {
        self.odorLeft = odorLeft
        self.odorRight = odorRight
        self.taste = taste
        self.visualLeft = visualLeft
        self.visualRight = visualRight
        self.feeding = feeding
    }
    public var hasInput: Bool { odorLeft + odorRight + taste + visualLeft + visualRight + feeding > 0 }
}
public struct BrainSnapshot {
    public let time: Double
    public let rates: [Float]
    public let groupActive: [Int]
    public let groupMeanHz: [Double]
    public let activeCells: Int
    public let totalSpikes: UInt64
    public let computationSeconds: Double
    public let inputs: BrainInput
    public let directCells: Int
    public let steeringLeftHz: Float
    public let steeringRightHz: Float
    public let feedingHz: Float
}
public final class BrainModel {
    public let metadata: BrainMetadata
    public let mode: BrainMode
    private let handle: OpaquePointer
    private var gpu: MetalSolver?
    public var processor: String { gpu.map { $0.device.name } ?? "CPU" }
    public var cells: Int { Int(FFCellCount(handle)) }
    public var connections: Int { Int(FFConnectionCount(handle)) }
    public var contacts: UInt64 { FFContactCount(handle) }
    public var time: Double { gpu.map { Double($0.tick) * 0.0002 } ?? FFTime(handle) }
    public var processedConnections: UInt64 { FFProcessedContacts(handle) }
    public let groupCounts: [Int]

    public init(folder: URL, mode: BrainMode, useGPU: Bool = true) throws {
        self.mode = mode
        let prefix = mode == .simple ? "simple-" : ""
        let decoded = try JSONDecoder().decode(
            BrainMetadata.self, from: Data(contentsOf: folder.appendingPathComponent(prefix + "neurons.json")))
        metadata = decoded
        guard let created = FFCreate(folder.appendingPathComponent(prefix + "network.bin").path) else {
            throw NSError(
                domain: "FruitflyBrain", code: 1, userInfo: [NSLocalizedDescriptionKey: String(cString: FFLastError())])
        }
        handle = created
        let n = metadata.ids.count
        guard Int(FFCellCount(handle)) == n, metadata.types.count == n, metadata.groups.count == n,
            metadata.positions.count == n, metadata.sides.count == n,
            Set(metadata.ids).count == n,
            metadata.positions.allSatisfy({ $0 == nil || $0!.count == 3 }),
            metadata.types.allSatisfy({ decoded.typeNames.indices.contains($0) }),
            metadata.groups.allSatisfy({ decoded.groupNames.indices.contains($0) }),
            metadata.channels.values.allSatisfy({ $0.allSatisfy { (0..<n).contains($0) } })
        else {
            FFDestroy(created)
            throw NSError(
                domain: "FruitflyBrain", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Cell metadata does not match the graph."])
        }
        var counts = [Int](repeating: 0, count: metadata.groupNames.count)
        for group in metadata.groups { counts[group] += 1 }
        groupCounts = counts
        FFReset(handle, 7)
        // The same CPU solver remains available if this Mac cannot initialize Metal.
        if useGPU {
            gpu = try? MetalSolver(
                path: folder.appendingPathComponent(prefix + "network.bin"), cells: n,
                edges: Int(FFConnectionCount(handle)))
        }
    }
    deinit { FFDestroy(handle) }
    public func reset(seed: UInt64 = 7) {
        FFReset(handle, seed)
        gpu?.reset(seed: seed)
    }
    public func silence(_ indices: [Int], enabled: Bool) {
        gpu?.silence(indices, enabled: enabled)
        for index in indices where index >= 0 && index < cells { FFSilence(handle, UInt32(index), enabled ? 1 : 0) }
    }
    public func voltageAboveRest(at index: Int) -> Float {
        gpu?.voltageAboveRest(at: index) ?? FFVoltages(handle)[index]
    }
    public func snapshot(inputs: BrainInput = BrainInput(), duration: Double = 0, direct: Int = 0) -> BrainSnapshot {
        let rates = gpu?.rates ?? Array(UnsafeBufferPointer(start: FFRates(handle), count: cells))
        var active = [Int](repeating: 0, count: groupCounts.count)
        var totals = [Double](repeating: 0, count: groupCounts.count)
        var total = 0
        for i in rates.indices {
            let group = metadata.groups[i]
            totals[group] += Double(rates[i])
            if rates[i] > 0 {
                active[group] += 1
                total += 1
            }
        }
        func mean(_ key: String, side: Int? = nil) -> Float {
            let ids = (metadata.channels[key] ?? []).filter { side == nil || metadata.sides[$0] == side }
            return ids.isEmpty ? 0 : ids.reduce(Float(0)) { $0 + rates[$1] } / Float(ids.count)
        }
        return BrainSnapshot(
            time: time, rates: rates, groupActive: active,
            groupMeanHz: totals.indices.map { totals[$0] / Double(max(1, groupCounts[$0])) }, activeCells: total,
            totalSpikes: gpu?.totalSpikes ?? FFTotalSpikes(handle), computationSeconds: duration, inputs: inputs,
            directCells: direct,
            steeringLeftHz: mean("steering", side: -1), steeringRightHz: mean("steering", side: 1),
            feedingHz: mean("mn9"))
    }
    public func advance(_ input: BrainInput) throws -> BrainSnapshot {
        var ids: [UInt32] = []
        var frequencies: [Float] = []
        func add(_ name: String, _ left: Float, _ right: Float) {
            for index in metadata.channels[name] ?? [] {
                let side = metadata.sides[index]
                let value = side == -1 ? left : (side == 1 ? right : (left + right) / 2)
                let hz = min(200, max(0, value.isFinite ? value : 0))
                if hz > 0 {
                    ids.append(UInt32(index))
                    frequencies.append(hz)
                }
            }
        }
        add("odor", input.odorLeft, input.odorRight)
        add("taste", input.taste, input.taste)
        add("visual", input.visualLeft, input.visualRight)
        add("feeding", input.feeding, input.feeding)
        let start = ProcessInfo.processInfo.systemUptime
        if let gpu {
            try gpu.advance(ids: ids, frequencies: frequencies)
        } else {
            FFAdvance(handle, ids, frequencies, UInt32(ids.count))
        }
        return snapshot(inputs: input, duration: ProcessInfo.processInfo.systemUptime - start, direct: ids.count)
    }
}
