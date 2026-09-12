import Foundation
import RoyaleCore

var failures = 0
func check(_ value: Bool, _ message: String) {
    if !value {
        print("FAIL:", message)
        failures += 1
    }
}
let neutral = [NeuralReading](repeating: NeuralReading(), count: 10)
var first = Arena(seed: 42)
check(first.living == 10, "ten flies start alive")
check(first.flies.allSatisfy { abs($0.position.length - 246) < 0.001 }, "flies start on a circle")
check(!first.dropFood(at: Vector(.nan, 0)), "invalid food is rejected")
check(!first.dropFood(at: Vector(300, 0)), "food outside the dish is rejected")
for _ in 0..<20 { first.dropFood(at: .zero) }
check(first.food.count == 8, "food stays bounded")
let original = first.flies.map(\.position)
for _ in 0..<20 { first.step(neutral) }
check(first.flies.map(\.position) == original, "countdown holds the starting ring")
for seed in 1...30 {
    var arena = Arena(seed: UInt64(seed))
    var previousAlive = 10
    var hitCount = 0
    var largestRadius = arena.radius
    for _ in 0..<1100 {
        arena.step(neutral)
        check(arena.living > 0 && arena.living <= previousAlive, "elimination preserves one survivor")
        check(arena.radius <= largestRadius, "ring never grows")
        check(
            arena.flies.allSatisfy { $0.health >= 0 && $0.health <= 100 && $0.position.length <= 291.01 },
            "finite health and bounded position")
        previousAlive = arena.living
        largestRadius = arena.radius
        hitCount += arena.hits.count
        if arena.complete { break }
    }
    check(arena.winner != nil && arena.living == 1, "round \(seed) reaches one winner")
    check(hitCount > 0, "round produces blood events from damage")
    let time = arena.time
    let positions = arena.flies.map(\.position)
    arena.step(neutral)
    check(arena.time == time && arena.flies.map(\.position) == positions, "finished round stays frozen")
}
var a = Arena(seed: 97)
var b = Arena(seed: 97)
for _ in 0..<500 {
    a.step(neutral)
    b.step(neutral)
}
check(
    a.flies.map(\.health) == b.flies.map(\.health) && a.flies.map(\.position) == b.flies.map(\.position),
    "same seed reproduces combat")
var steered = Arena(seed: 97)
var unsteered = Arena(seed: 97)
for _ in 0..<50 {
    steered.step([NeuralReading](repeating: NeuralReading(turn: 1, activity: 1), count: 10))
    unsteered.step(neutral)
}
check(steered.flies.map(\.position) != unsteered.flies.map(\.position), "brain readouts affect movement")

if !CommandLine.arguments.contains("--game-only") {
    let folder = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "../full-map/Data")
    let modes: [FleetMode] = CommandLine.arguments.contains("--full") ? [.simple, .full] : [.simple]
    for mode in modes {
        let fleet = try BrainFleet(folder: folder, mode: mode)
        check(
            fleet.models.count == 10 && fleet.models.allSatisfy { $0.cells == mode.cellsPerFly },
            "ten full, separate graphs")
        let before = fleet.frame()
        _ = fleet.frame()
        check(
            before.activity.allSatisfy { $0.modelTime == 0 && $0.activeCells == 0 },
            "reading does not advance the brains")
        let frame = try fleet.advance()
        check(
            frame.activity.allSatisfy { abs($0.modelTime - 0.1) < 0.00001 && $0.activeCells > 0 },
            "all brains calculate food response")
        check(Set(frame.activity.map(\.rateHash)).count > 1, "fly states are not copies of one shared result")
        for i in 0..<10 {
            let sample = fleet.models[i].snapshot()
            check(
                BrainFleet.hash(sample.rates) == frame.activity[i].rateHash,
                "shown rates come from fly \(i)'s actual model")
            check(sample.activeCells == frame.activity[i].activeCells, "shown count matches calculated spikes")
        }
        fleet.models[0].silence(Array(0..<mode.cellsPerFly), enabled: true)
        fleet.models[0].reset()
        let blocked = try fleet.advance()
        check(
            blocked.activity[0].activeCells == 0 && blocked.activity.dropFirst().allSatisfy { $0.activeCells > 0 },
            "blocking one brain leaves the other nine active")
        print("\(mode.rawValue): ten brains checked; step cost \(frame.calculationSeconds)s")
    }
}
print("\(failures) failures; 30 complete rounds checked")
exit(failures == 0 ? 0 : 1)
