import AppKit
import BrainCore
import ImageIO
import UniformTypeIdentifiers

private func capture(_ view: PreviewView) -> CGImage? {
    view.layoutSubtreeIfNeeded()
    view.displayIfNeeded()
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width), pixelsHigh: Int(view.bounds.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    view.cacheDisplay(in: view.bounds, to: rep)
    return rep.cgImage
}
private func png(_ image: CGImage, _ url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
}
func recordPreview(folder: URL, output: URL, controller: PreviewController, view: PreviewView) throws {
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let model = try BrainModel(folder: folder, mode: .full)
    var trial = Trial()
    var history: [TracePoint] = []
    var rates = Data()
    var events: [[String: Any]] = []
    let gifURL = output.appendingPathComponent("full-map-food.gif")
    guard let gif = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, 80, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationSetProperties(
        gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for frame in 0..<80 {
        if frame == 10 { trial.dropFood() }
        let s = try model.advance(trial.input())
        trial.advance(s, mode: .full)
        history.append(TracePoint(s))
        controller.displayRecorded(
            model: model, snapshot: s, trial: trial,
            label: frame < 10 ? "No input" : "Food trial · smell and contact taste", history: history)
        guard let picture = capture(view) else { throw CocoaError(.fileWriteUnknown) }
        if [9, 19, 39, 79].contains(frame) { try png(picture, output.appendingPathComponent("food-\(frame).png")) }
        CGImageDestinationAddImage(
            gif, picture, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]] as CFDictionary)
        s.rates.withUnsafeBytes { rates.append(contentsOf: $0) }
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(s.inputs))
        events.append([
            "frame": frame, "modelSeconds": s.time, "input": encoded, "directCells": s.directCells,
            "activeCells": s.activeCells, "groupMeanHz": s.groupMeanHz, "groupActive": s.groupActive,
            "MN9Hz": s.feedingHz, "DNa02LeftHz": s.steeringLeftHz, "DNa02RightHz": s.steeringRightHz,
            "foodLeft": trial.foodAmount, "phase": trial.phase,
        ])
    }
    guard CGImageDestinationFinalize(gif) else { throw CocoaError(.fileWriteUnknown) }
    try rates.write(to: output.appendingPathComponent("food-rates.f32"))
    let manifest: [String: Any] = [
        "seed": 7, "mode": "Full map", "cellCount": model.cells, "frameCount": 80, "secondsPerFrame": 0.1,
        "rateFormat": "Little-endian Float32, frame-major; cell order is Data/neurons.json ids",
        "modelStepMilliseconds": 0.2,
        "note":
            "Calculated model spikes. Guided approach. Food use reads MN9; no direct feeding-pathway input in this trial.",
        "frames": events,
    ]
    try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]).write(
        to: output.appendingPathComponent("food-trace.json"))
    for (name, input) in [
        ("smell", BrainInput(odorLeft: 120, odorRight: 80)), ("taste", BrainInput(taste: 150)),
        ("visual", BrainInput(visualLeft: 140, visualRight: 30)), ("feeding", BrainInput(feeding: 150)),
    ] {
        model.reset()
        history = []
        var s = model.snapshot()
        for _ in 0..<10 {
            s = try model.advance(input)
            history.append(TracePoint(s))
        }
        controller.displayRecorded(
            model: model, snapshot: s, trial: Trial(), label: "\(name.capitalized) test · direct stimulation",
            history: history)
        try png(capture(view)!, output.appendingPathComponent("test-\(name).png"))
    }
    let simple = try BrainModel(folder: folder, mode: .simple, useGPU: false)
    history = []
    var s = simple.snapshot()
    for _ in 0..<10 {
        s = try simple.advance(BrainInput(odorLeft: 120, odorRight: 80))
        history.append(TracePoint(s))
    }
    controller.displayRecorded(
        model: simple, snapshot: s, trial: Trial(), label: "Smell test · direct stimulation", history: history)
    try png(capture(view)!, output.appendingPathComponent("simple.png"))
    print("Saved 80 recorded frames and four independent input tests to \(output.path)")
}
