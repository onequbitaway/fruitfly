import BrainCore
import Foundation

let folder = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Data")
var failures = 0
func check(_ pass: Bool, _ message: String) {
    if !pass {
        failures += 1
        print("FAIL: \(message)")
    }
}
func drive(_ model: BrainModel, _ input: BrainInput, _ frames: Int = 10) throws -> BrainSnapshot {
    var s = model.snapshot()
    for _ in 0..<frames { s = try model.advance(input) }
    return s
}
// A small graph gives an independent linear solution for an inhibitory target.
let toy = FileManager.default.temporaryDirectory.appendingPathComponent("fruitfly-checks-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: toy, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: toy) }
var bytes = Data("FFBRN001".utf8)
func append<T>(_ v: T) {
    var x = v
    withUnsafeBytes(of: &x) { bytes.append(contentsOf: $0) }
}
append(UInt32(5))
append(UInt32(3))
append(UInt64(800))
for x: UInt32 in [0, 2, 2, 3, 3, 3, 1, 3, 4, 100, 200, 500] { append(x) }
for x: Float in [1, 1, -1, 1, 1] { append(x) }
try bytes.write(to: toy.appendingPathComponent("network.bin"))
let meta: [String: Any] = [
    "dataset": "Analytical test graph", "ids": [0, 1, 2, 3, 4], "types": [0, 0, 0, 0, 0], "typeNames": ["test"],
    "groups": [0, 0, 0, 0, 0], "groupNames": ["test"], "sides": [0, 0, 0, 0, 0],
    "positions": [NSNull(), NSNull(), NSNull(), NSNull(), NSNull()],
    "channels": ["odor": [0], "taste": [2], "mn9": [1]], "selection": "test", "positionMeaning": "none",
]
try JSONSerialization.data(withJSONObject: meta).write(to: toy.appendingPathComponent("neurons.json"))
func unit(_ cell: UInt32, _ tick: UInt32) -> Float {
    var x = cell ^ (tick &* 747_796_405) ^ (UInt32(7) &* 2_891_336_453)
    x ^= x >> 16
    x = x &* 2_246_822_519
    x ^= x >> 13
    x = x &* 3_266_489_917
    x ^= x >> 16
    return Float(x >> 8) / 16_777_216
}
for gpu in [false, true] {
    let model = try BrainModel(folder: toy, mode: .full, useGPU: gpu)
    let silent = try drive(model, BrainInput(), 1)
    check(silent.totalSpikes == 0, "no input creates no spikes")
    model.reset()
    let inhibitory = try drive(model, BrainInput(taste: 200), 1)
    let spikeSteps = (0..<500).filter { unit(2, UInt32($0)) < Float(200) * Float(0.0002) }
    check(inhibitory.rates[2] == Float(spikeSteps.count) * 10, "forced input matches seeded spike train")
    check(inhibitory.rates[4] == 0, "inhibition cannot make isolated target fire")
    let em = Double(exp(-Float(0.2) / 20))
    let es = Double(exp(-Float(0.2) / 5))
    let expected = spikeSteps.filter { $0 + 9 < 500 }.reduce(0.0) { sum, t in
        let elapsed = Double(500 - (t + 9))
        return sum - 500 * 0.275 * (pow(em, elapsed) - pow(es, elapsed)) / 3
    }
    check(
        abs(Double(model.voltageAboveRest(at: 4)) - expected) < 0.005,
        "inhibitory voltage matches closed-form decay and 1.8 ms delay")
    model.reset()
    let excitation = try drive(model, BrainInput(odorLeft: 200, odorRight: 200), 1)
    check(excitation.rates[1] > 0 && excitation.rates[3] > 0, "connected excitatory targets fire")
    check(excitation.rates[2] == 0 && excitation.rates[4] == 0, "unconnected pathway remains silent")
    model.silence([0], enabled: true)
    model.reset()
    check(
        try drive(model, BrainInput(odorLeft: 200, odorRight: 200), 1).activeCells == 0,
        "blocking source removes downstream response")
    print("Analytical graph checked on", model.processor)
}
if CommandLine.arguments.contains("--kernel-only") {
    print("\(failures) kernel failures")
    exit(failures == 0 ? 0 : 1)
}
let full = try BrainModel(folder: folder, mode: .full)
print("Processor", full.processor)
fflush(stdout)
check(
    full.cells == 166700 && full.connections == 25_582_938 && full.contacts == 124_177_617,
    "complete released graph counts")
check(full.metadata.positions.filter { $0 == nil }.count == 27038, "missing positions remain missing")
let inputs: [(String, BrainInput)] = [
    ("No input", BrainInput()), ("Smell", BrainInput(odorLeft: 120, odorRight: 80)),
    ("Taste LB1", BrainInput(taste: 150)), ("Feeding pathway", BrainInput(feeding: 150)),
    ("Visual LC10a", BrainInput(visualLeft: 140, visualRight: 30)),
]
var reports: [[String: Any]] = []
for (name, input) in inputs {
    full.reset()
    let start = ProcessInfo.processInfo.systemUptime
    let result = try drive(full, input)
    check(result.rates.allSatisfy { $0.isFinite && $0 >= 0 }, "finite rates")
    check(input.hasInput ? result.activeCells > 0 : result.activeCells == 0, "response follows input")
    check(result.groupActive.reduce(0, +) == result.activeCells, "class totals include every active cell")
    let cost = ProcessInfo.processInfo.systemUptime - start
    reports.append([
        "input": name, "active": result.activeCells, "groupActive": result.groupActive, "MN9Hz": result.feedingHz,
        "DNa02LeftHz": result.steeringLeftHz, "DNa02RightHz": result.steeringRightHz, "wallSecondsPerModelSecond": cost,
    ])
    print(
        name, "active", result.activeCells, "MN9", result.feedingHz, "DNa02", result.steeringLeftHz,
        result.steeringRightHz, "cost", cost)
    fflush(stdout)
}
let visual = BrainInput(visualLeft: 140, visualRight: 30)
full.reset()
let once = try drive(full, visual, 3)
full.reset()
let twice = try drive(full, visual, 3)
check(once.rates == twice.rates && once.totalSpikes == twice.totalSpikes, "GPU repeat is deterministic")
let cpu = try BrainModel(folder: folder, mode: .full, useGPU: false)
let cpuResult = try drive(cpu, visual, 3)
let mismatches = zip(cpuResult.rates, twice.rates).filter { $0 != $1 }.count
print("CPU/GPU differing rates after 300 ms:", mismatches)
check(mismatches == 0 && cpuResult.totalSpikes == twice.totalSpikes, "CPU and GPU produce the same full-network spikes")
let before = full.time
let read = full.snapshot()
_ = full.snapshot()
check(full.time == before && full.snapshot().rates == read.rates, "reading activity cannot advance the model")
full.reset()
let feeding = try drive(full, BrainInput(feeding: 150))
full.silence(full.metadata.channels["mn9"]!, enabled: true)
full.reset()
let blocked = try drive(full, BrainInput(feeding: 150))
check(
    feeding.feedingHz > 0 && blocked.feedingHz == 0 && blocked.activeCells > 0,
    "MN9 block changes feeding output while other cells still fire")
var trial = Trial()
trial.dropFood(x: trial.x, y: trial.y)
for _ in 0..<10 { trial.advance(blocked, mode: .full) }
check(trial.foodAmount == 1, "blocked MN9 prevents full-mode food use")
trial.advance(feeding, mode: .full)
check(trial.foodAmount < 1, "measured MN9 output changes food use")
let simple = try BrainModel(folder: folder, mode: .simple, useGPU: false)
check(simple.cells == 3745, "simple mode retains released small set")
check(Set(simple.metadata.ids).isSubset(of: Set(full.metadata.ids)), "simple cells exist in full map")
check(
    simple.metadata.channels["taste"]!.isEmpty && simple.metadata.channels["mn9"]!.isEmpty,
    "simple does not invent absent taste/motor cells")
print("\(failures) failures")
let report: [String: Any] = [
    "failures": failures, "processor": full.processor, "CPUvsGPURateMismatchesAt300ms": mismatches,
    "inputTrials": reports, "modelStepMilliseconds": 0.2, "seed": 7,
]
try FileManager.default.createDirectory(
    at: folder.deletingLastPathComponent().appendingPathComponent("output"), withIntermediateDirectories: true)
try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(
    to: folder.deletingLastPathComponent().appendingPathComponent("output/checks.json"))
exit(failures == 0 ? 0 : 1)
