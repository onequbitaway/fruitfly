import Foundation
import FlyCore

final class CircuitTests {
    func testBundledDataHasRealIDsAndBothSides() throws {
        let data = try CircuitData.bundled()
        expectEqual(data.source, "MaleCNS v1.0")
        expectGreater(data.ids.count, 3000)
        expectGreater(data.from.count, 1000)
        expect(data.ids.allSatisfy { UInt64($0) != nil })
        expect(data.sides.contains(-1) && data.sides.contains(1))
    }

    func testStimulusReachesOutputCellsThroughConnections() throws {
        let circuit = try SmellCircuit(data: CircuitData.bundled())
        for _ in 0..<50 { circuit.step(left: 0, right: 0, dt: 0.05) }
        expectEqual(circuit.activity, 0, accuracy: 0.000001)
        for _ in 0..<80 { circuit.step(left: 0.8, right: 0.2, dt: 0.05) }
        expectGreater(circuit.activity, 0.01)
        expect(circuit.rates.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 })
        circuit.reset()
        expect(circuit.rates.allSatisfy { $0 == 0 })
    }

    func testCircuitChangesPetMovement() throws {
        let area = Area(x: 0, y: 0, width: 1440, height: 900)
        let circuit = try SmellCircuit(data: CircuitData.bundled())
        let withCircuit = FlyWorld(areas: [area], seed: 1, circuit: circuit)
        let withoutCircuit = FlyWorld(areas: [area], seed: 1)
        for world in [withCircuit, withoutCircuit] { world.dropFood(at: Point(200, 180)) }
        for _ in 0..<60 {
            withCircuit.step(dt: 1.0 / 30)
            withoutCircuit.step(dt: 1.0 / 30)
        }
        expectGreater(circuit.activity, 0)
        expectGreater(withCircuit.position.distance(to: withoutCircuit.position), 0.1)
        for _ in 0..<900 { withCircuit.step(dt: 1.0 / 30) }
        expectEqual(withCircuit.eaten, 1)
    }
}
