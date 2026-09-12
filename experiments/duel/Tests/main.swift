import DuelCore
import Foundation

var failures = 0
func check(_ value: Bool, _ label: String) {
  if !value {
    print("FAIL: \(label)")
    failures += 1
  }
}
let engine = try FightEngine()
check(try engine.snapshot().fighters.count == 2, "two fighters")
let steps = try engine.advance([Reading(drive: 0.8), Reading(drive: 0.7)])
check(steps.count == 6 && steps.last?.frame == 6, "six physics frames per brain sample")
let folder = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "../full-map/Data")
let modes: [DuelMode] = CommandLine.arguments.contains("--full") ? [.simple, .full] : [.simple]
for mode in modes {
  let duel = try Duel(folder: folder, mode: mode)
  check(
    duel.models.count == 2 && duel.models.allSatisfy { $0.cells == mode.cells },
    "two separate graphs")
  let frame = try duel.advance()
  check(
    frame.activity.allSatisfy { abs($0.time - 0.1) < 0.00001 && $0.activeCells > 0 },
    "both brains advance")
  check(Set(frame.activity.map(\.rateHash)).count == 2, "separate seeds produce separate states")
  for i in 0..<2 {
    let s = duel.models[i].snapshot()
    check(Duel.hash(s.rates) == frame.activity[i].rateHash, "displayed rates match the model")
    check(
      frame.activity[i].points.allSatisfy { $0.rate == s.rates[$0.index] },
      "every dot uses its cell's rate")
    check(frame.activity[i].reading.drive > 0, "calculated sensory rates reach the controls")
  }
  duel.models[0].silence(Array(0..<mode.cells), enabled: true)
  duel.models[0].reset()
  let blocked = try duel.advance()
  check(
    blocked.activity[0].activeCells == 0 && blocked.activity[0].reading.drive == 0,
    "silenced brain cannot supply moves")
  check(
    blocked.activity[1].activeCells > 0 && blocked.activity[1].time > 0.1,
    "other brain remains independent")
  print("\(mode.rawValue): two independent brains; \(frame.calculationSeconds)s per sample")
}
print("\(failures) failures")
exit(failures == 0 ? 0 : 1)
