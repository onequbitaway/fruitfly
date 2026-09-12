import AVFoundation
import AppKit
import DuelCore
import ImageIO
import UniformTypeIdentifiers

func render(frame: DuelFrame, mode: DuelMode, blood: Bool = true, replay: Bool = false) throws
  -> CGImage
{
  let ctx = CGContext(
    data: nil, width: 1280, height: 900, bitsPerComponent: 8, bytesPerRow: 1280 * 4,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.translateBy(x: 0, y: 900)
  ctx.scaleBy(x: 1, y: -1)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
  DuelPainter.draw(ctx, frame: frame, mode: mode, blood: blood, replay: replay)
  NSGraphicsContext.restoreGraphicsState()
  return ctx.makeImage()!
}
func savePNG(_ image: CGImage, to url: URL) throws {
  let destination = CGImageDestinationCreateWithURL(
    url as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else {
    throw NSError(domain: "DuelRecording", code: 1)
  }
}
func exportIcon(to folder: URL) throws {
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
      let pixels = size * scale
      let edge = Double(pixels)
      let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: pixels * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      ctx.addPath(
        CGPath(
          roundedRect: CGRect(
            x: edge * 0.04, y: edge * 0.04, width: edge * 0.92, height: edge * 0.92),
          cornerWidth: edge * 0.2, cornerHeight: edge * 0.2, transform: nil))
      ctx.setFillColor(Palette.pond.cgColor)
      ctx.fillPath()
      ctx.translateBy(x: 0, y: edge)
      ctx.scaleBy(x: 1, y: -1)
      DuelPainter.fly(
        ctx, at: CGPoint(x: edge * 0.33, y: edge * 0.4), face: 1, time: 0, air: true, attack: false,
        hurt: false, accent: Palette.blood, scale: edge / 160)
      DuelPainter.fly(
        ctx, at: CGPoint(x: edge * 0.67, y: edge * 0.65), face: -1, time: 0, air: true,
        attack: false, hurt: false, accent: Palette.violet, scale: edge / 160)
      try savePNG(
        ctx.makeImage()!,
        to: folder.appendingPathComponent("icon_\(size)x\(size)\(scale==2 ? "@2x" : "").png"))
    }
  }
}
func record(folder: URL, output: URL, mode: DuelMode) throws {
  try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
  let duel = try Duel(folder: folder, mode: mode)
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  let traceURL = output.appendingPathComponent("trace.ndjson")
  FileManager.default.createFile(atPath: traceURL.path, contents: nil)
  let trace = try FileHandle(forWritingTo: traceURL)
  defer { try? trace.close() }
  let gif = CGImageDestinationCreateWithURL(
    output.appendingPathComponent("fruitfly-duel.gif") as CFURL, UTType.gif.identifier as CFString,
    0, nil)!
  CGImageDestinationSetProperties(
    gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
  let movieURL = output.appendingPathComponent("fruitfly-duel.mp4")
  if FileManager.default.fileExists(atPath: movieURL.path) {
    try FileManager.default.removeItem(at: movieURL)
  }
  let writer = try AVAssetWriter(outputURL: movieURL, fileType: .mp4)
  let input = AVAssetWriterInput(
    mediaType: .video,
    outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 1280, AVVideoHeightKey: 900,
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
  var frame = duel.current
  var frameCount = 0
  var samples = 0
  var hitCount = 0
  var koCount = 0
  var bloodPixels = 0
  for index in 0..<750 {
    for _ in 0..<3 where !frame.match.complete {
      frame = try duel.advance()
      samples += 1
      hitCount += frame.frames.flatMap(\.events).filter { $0.type == "hit" }.count
      koCount += frame.frames.flatMap(\.events).filter { $0.type == "ko" }.count
      try trace.write(contentsOf: encoder.encode(frame))
      try trace.write(contentsOf: Data([10]))
    }
    let image = try render(frame: frame, mode: mode, replay: true)
    if index == 0 { try savePNG(image, to: output.appendingPathComponent("start.png")) }
    if bloodPixels == 0
      && frame.effects.contains(where: { $0.type == "hit" && frame.match.frame - $0.frame < 30 })
    {
      let hashes = duel.models.map { Duel.hash($0.snapshot().rates) }
      let off = try render(frame: frame, mode: mode, blood: false, replay: true)
      let a = image.dataProvider!.data! as Data
      let b = off.dataProvider!.data! as Data
      for p in stride(from: 0, to: min(a.count, b.count), by: 4) {
        if a[p] != b[p] || a[p + 1] != b[p + 1] || a[p + 2] != b[p + 2] { bloodPixels += 1 }
      }
      guard hashes == duel.models.map({ Duel.hash($0.snapshot().rates) }) else {
        throw NSError(domain: "DuelRecording", code: 2)
      }
      if bloodPixels > 0 {
        try savePNG(image, to: output.appendingPathComponent("battle.png"))
        try savePNG(off, to: output.appendingPathComponent("blood-off.png"))
      }
    }
    let thumbnail = CGContext(
      data: nil, width: 768, height: 540, bitsPerComponent: 8, bytesPerRow: 768 * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    thumbnail.draw(image, in: CGRect(x: 0, y: 0, width: 768, height: 540))
    CGImageDestinationAddImage(
      gif, thumbnail.makeImage()!,
      [
        kCGImagePropertyGIFDictionary: [
          kCGImagePropertyGIFDelayTime: frame.match.complete ? 1.8 : 0.1,
          kCGImagePropertyGIFUnclampedDelayTime: frame.match.complete ? 1.8 : 0.1,
        ]
      ] as CFDictionary)
    while !input.isReadyForMoreMediaData {
      if writer.status == .failed { throw writer.error! }
      Thread.sleep(forTimeInterval: 0.002)
    }
    var buffer: CVPixelBuffer?
    guard
      CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
        == kCVReturnSuccess, let buffer
    else { throw NSError(domain: "DuelRecording", code: 3) }
    CVPixelBufferLockBaseAddress(buffer, [])
    let ctx = CGContext(
      data: CVPixelBufferGetBaseAddress(buffer), width: 1280, height: 900, bitsPerComponent: 8,
      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    ctx.draw(image, in: CGRect(origin: .zero, size: DuelPainter.size))
    CVPixelBufferUnlockBaseAddress(buffer, [])
    guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: 10))
    else { throw writer.error! }
    frameCount += 1
    if index % 20 == 0 {
      print("Recorded \(frame.activity[0].time)s: \(hitCount) hits, \(koCount) ring-outs")
      fflush(stdout)
    }
    if frame.match.complete {
      try savePNG(image, to: output.appendingPathComponent("winner.png"))
      break
    }
  }
  input.markAsFinished()
  let done = DispatchSemaphore(value: 0)
  writer.finishWriting { done.signal() }
  done.wait()
  guard writer.status == .completed, CGImageDestinationFinalize(gif), frame.match.complete,
    bloodPixels > 0
  else {
    throw NSError(
      domain: "DuelRecording", code: 4,
      userInfo: [
        NSLocalizedDescriptionKey: "Recording needs a complete match and visible hit effects."
      ])
  }
  let manifest: [String: Any] = [
    "mode": mode.rawValue, "cellsPerFly": mode.cells, "flyCount": 2, "seed": 42,
    "frames": frameCount, "samples": samples, "modelSecondsPerVideoSecond": 3,
    "lastModelTime": frame.activity[0].time, "winner": frame.match.winner ?? -1, "hits": hitCount,
    "ringOuts": koCount, "bloodToggleChangedPixels": bloodPixels,
    "renderDidNotChangeBrainRates": true,
    "engine": "Super Bash Folds, MIT, 1028a3b739ef54efdcbe5a2ef0ad1714fe569c47",
    "activity":
      "Calculated rates from two separate model states. Plot points use real cell positions.",
    "rules":
      "Programmed combat. Rates modulate movement and action timing. This is not learned fly fighting.",
  ]
  try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("manifest.json"))
  print("Saved \(frameCount) frames to \(output.path)")
}
