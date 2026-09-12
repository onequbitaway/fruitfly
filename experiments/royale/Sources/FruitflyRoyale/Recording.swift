import AVFoundation
import AppKit
import ImageIO
import RoyaleCore
import UniformTypeIdentifiers

struct ReplaySample: Codable {
    let modelTime: Double
    let flies: [Fighter]
    let activity: [FlyActivity]
    let ringRadius: Double
    let hits: [Hit]
    let events: [ArenaEvent]
}

func render(frame: FleetFrame, mode: FleetMode, blood: Bool = true) throws -> CGImage {
    let width = Int(ArenaPainter.size.width)
    let height = Int(ArenaPainter.size.height)
    guard
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else {
        throw NSError(domain: "RoyaleRecording", code: 1)
    }
    ctx.translateBy(x: 0, y: CGFloat(height))
    ctx.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    ArenaPainter.draw(
        ctx, frame: frame, mode: mode, selected: frame.arena.winner ?? 2,
        blood: blood, paused: false, status: "Replay")
    ArenaPainter.text("Recorded round  •  3× model time", 48, 132, 14, color: Palette.muted, bold: true)
    ArenaPainter.text(mode.rawValue, 532, 130, 16, color: Palette.ink, bold: true)
    NSGraphicsContext.restoreGraphicsState()
    return ctx.makeImage()!
}

func savePNG(_ image: CGImage, to path: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(path as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
        throw NSError(domain: "RoyaleRecording", code: 2)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "RoyaleRecording", code: 3) }
}

func record(folder: URL, output: URL, mode: FleetMode) throws {
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let fleet = try BrainFleet(folder: folder, mode: mode)
    let gifURL = output.appendingPathComponent("fruitfly-royale.gif")
    guard let gif = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, 0, nil) else {
        throw NSError(domain: "RoyaleRecording", code: 4)
    }
    CGImageDestinationSetProperties(
        gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    var samples: [ReplaySample] = []
    var frame = fleet.frame()
    var bestHits = 0
    var bloodChangedPixels = 0
    let movieURL = output.appendingPathComponent("fruitfly-royale.mp4")
    if FileManager.default.fileExists(atPath: movieURL.path) { try FileManager.default.removeItem(at: movieURL) }
    let writer = try AVAssetWriter(outputURL: movieURL, fileType: .mp4)
    let input = AVAssetWriterInput(
        mediaType: .video,
        outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1280, AVVideoHeightKey: 900,
        ])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: 1280, kCVPixelBufferHeightKey as String: 900,
        ])
    writer.add(input)
    guard writer.startWriting() else { throw writer.error! }
    writer.startSession(atSourceTime: .zero)
    for index in 0..<340 {
        // Three calculated 100 ms samples per displayed frame. The replay
        // clearly labels this acceleration. No sampled activity is invented.
        if !frame.arena.complete {
            for _ in 0..<3 { frame = try fleet.advance() }
        }
        samples.append(
            ReplaySample(
                modelTime: frame.arena.time, flies: frame.arena.flies,
                activity: frame.activity, ringRadius: frame.arena.radius, hits: frame.arena.hits,
                events: frame.arena.events))
        let image = try render(frame: frame, mode: mode)
        if bloodChangedPixels == 0, frame.arena.hits.contains(where: { frame.arena.time - $0.time > 0.2 }) {
            let before = fleet.models.map { BrainFleet.hash($0.snapshot().rates) }
            let withoutBlood = try render(frame: frame, mode: mode, blood: false)
            let on = image.dataProvider!.data! as Data
            let off = withoutBlood.dataProvider!.data! as Data
            for p in stride(from: 0, to: min(on.count, off.count), by: 4) {
                if on[p] != off[p] || on[p + 1] != off[p + 1] || on[p + 2] != off[p + 2] { bloodChangedPixels += 1 }
            }
            guard before == fleet.models.map({ BrainFleet.hash($0.snapshot().rates) }) else {
                throw NSError(
                    domain: "RoyaleRecording", code: 7,
                    userInfo: [NSLocalizedDescriptionKey: "Drawing changed a brain state."])
            }
            if bloodChangedPixels > 0 { try savePNG(withoutBlood, to: output.appendingPathComponent("blood-off.png")) }
        }
        // GIF uses a smaller image; video keeps the native canvas size.
        let thumbnailContext = CGContext(
            data: nil, width: 960, height: 675, bitsPerComponent: 8, bytesPerRow: 960 * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        thumbnailContext.draw(image, in: CGRect(x: 0, y: 0, width: 960, height: 675))
        CGImageDestinationAddImage(
            gif, thumbnailContext.makeImage()!,
            [
                kCGImagePropertyGIFDictionary:
                    [
                        kCGImagePropertyGIFDelayTime: frame.arena.complete ? 1.8 : 0.1,
                        kCGImagePropertyGIFUnclampedDelayTime: frame.arena.complete ? 1.8 : 0.1,
                    ]
            ] as CFDictionary)
        if index == 0 { try savePNG(image, to: output.appendingPathComponent("starting-ring.png")) }
        if frame.arena.hits.count > bestHits {
            bestHits = frame.arena.hits.count
            try savePNG(image, to: output.appendingPathComponent("battle.png"))
        }
        while !input.isReadyForMoreMediaData {
            if writer.status == .failed { throw writer.error! }
            Thread.sleep(forTimeInterval: 0.002)
        }
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer) == kCVReturnSuccess, let buffer
        else {
            throw NSError(domain: "RoyaleRecording", code: 5)
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer), width: 1280, height: 900, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        context.draw(image, in: CGRect(origin: .zero, size: ArenaPainter.size))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: 10)) else {
            throw writer.error!
        }
        if index % 20 == 0 {
            print("Recorded \(mode.rawValue): \(frame.arena.time)s, \(frame.arena.living) alive")
            fflush(stdout)
        }
        if frame.arena.complete {
            try savePNG(image, to: output.appendingPathComponent("winner.png"))
            break
        }
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    guard writer.status == .completed else { throw writer.error! }
    guard CGImageDestinationFinalize(gif) else { throw NSError(domain: "RoyaleRecording", code: 6) }
    guard bloodChangedPixels > 0, frame.arena.complete else {
        throw NSError(
            domain: "RoyaleRecording", code: 8,
            userInfo: [NSLocalizedDescriptionKey: "Recording needs a complete round and visible hit effects."])
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(samples).write(to: output.appendingPathComponent("trace.json"))
    let manifest: [String: Any] = [
        "mode": mode.rawValue, "cellsPerFly": mode.cellsPerFly,
        "flyCount": 10, "seed": 42, "modelSecondsPerVideoSecond": 3, "frames": samples.count,
        "lastModelTime": frame.arena.time, "winner": frame.arena.winner.map { $0 as Any } ?? NSNull(),
        "bloodToggleChangedPixels": bloodChangedPixels, "renderDidNotChangeBrainRates": true,
        "activity": "Actual calculated spike counts. Each fly has separate state.",
        "gameRules": "Movement, combat, blood, health, food healing, and ring closure are programmed.",
    ]
    try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        .write(to: output.appendingPathComponent("manifest.json"))
    print("Saved \(samples.count) frames to \(output.path)")
}
