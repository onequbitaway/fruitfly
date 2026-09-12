import BrainCore
import Foundation
import JavaScriptCore

public enum DuelMode: String, Codable {
  case simple = "Simple"
  case full = "Full map"
  public var cells: Int { self == .simple ? 3745 : 166700 }
}
public struct Point: Codable {
  public let x: Double
  public let y: Double
}
public struct Fighter: Codable {
  public let slot: Int
  public let name: String
  public let position: Point
  public let velocity: Point
  public let facing: Int
  public let percent: Double
  public let stocks: Int
  public let state: String
  public let grounded: Bool
  public let jumpsRemaining: Int
  public let shield: Double
  public let maxShield: Double
  public let invulnerableFrames: Int
  public let currentMove: String?
  public let moveFrame: Int
  public let hitstunFrames: Int
  public let respawnFrames: Int
  public let visualRotation: Double
  public let size: PointSize
}
public struct PointSize: Codable {
  public let width: Double
  public let height: Double
}
public struct Platform: Codable {
  public let id: String
  public let x: Double
  public let y: Double
  public let width: Double
  public let height: Double
  public let kind: String
}
public struct Stage: Codable { public let platforms: [Platform] }
public struct Event: Codable {
  public let type: String
  public let frame: Int
  public let slot: Int?
  public let target: Int?
  public let position: Point?
  public let move: String?
  public let damage: Double?
  public let velocity: Point?
}
public struct Match: Codable {
  public let frame: Int
  public let elapsedMs: Double
  public let remainingTimeMs: Double?
  public let phase: String
  public let countdownFrames: Int
  public let suddenDeath: Bool
  public let fighters: [Fighter]
  public let stage: Stage
  public let winner: Int?
  public let events: [Event]
  public var complete: Bool { phase == "finished" }
}
public struct Reading: Codable {
  public let drive: Double
  public let turn: Double
  public init(drive: Double = 0, turn: Double = 0) {
    self.drive = drive
    self.turn = turn
  }
}
public struct BrainPoint: Codable {
  public let index: Int
  public let x: Double
  public let y: Double
  public let rate: Float
}
public struct Activity: Codable {
  public let id: Int
  public let time: Double
  public let activeCells: Int
  public let spikes: UInt64
  public let inputs: BrainInput
  public let reading: Reading
  public let rateHash: String
  public let points: [BrainPoint]
}
public struct DuelFrame: Codable {
  public let frames: [Match]
  public let activity: [Activity]
  public let effects: [Event]
  public let calculationSeconds: Double
  public var match: Match { frames.last! }
}

