import Foundation
import CryptoKit
import BrainCore

// One process owns one brain. stdout is a versioned JSON-lines protocol.
struct Request: Decodable {
    let id: Int
    let command: String
    var seed: UInt64?
    var input: BrainInput?
    var fullRates: Bool?
}
func send(_ value: [String: Any]) throws {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([10]))
}
func failure(_ text: String) -> NSError {
    NSError(domain: "FlyPilot", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
}
do {
    let args = CommandLine.arguments
    guard args.count >= 3, ["full", "simple"].contains(args[2]) else {
        throw failure("Usage: FlyBrainService DATA_FOLDER full|simple [--cpu]")
    }
    let brain = try BrainModel(folder: URL(fileURLWithPath: args[1]),
        mode: args[2] == "full" ? .full : .simple, useGPU: !args.contains("--cpu"))
    let m = brain.metadata
    let channel = brain.mode == .full ? "visual" : "odor"
    let left = (m.channels[channel] ?? []).filter { m.sides[$0] == -1 }
    let right = (m.channels[channel] ?? []).filter { m.sides[$0] == 1 }
    let known = m.positions.indices.filter { m.positions[$0] != nil }
    let plot = stride(from: 0, to: known.count, by: max(1, known.count / 2400)).map { known[$0] }
    let direct = Set(m.channels.values.flatMap { $0 })
    let downstream = m.groupNames.indices.map { group in
        m.groups.indices.filter { m.groups[$0] == group && !direct.contains($0) }
    }
    let featureNames = [channel + "LeftHz", channel + "RightHz", "DNa02LeftHz", "DNa02RightHz"]
        + m.groupNames.map { "downstream:" + $0 }
    try send(["protocol": 1, "ready": true, "mode": args[2], "cells": brain.cells,
        "connections": brain.connections, "contacts": brain.contacts, "processor": brain.processor,
        "stepSeconds": 0.1, "channels": m.channels, "featureNames": featureNames,
        "plot": plot.map { ["index": $0, "id": String(m.ids[$0]), "position": m.positions[$0]!,
            "group": m.groups[$0]] as [String: Any] }, "groupNames": m.groupNames,
        "positionedCells": known.count])
    while let line = readLine() {
        var id = -1
        do {
            guard line.utf8.count < 16384 else { throw failure("Request is too large.") }
            let r = try JSONDecoder().decode(Request.self, from: Data(line.utf8))
            id = r.id
            if r.command == "quit" { try send(["id": id, "ok": true]); break }
            if r.command == "reset" { brain.reset(seed: r.seed ?? 7) }
            let s: BrainSnapshot
            switch r.command {
            case "step":
                guard let input = r.input else { throw failure("Step needs input rates.") }
                guard [input.odorLeft,input.odorRight,input.taste,input.visualLeft,input.visualRight,input.feeding]
                    .allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 200 }) else {
                    throw failure("Input rates must be from 0 to 200 Hz.")
                }
                s = try brain.advance(input)
            case "reset", "snapshot": s = brain.snapshot()
            default: throw failure("Unknown command.")
            }
            func mean(_ indices: [Int]) -> Double {
                indices.reduce(0.0) { $0 + Double(s.rates[$1]) } / Double(max(1, indices.count))
            }
            let bytes = s.rates.withUnsafeBytes { Data($0) }
            var result: [String: Any] = ["id": id, "ok": true, "time": s.time,
                "activeCells": s.activeCells, "totalSpikes": s.totalSpikes,
                "calculationSeconds": s.computationSeconds,
                "features": [mean(left), mean(right), Double(s.steeringLeftHz), Double(s.steeringRightHz)]
                    + downstream.map { mean($0) },
                "plotRates": plot.map { s.rates[$0] }, "groupMeanHz": s.groupMeanHz,
                "rateHash": SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()]
            if r.fullRates == true { result["ratesF32LE"] = bytes.base64EncodedString() }
            try send(result)
        } catch { try send(["id": id, "ok": false, "error": error.localizedDescription]) }
    }
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    exit(1)
}
