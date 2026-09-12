import Foundation
import CryptoKit
import ImageIO
import FlyCore

final class ActivityTests {
    func testReadingUsesActualCellsWithoutChangingTheModel() throws {
        let data = try CircuitData.bundled()
        let observed = try SmellCircuit(data: data)
        let control = try SmellCircuit(data: data)
        let baseline = ActivityReading(circuit: observed)
        expect(baseline.rates.allSatisfy { $0 == 0 })
        expectEqual(baseline.activeCells, 0)
        for _ in 0..<80 {
            observed.step(left: 0.8, right: 0.2, dt: 0.05)
            let reading = ActivityReading(circuit: observed)
            control.step(left: 0.8, right: 0.2, dt: 0.05)
            expectEqual(reading.rates, observed.rates)
            expectEqual(reading.rates, control.rates, "Reading activity must not affect the model")
            expectEqual(reading.outputLeft, observed.left)
            expectEqual(reading.inputRight, Double(Float(0.2)))
        }
        expect(baseline.rates.allSatisfy { $0 == 0 }, "A saved reading must not change with the next step")
        expectGreater(ActivityReading(circuit: observed).activeCells, 0)
    }

    func testPauseHoldsHistoryAndResetStartsAgain() throws {
        let demo = try ActivityDemo(data: CircuitData.bundled())
        for _ in 0..<40 { demo.advance() }
        let circuit = demo.world.circuit!
        let before = ActivityReading(circuit: circuit)
        let count = demo.history.points.count
        demo.world.paused = true
        for _ in 0..<20 {
            demo.world.step(dt: 0.05)
            demo.history.append(ActivityReading(circuit: circuit))
        }
        expectEqual(circuit.rates, before.rates)
        expectEqual(circuit.stepCount, before.step)
        expectEqual(demo.history.points.count, count)
        circuit.reset()
        demo.history.append(ActivityReading(circuit: circuit))
        expectEqual(demo.history.points.count, 1)
        expectEqual(demo.history.points[0].time, 0)
        demo.world.paused = false
        for _ in 0..<240 { demo.advance() }
        let times = demo.history.points.map(\.time)
        expect(times.last! - times.first! <= 10.000001)
    }

    func testLayoutKeepsSourceCellAndConnectionIdentity() throws {
        let data = try CircuitData.bundled()
        let layout = ActivityLayout(data: data)
        let repeatLayout = ActivityLayout(data: data)
        expectEqual(layout.positions.count, data.ids.count)
        expectEqual(layout.positions, repeatLayout.positions)
        expect(layout.positions.allSatisfy { $0.x >= 0 && $0.x <= 1 && $0.y >= 0 && $0.y <= 1 })
        expectEqual(Set(layout.positions.map { "\($0.x),\($0.y)" }).count, data.ids.count)
        expectEqual(layout.connections.count, 600)
        expectEqual(Set(layout.connections).count, 600)
        for edge in layout.connections {
            expect(data.from.indices.contains(edge))
            expect(data.kinds[data.from[edge]] != data.kinds[data.to[edge]])
        }
        let counts = layout.connections.map { data.counts[$0] }
        expectEqual(counts, counts.sorted(by: >))
    }
}

/// Replay the public recording and compare every saved cell value with the model.
func verifyRecording(rawPath: String, mediaPath: String) throws {
    let folder = URL(fileURLWithPath: mediaPath)
    let raw = try Data(contentsOf: URL(fileURLWithPath: rawPath))
    let framesData = try Data(contentsOf: folder.appendingPathComponent("activity-frames.json"))
    let frames = try JSONDecoder().decode([ActivityFrame].self, from: framesData)
    let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("activity-manifest.json"))) as! [String: Any]
    let sourceHashes = manifest["sourceSHA256"] as! [String: String]
    let fileHashes = manifest["fileSHA256"] as! [String: String]
    func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    for (path, expected) in sourceHashes {
        expectEqual(hash(try Data(contentsOf: URL(fileURLWithPath: path))), expected, "Source changed: \(path). Run make demo.")
    }
    expectEqual(hash(raw), fileHashes["cell-activity.f32"])
    expectEqual(hash(framesData), fileHashes["activity-frames.json"])
    let gifURL = folder.appendingPathComponent("brain-activity.gif")
    expectEqual(hash(try Data(contentsOf: gifURL)), fileHashes["brain-activity.gif"])
    let gif = CGImageSourceCreateWithURL(gifURL as CFURL, nil)!
    expectEqual(CGImageSourceGetCount(gif), ActivityDemo.frames)
    for i in 0..<CGImageSourceGetCount(gif) {
        let properties = CGImageSourceCopyPropertiesAtIndex(gif, i, nil)! as NSDictionary
        let gifProperties = properties[kCGImagePropertyGIFDictionary] as! NSDictionary
        let delay = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double
            ?? gifProperties[kCGImagePropertyGIFDelayTime] as! Double
        expectEqual(delay, 1.0 / Double(ActivityDemo.fps), accuracy: 0.000001)
    }
    let data = try CircuitData.bundled()
    expectEqual(frames.count, ActivityDemo.frames)
    expectEqual(raw.count, ActivityDemo.frames * data.ids.count * 4)
    guard frames.count == ActivityDemo.frames, raw.count == ActivityDemo.frames * data.ids.count * 4 else { return }
    let demo = try ActivityDemo(data: data)
    var maximumError: Float = 0
    for i in 0..<ActivityDemo.frames {
        let reading = demo.advance()
        let saved = frames[i]
        let current = ActivityFrame(reading: reading, world: demo.world)
        expectEqual(saved.step, current.step)
        expectEqual(saved.time, current.time, accuracy: 0.000001)
        expectEqual(saved.inputLeft, current.inputLeft, accuracy: 0.000002)
        expectEqual(saved.inputRight, current.inputRight, accuracy: 0.000002)
        expectEqual(saved.outputLeft, current.outputLeft, accuracy: 0.000002)
        expectEqual(saved.outputRight, current.outputRight, accuracy: 0.000002)
        expectEqual(saved.activeCells, current.activeCells)
        expectEqual(saved.state, current.state)
        expectEqual(saved.eaten, current.eaten)
        expectEqual(saved.position[0], current.position[0], accuracy: 0.001)
        expectEqual(saved.position[1], current.position[1], accuracy: 0.001)
        expectEqual(saved.heading, current.heading, accuracy: 0.0001)
        expectEqual(saved.food.count, current.food.count)
        for (a, b) in zip(saved.food.flatMap { $0 }, current.food.flatMap { $0 }) {
            expectEqual(a, b, accuracy: 0.001)
        }
        raw.withUnsafeBytes { bytes in
            for cell in reading.rates.indices {
                let bits = bytes.loadUnaligned(fromByteOffset: (i * data.ids.count + cell) * 4, as: UInt32.self)
                let value = Float(bitPattern: UInt32(littleEndian: bits))
                let difference = abs(value - reading.rates[cell])
                if !value.isFinite { failures += 1 }
                maximumError = max(maximumError, difference)
            }
        }
        if i < ActivityDemo.foodFrame { expectEqual(reading.activeCells, 0) }
        if i == ActivityDemo.foodFrame + 20 { expectGreater(reading.output, 0.01) }
    }
    expectAtMost(maximumError, Float(0.000002))
    expectEqual(demo.world.eaten, 1)
    print("Checked \(ActivityDemo.frames * data.ids.count) cell values. Largest difference: \(maximumError).")
    print("Checked GIF timing, food response, fly state, and file hashes.")
}