/// Each instance belongs to one serial worker. JavaScriptCore has no network or file bridge.
public final class FightEngine {
  private let context: JSContext
  private let api: JSValue
  private var error: String?
  public init(seed: UInt64 = 42, stocks: Int = 3, countdown: Int = 180) throws {
    guard let context = JSContext() else { throw Self.failure("Could not start the fight engine.") }
    self.context = context
    let resources: Bundle
    if Bundle.main.bundleURL.pathExtension == "app" {
      guard let folder = Bundle.main.resourceURL,
        let packaged = Bundle(url: folder.appendingPathComponent("FruitflyDuel_DuelCore.bundle"))
      else {
        throw Self.failure("The app is missing its fight engine. Download the complete app again.")
      }
      resources = packaged
    } else {
      resources = Bundle.module
    }
    guard let url = resources.url(forResource: "engine", withExtension: "js") else {
      throw Self.failure("The fight engine file is missing.")
    }
    context.evaluateScript(try String(contentsOf: url, encoding: .utf8))
    guard context.exception == nil, let value = context.objectForKeyedSubscript("DuelEngine"),
      !value.isUndefined
    else {
      throw Self.failure(context.exception?.toString() ?? "Could not load the fight engine.")
    }
    api = value
    context.exceptionHandler = { [weak self] _, exception in self?.error = exception?.toString() }
    _ = try call("reset", [Double(seed & 0xFFFF_FFFF), stocks, countdown])
  }
  private func call(_ name: String, _ args: [Any] = []) throws -> Data {
    error = nil
    guard let result = api.invokeMethod(name, withArguments: args)?.toString(), error == nil,
      let data = result.data(using: .utf8)
    else { throw Self.failure(error ?? "Fight engine stopped.") }
    return data
  }
  public func snapshot() throws -> Match {
    try JSONDecoder().decode(Match.self, from: call("snapshot"))
  }
  public func advance(_ readings: [Reading]) throws -> [Match] {
    guard readings.count == 2 else { throw Self.failure("The match needs two brain readings.") }
    let values = readings.map { ["drive": $0.drive, "turn": $0.turn] }
    return try JSONDecoder().decode([Match].self, from: call("advance", [values]))
  }
  private static func failure(_ message: String) -> Error {
    NSError(domain: "FruitflyDuel", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
  }
}

public final class Duel {
  public let mode: DuelMode
  public let models: [BrainModel]
  public let engine: FightEngine
  public private(set) var current: DuelFrame
  private let positions: [(Int, Double, Double)]
  public init(folder: URL, mode: DuelMode, seed: UInt64 = 42, stocks: Int = 3) throws {
    self.mode = mode
    engine = try FightEngine(seed: seed, stocks: stocks)
    models = try (0..<2).map { i in
      let model = try BrainModel(
        folder: folder, mode: mode == .simple ? .simple : .full, useGPU: mode == .full)
      model.reset(seed: seed &+ UInt64(i) &* 104729)
      return model
    }
    let known = models[0].metadata.positions.enumerated().compactMap {
      index, p -> (Int, Double, Double)? in
      guard let p else { return nil }
      return (index, Double(p[0]), Double(p[2]))
    }
    let minX = known.map { $0.1 }.min() ?? 0
    let maxX = known.map { $0.1 }.max() ?? 1
    let minY = known.map { $0.2 }.min() ?? 0
    let maxY = known.map { $0.2 }.max() ?? 1
    positions = known.enumerated().filter { $0.offset % max(1, known.count / 1200) == 0 }.map {
      _, p in
      (p.0, (p.1 - minX) / max(1, maxX - minX), (p.2 - minY) / max(1, maxY - minY))
    }
    current = DuelFrame(
      frames: [try engine.snapshot()], activity: [], effects: [], calculationSeconds: 0)
    current = DuelFrame(
      frames: current.frames,
      activity: models.enumerated().map { i, m in
        activity(m.snapshot(), id: i)
      }, effects: [], calculationSeconds: 0)
  }
  public func advance() throws -> DuelFrame {
    guard !current.match.complete else { return current }
    let start = ProcessInfo.processInfo.systemUptime
    // The opponent is a visual target in Full map. Simple has only a smell
    // circuit, so opponent direction becomes an explicit game scent cue.
    // These are simulated inputs, not measured fly combat sensory signals.
    let inputs = (0..<2).map { i -> BrainInput in
      let a = current.match.fighters[i]
      let b = current.match.fighters[1 - i]
      let dx = b.position.x - a.position.x
      let dy = b.position.y - a.position.y
      let signal = Float(35 + 135 / (1 + hypot(dx, dy) / 220))
      let left = dx < 0 ? signal : signal * 0.18
      let right = dx >= 0 ? signal : signal * 0.18
      return mode == .full
        ? BrainInput(odorLeft: 20, odorRight: 20, visualLeft: left, visualRight: right)
        : BrainInput(odorLeft: left, odorRight: right)
    }
    // Sequential model access avoids races and supports the CPU fallback.
    let samples = try models.indices.map { try models[$0].advance(inputs[$0]) }
    let readings = samples.enumerated().map { activity($0.element, id: $0.offset) }
    let frames = try engine.advance(readings.map(\.reading))
    let endFrame = frames.last?.frame ?? current.match.frame
    let effects = (current.effects + frames.flatMap(\.events)).filter {
      endFrame - $0.frame < 60
        && ["hit", "throw", "ko", "shield-hit", "attack-active"].contains($0.type)
    }
    current = DuelFrame(
      frames: frames.isEmpty ? current.frames : frames, activity: readings,
      effects: effects, calculationSeconds: ProcessInfo.processInfo.systemUptime - start)
    return current
  }
  private func activity(_ sample: BrainSnapshot, id: Int) -> Activity {
    let metadata = models[id].metadata
    let channel = metadata.channels[mode == .full ? "visual" : "odor"] ?? []
    let left = channel.filter { metadata.sides[$0] == -1 }
    let right = channel.filter { metadata.sides[$0] == 1 }
    func mean(_ ids: [Int]) -> Double {
      ids.reduce(0) { $0 + Double(sample.rates[$1]) } / Double(max(1, ids.count))
    }
    let drive = min(1, mean(channel) / 140)
    let turn = max(
      -1,
      min(
        1,
        (mean(right) - mean(left)) / 160 + Double(sample.steeringRightHz - sample.steeringLeftHz)
          / 400))
    return Activity(
      id: id, time: sample.time, activeCells: sample.activeCells, spikes: sample.totalSpikes,
      inputs: sample.inputs, reading: Reading(drive: drive, turn: turn),
      rateHash: Self.hash(sample.rates),
      points: positions.map { BrainPoint(index: $0.0, x: $0.1, y: $0.2, rate: sample.rates[$0.0]) })
  }
  public static func hash(_ rates: [Float]) -> String {
    var value: UInt64 = 14_695_981_039_346_656_037
    rates.withUnsafeBytes { bytes in
      for byte in bytes { value = (value ^ UInt64(byte)) &* 1_099_511_628_211 }
    }
    return String(value, radix: 16)
  }
}
