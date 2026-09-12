import Foundation

public struct CircuitData: Decodable {
    public let source: String
    public let ids: [String]
    public let types: [String]
    public let kinds: [Int]
    public let sides: [Int]
    public let signs: [Float]
    public let from: [Int]
    public let to: [Int]
    public let counts: [Int]

    public static func bundled() throws -> CircuitData {
        // SwiftPM puts its resource bundle beside the executable. Packaged apps
        // put it in Contents/Resources so the app works after it is moved.
        let name = "Fruitfly_FlyCore"
        let packaged = Bundle.main.url(forResource: name, withExtension: "bundle")
            .flatMap { Bundle(url: $0) }
        let bundle: Bundle
        if Bundle.main.bundleURL.pathExtension == "app" {
            guard let packaged else { throw CircuitError.missingData }
            bundle = packaged
        } else {
            bundle = Bundle.module
        }
        guard let url = bundle.url(forResource: "smell-circuit", withExtension: "json") else {
            throw CircuitError.missingData
        }
        let decoded = try JSONDecoder().decode(CircuitData.self, from: Data(contentsOf: url))
        try decoded.validate()
        return decoded
    }

    public func validate() throws {
        let n = ids.count
        guard n > 0, types.count == n, kinds.count == n, sides.count == n, signs.count == n,
              Set(ids).count == n, from.count == to.count, from.count == counts.count,
              !from.isEmpty else { throw CircuitError.invalidData }
        for i in 0..<n {
            guard (0...2).contains(kinds[i]), (-1...1).contains(sides[i]),
                  signs[i] == 1 || signs[i] == -1 else { throw CircuitError.invalidData }
        }
        for i in from.indices {
            guard (0..<n).contains(from[i]), (0..<n).contains(to[i]), counts[i] > 0 else {
                throw CircuitError.invalidData
            }
        }
    }
}

public enum CircuitError: Error { case missingData, invalidData }

/// A rate model of a selected smell circuit. This is not a full brain simulation.
/// Wiring and contact counts come from MaleCNS; dynamics and readouts are chosen here.
public final class SmellCircuit {
    public let data: CircuitData
    public private(set) var rates: [Float]
    public private(set) var left: Double = 0
    public private(set) var right: Double = 0
    public var activity: Double { (left + right) / 2 }
    public var neuronCount: Int { data.ids.count }
    public var connectionCount: Int { data.from.count }
    private var weights: [Float]
    private var drive: [Float]
    private var outputsLeft: [Int] = []
    private var outputsRight: [Int] = []
    private var inputs: [Int] = []

    public init(data: CircuitData) throws {
        try data.validate()
        self.data = data
        rates = Array(repeating: 0, count: data.ids.count)
        drive = rates
        var totals = rates
        for i in data.from.indices { totals[data.to[i]] += Float(data.counts[i]) }
        weights = data.from.indices.map {
            Float(data.counts[$0]) * data.signs[data.from[$0]] / max(1, totals[data.to[$0]])
        }
        for i in data.ids.indices {
            if data.kinds[i] == 0 { inputs.append(i) }
            if data.kinds[i] == 1 && data.sides[i] == -1 { outputsLeft.append(i) }
            if data.kinds[i] == 1 && data.sides[i] == 1 { outputsRight.append(i) }
        }
    }

    public func step(left stimulusLeft: Double, right stimulusRight: Double, dt: Double) {
        guard dt.isFinite, dt > 0 else { return }
        for i in drive.indices { drive[i] = 0 }
        for e in weights.indices { drive[data.to[e]] += rates[data.from[e]] * weights[e] * 1.6 }
        let l = Float(bounded(stimulusLeft.isFinite ? stimulusLeft : 0, 0, 1))
        let r = Float(bounded(stimulusRight.isFinite ? stimulusRight : 0, 0, 1))
        for i in inputs {
            let input = data.sides[i] == -1 ? l : (data.sides[i] == 1 ? r : (l + r) / 2)
            drive[i] += input * 1.8
        }
        let alpha = Float(1 - exp(-min(dt, 0.1) / 0.08))
        for i in rates.indices {
            let target = tanh(max(0, drive[i] - 0.025))
            rates[i] += (target - rates[i]) * alpha
        }
        left = mean(outputsLeft)
        right = mean(outputsRight)
    }

    public func reset() {
        for i in rates.indices { rates[i] = 0 }
        left = 0; right = 0
    }
    private func mean(_ ids: [Int]) -> Double {
        guard !ids.isEmpty else { return 0 }
        return Double(ids.reduce(Float(0)) { $0 + rates[$1] }) / Double(ids.count)
    }
}
