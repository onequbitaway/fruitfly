import Foundation

// These checks use the Apple command-line tools. Full Xcode is not required.
var failures = 0
func expect(_ value: Bool, _ message: String = "Condition failed", file: StaticString = #fileID, line: UInt = #line) {
    if !value { failures += 1; print("FAIL \(file):\(line): \(message)") }
}
func expectFalse(_ value: Bool, _ message: String = "Expected false", file: StaticString = #fileID, line: UInt = #line) {
    expect(!value, message, file: file, line: line)
}
func expectEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "Values differ", file: StaticString = #fileID, line: UInt = #line) {
    expect(a == b, message, file: file, line: line)
}
func expectEqual(_ a: Double, _ b: Double, accuracy: Double, file: StaticString = #fileID, line: UInt = #line) {
    expect(abs(a - b) <= accuracy, "Values differ", file: file, line: line)
}
func expectGreater<T: Comparable>(_ a: T, _ b: T, _ message: String = "Value is too small", file: StaticString = #fileID, line: UInt = #line) {
    expect(a > b, message, file: file, line: line)
}
func expectAtMost<T: Comparable>(_ a: T, _ b: T, file: StaticString = #fileID, line: UInt = #line) {
    expect(a <= b, "Value is too large", file: file, line: line)
}

let world = FlyWorldTests()
let circuit = CircuitTests()
var cases: [(String, () throws -> Void)] = [
    ("Find and eat food", world.testFlyFindsAndEatsFoodAcrossSeeds),
    ("Pause", world.testPauseFreezesMovementFoodAndCircuitTime),
    ("Screen limits and screen removal", world.testFlyStaysVisibleDuringLongRunAndScreenRemoval),
    ("Food limits and expiry", world.testFoodLimitExpiryAndInvalidCoordinates),
    ("Still cursor", world.testStillCursorDoesNotPreventEating),
    ("Cursor reaction", world.testFastCursorStartlesFly),
    ("Invalid time values", world.testInvalidFrameTimesDoNotCorruptPosition),
]
if !CommandLine.arguments.contains("--world-only") {
    cases += [
        ("Bundled brain data", circuit.testBundledDataHasRealIDsAndBothSides),
        ("Circuit response", circuit.testStimulusReachesOutputCellsThroughConnections),
        ("Circuit changes movement", circuit.testCircuitChangesPetMovement),
    ]
}
for (name, run) in cases {
    let before = failures
    do { try run() } catch { failures += 1; print("FAIL \(name): \(error)") }
    if failures == before { print("PASS \(name)") }
}
print("\(cases.count) checks finished. \(failures) failures.")
exit(failures == 0 ? 0 : 1)
