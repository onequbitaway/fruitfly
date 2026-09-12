import AVFoundation
import AppKit
import BrainCore
import ImageIO
import UniformTypeIdentifiers

private enum Desk {
    static let ink = NSColor(srgbRed: 0.16, green: 0.22, blue: 0.31, alpha: 1)
    static let muted = NSColor(srgbRed: 0.39, green: 0.46, blue: 0.55, alpha: 1)
    static let bounds = CGRect(x: 0, y: 0, width: 1280, height: 800)
    static func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: 90 + x * 4, y: 80 + y * 2.5) }
    static func round(_ ctx: CGContext, _ rect: CGRect, _ radius: CGFloat, _ color: NSColor) {
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
    }
    static func text(
        _ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat = 14, _ color: NSColor = ink,
        _ weight: NSFont.Weight = .regular
    ) { Ink.label(s, x, y, size, color, weight) }
    static func window(_ ctx: CGContext, _ rect: CGRect, _ title: String) {
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -9), blur: 26, color: NSColor.black.withAlphaComponent(0.14).cgColor)
        round(ctx, rect, 12, NSColor(srgbRed: 0.985, green: 0.99, blue: 1, alpha: 1))
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil))
        ctx.clip()
        ctx.setFillColor(NSColor(srgbRed: 0.94, green: 0.96, blue: 0.98, alpha: 1).cgColor)
        ctx.fill(CGRect(x: rect.minX, y: rect.maxY - 44, width: rect.width, height: 44))
        ctx.restoreGState()
        for (i, c) in [NSColor.systemRed, NSColor.systemYellow, NSColor.systemGreen].enumerated() {
            ctx.setFillColor(c.withAlphaComponent(0.8).cgColor)
            ctx.fillEllipse(in: CGRect(x: rect.minX + 17 + CGFloat(i) * 20, y: rect.maxY - 28, width: 12, height: 12))
        }
        text(title, rect.minX + 103, rect.maxY - 29, 14, ink, .medium)
    }
    static func background() -> CGImage {
        let ctx = CGContext(
            data: nil, width: 1280, height: 800, bitsPerComponent: 8, bytesPerRow: 5120,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        let colors = [
            NSColor(srgbRed: 0.63, green: 0.77, blue: 0.93, alpha: 1).cgColor,
            NSColor(srgbRed: 0.89, green: 0.9, blue: 0.97, alpha: 1).cgColor,
        ]
        ctx.drawLinearGradient(
            CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!,
            start: CGPoint(x: 100, y: 0), end: CGPoint(x: 950, y: 800),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        // Original, drawn wallpaper. No personal desktop or external app is captured.
        let hill = CGMutablePath()
        hill.move(to: CGPoint(x: 0, y: 0))
        hill.addLine(to: CGPoint(x: 0, y: 210))
        hill.addCurve(
            to: CGPoint(x: 1280, y: 230), control1: CGPoint(x: 430, y: 600), control2: CGPoint(x: 680, y: -80))
        hill.addLine(to: CGPoint(x: 1280, y: 0))
        hill.closeSubpath()
        ctx.addPath(hill)
        ctx.setFillColor(NSColor(srgbRed: 0.54, green: 0.7, blue: 0.87, alpha: 0.32).cgColor)
        ctx.fillPath()
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.36).cgColor)
        ctx.fill(CGRect(x: 0, y: 768, width: 1280, height: 32))
        text("●", 23, 777, 15, ink)
        text("Finder", 52, 777, 13, ink, .semibold)
        for (s, x) in [("File", 113.0), ("Edit", 154), ("View", 198), ("Go", 247), ("Window", 282), ("Help", 357)] {
            text(s, x, 778, 12)
        }
        text("Sat  9:41", 1179, 778, 12)
        text("Your desktop has a new resident.", 59, 669, 43, ink, .semibold)
        text("A fly pet with a full-map brain model.", 62, 637, 20, muted)
        let notes = CGRect(x: 57, y: 223, width: 654, height: 348)
        window(ctx, notes, "Notes")
        ctx.setFillColor(NSColor(srgbRed: 0.955, green: 0.955, blue: 0.94, alpha: 1).cgColor)
        ctx.fill(CGRect(x: notes.minX + 1, y: notes.minY + 12, width: 150, height: notes.height - 56))
        round(
            ctx, CGRect(x: 68, y: 468, width: 128, height: 33), 7,
            NSColor(srgbRed: 0.93, green: 0.85, blue: 0.6, alpha: 0.54))
        text("Today", 83, 478, 13, ink, .medium)
        text("Ideas", 83, 438, 13, muted)
        text("Weekend", 83, 402, 13, muted)
        text("A small plan", 237, 476, 28, ink, .semibold)
        for (s, y) in [("Finish one thing.", 431.0), ("Take a walk.", 392), ("Feed the fly.", 353)] {
            ctx.setStrokeColor(NSColor(srgbRed: 0.68, green: 0.72, blue: 0.76, alpha: 1).cgColor)
            ctx.setLineWidth(1.2)
            ctx.strokeEllipse(in: CGRect(x: 238, y: y + 2, width: 15, height: 15))
            text(s, 266, y, 18)
        }
        text("One very small distraction is allowed.", 237, 284, 13, muted)
        let files = CGRect(x: 708, y: 170, width: 514, height: 342)
        window(ctx, files, "Projects")
        text("Name", 738, 444, 11, muted)
        text("Kind", 1067, 444, 11, muted)
        for (i, row) in [("fruitfly", "Folder"), ("Weekend photos", "Folder"), ("Reading list", "Document")]
            .enumerated()
        {
            let y = 410 - CGFloat(i) * 47
            if i == 0 {
                round(
                    ctx, CGRect(x: 721, y: y - 6, width: 488, height: 36), 5,
                    NSColor(srgbRed: 0.9, green: 0.94, blue: 0.98, alpha: 1))
            }
            if i < 2 {
                round(
                    ctx, CGRect(x: 739, y: y + 2, width: 24, height: 17), 3,
                    NSColor(srgbRed: 0.38, green: 0.7, blue: 0.91, alpha: 1))
                round(
                    ctx, CGRect(x: 740, y: y + 17, width: 11, height: 5), 2,
                    NSColor(srgbRed: 0.42, green: 0.76, blue: 0.97, alpha: 1))
            } else {
                round(
                    ctx, CGRect(x: 741, y: y - 1, width: 18, height: 23), 2,
                    NSColor(srgbRed: 0.83, green: 0.87, blue: 0.92, alpha: 1))
            }
            text(row.0, 778, y + 1, 14)
            text(row.1, 1067, y + 2, 12, muted)
        }
        text("3 items", 934, 185, 10, muted)
        // A small dock makes the desktop context readable in a mobile feed.
        round(ctx, CGRect(x: 419, y: 42, width: 442, height: 66), 18, NSColor.white.withAlphaComponent(0.39))
        for i in 0..<6 {
            let r = CGRect(x: 435 + CGFloat(i) * 70, y: 52, width: 46, height: 46)
            let colors = [
                NSColor.systemBlue, NSColor.systemYellow, NSColor.white, NSColor.systemTeal, NSColor.darkGray,
                NSColor.systemOrange,
            ]
            round(ctx, r, 10, colors[i].withAlphaComponent(0.9))
            if i == 5 {
                FlyPainter.draw(
                    in: ctx, at: CGPoint(x: r.midX, y: r.midY), heading: .pi / 2, time: 0, scale: 1.3, flying: false)
            } else if i == 0 {
                text("☺", r.minX + 8, r.minY + 8, 28, NSColor.white)
            } else if i == 1 {
                for k in 0..<3 {
                    ctx.setFillColor(ink.withAlphaComponent(0.3).cgColor)
                    ctx.fill(CGRect(x: r.minX + 10, y: r.minY + 10 + CGFloat(k) * 8, width: 27, height: 2))
                }
            } else if i == 2 {
                text("12", r.minX + 8, r.minY + 9, 24, ink, .medium)
            } else if i == 3 {
                text("↗", r.minX + 10, r.minY + 7, 29, NSColor.white)
            } else {
                text(">_", r.minX + 7, r.minY + 12, 21, NSColor.white, .medium)
            }
        }
        text("Staged desktop • Full-map prototype • Guided movement", 29, 16, 11, ink)
        text("github.com/onequbitaway/fruitfly", 1012, 16, 11, ink)
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()!
    }
    static func cursor(_ ctx: CGContext, at p: CGPoint, alpha: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: p.x, y: p.y)
        ctx.setAlpha(alpha)
        ctx.setShadow(
            offset: CGSize(width: 1, height: -2), blur: 3, color: NSColor.black.withAlphaComponent(0.25).cgColor)
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 1, y: -26))
        path.addLine(to: CGPoint(x: 7, y: -19))
        path.addLine(to: CGPoint(x: 13, y: -30))
        path.addLine(to: CGPoint(x: 18, y: -27))
        path.addLine(to: CGPoint(x: 12, y: -17))
        path.addLine(to: CGPoint(x: 22, y: -16))
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(1.8)
        ctx.drawPath(using: .fillStroke)
        ctx.restoreGState()
    }
    static func draw(
        _ ctx: CGContext, background: CGImage, trial: Trial, previous: Trial, snapshot: BrainSnapshot, frame: Int,
        part: Int
    ) {
        ctx.draw(background, in: bounds)
        let alpha = Double(part + 1) / 3
        let t = Double(frame) / 10 + Double(part) / 30
        let x = previous.x + (trial.x - previous.x) * alpha
        let y = previous.y + (trial.y - previous.y) * alpha
        var angle = trial.heading - previous.heading
        angle = atan2(sin(angle), cos(angle))
        let heading = previous.heading + angle * alpha
        let landed = trial.atFood
        let fly = point(x, y)
        if let fx = trial.foodX, let fy = trial.foodY {
            ctx.saveGState()
            let p = point(fx, fy)
            ctx.translateBy(x: p.x, y: p.y)
            ctx.scaleBy(x: 2.8, y: 2.8)
            FlyPainter.crumb(in: ctx, at: .zero, amount: trial.foodAmount / 0.1, age: max(0, t - 1.2))
            ctx.restoreGState()
        }
        if t >= 0.6 && t < 2.4 {
            let a = min(1, max(0, (t - 0.6) / 0.6))
            let smooth = a * a * (3 - 2 * a)
            let target = point(228, 118)
            cursor(
                ctx, at: CGPoint(x: target.x + 100 * (1 - smooth), y: target.y + 135 * (1 - smooth)),
                alpha: t > 2 ? CGFloat((2.4 - t) / 0.4) : 1)
        }
        FlyPainter.draw(
            in: ctx, at: fly, heading: atan2(sin(heading) * 2.5, cos(heading) * 4), time: t, scale: 2.8,
            flying: !landed, eating: trial.phase.hasPrefix("Eating"))
        let status =
            trial.meals > 0
            ? "Crumb gone. Back to exploring."
            : (landed
                ? "It lands beside the crumb."
                : (frame >= 12 ? "Drop a crumb. It comes over." : "A little life above your windows."))
        round(ctx, CGRect(x: 58, y: 118, width: 631, height: 65), 13, NSColor.white.withAlphaComponent(0.82))
        text(status, 78, 150, 18, ink, .medium)
        text(
            "166,700 model cells   •   \(snapshot.activeCells.formatted()) firing   •   MN9: \(Int(snapshot.feedingHz)) Hz",
            78, 130, 12, muted)
    }
}

private final class Movie {
    let writer: AVAssetWriter, input: AVAssetWriterInput, adaptor: AVAssetWriterInputPixelBufferAdaptor
    let width: Int, height: Int
    init(url: URL, width: Int, height: Int) throws {
        self.width = width
        self.height = height
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 5_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoMaxKeyFrameIntervalKey: 30,
                ],
            ])
        input.expectsMediaDataInRealTime = false
        adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)
    }
    func append(_ image: CGImage, frame: Int) throws {
        let start = ProcessInfo.processInfo.systemUptime
        while !input.isReadyForMoreMediaData {
            if writer.status == .failed { throw writer.error ?? CocoaError(.fileWriteUnknown) }
            if ProcessInfo.processInfo.systemUptime - start > 20 { throw CocoaError(.fileWriteUnknown) }
            Thread.sleep(forTimeInterval: 0.001)
        }
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer) == kCVReturnSuccess,
            let pixel = buffer
        else { throw CocoaError(.fileWriteOutOfSpace) }
        CVPixelBufferLockBaseAddress(pixel, [])
        let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pixel), width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixel), space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(pixel, [])
        guard adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)) else {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
    }
    func finish(frames: Int) throws {
        writer.endSession(atSourceTime: CMTime(value: Int64(frames), timescale: 30))
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        guard done.wait(timeout: .now() + 30) == .success, writer.status == .completed else {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
    }
}
private func desktopPNG(_ image: CGImage, _ url: URL) throws {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
}
func recordDesktop(folder: URL, output: URL, brainGIF: URL?) throws {
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let model = try BrainModel(folder: folder, mode: .full)
    let background = Desk.background()
    let movie = try Movie(url: output.appendingPathComponent("fruitfly-desktop-full-map.mp4"), width: 1280, height: 800)
    let combined = try brainGIF.map { _ in
        try Movie(url: output.appendingPathComponent("fruitfly-desktop-and-brain.mp4"), width: 1280, height: 800)
    }
    let frames = 120
    let gif = CGImageDestinationCreateWithURL(
        output.appendingPathComponent("fruitfly-desktop-full-map.gif") as CFURL, UTType.gif.identifier as CFString,
        frames, nil)!
    CGImageDestinationSetProperties(
        gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    var trial = Trial()
    trial.x = 40
    trial.y = 120
    var rates = Data()
    var states: [[String: Any]] = []
    for frame in 0..<frames {
        if frame == 12 {
            trial.dropFood(x: 228, y: 118)
            trial.foodAmount = 0.1
        }
        let previous = trial
        let input = trial.input()
        let snapshot = try model.advance(input)
        trial.advance(snapshot, mode: .full)
        for part in 0..<3 {
            try autoreleasepool {
                let ctx = CGContext(
                    data: nil, width: 1280, height: 800, bitsPerComponent: 8, bytesPerRow: 5120,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
                Desk.draw(
                    ctx, background: background, trial: trial, previous: previous, snapshot: snapshot, frame: frame,
                    part: part)
                NSGraphicsContext.restoreGraphicsState()
                let image = ctx.makeImage()!
                try movie.append(image, frame: frame * 3 + part)
                try combined?.append(image, frame: frame * 3 + part)
                if part == 2 {
                    let small = CGContext(
                        data: nil, width: 960, height: 600, bitsPerComponent: 8, bytesPerRow: 3840,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                    small.interpolationQuality = .high
                    small.draw(image, in: CGRect(x: 0, y: 0, width: 960, height: 600))
                    CGImageDestinationAddImage(
                        gif, small.makeImage()!,
                        [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]] as CFDictionary)
                    if [0, 12, 25, 48, 90, 119].contains(frame) {
                        try desktopPNG(image, output.appendingPathComponent("desktop-\(frame).png"))
                    }
                }
            }
        }
        snapshot.rates.withUnsafeBytes { rates.append(contentsOf: $0) }
        let state = try JSONSerialization.jsonObject(with: JSONEncoder().encode(trial))
        let inputJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(input))
        states.append([
            "frame": frame, "modelSeconds": snapshot.time, "activeCells": snapshot.activeCells,
            "MN9Hz": snapshot.feedingHz, "DNa02LeftHz": snapshot.steeringLeftHz,
            "DNa02RightHz": snapshot.steeringRightHz, "groupActive": snapshot.groupActive,
            "groupMeanHz": snapshot.groupMeanHz, "input": inputJSON, "trial": state,
        ])
        if frame % 30 == 0 {
            print("Desktop frames", frame, "phase", trial.phase, "food", trial.foodAmount)
            fflush(stdout)
        }
    }
    try movie.finish(frames: frames * 3)
    guard CGImageDestinationFinalize(gif) else { throw CocoaError(.fileWriteUnknown) }
    if let brainGIF, let combined {
        let source = CGImageSourceCreateWithURL(brainGIF as CFURL, nil)!
        for i in 0..<CGImageSourceGetCount(source) {
            try autoreleasepool {
                let picture = CGImageSourceCreateImageAtIndex(source, i, nil)!
                let ctx = CGContext(
                    data: nil, width: 1280, height: 800, bitsPerComponent: 8, bytesPerRow: 5120,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                ctx.setFillColor(Ink.background.cgColor)
                ctx.fill(Desk.bounds)
                let width = CGFloat(picture.width) * 800 / CGFloat(picture.height)
                ctx.draw(picture, in: CGRect(x: (1280 - width) / 2, y: 0, width: width, height: 800))
                let result = ctx.makeImage()!
                for k in 0..<3 { try combined.append(result, frame: frames * 3 + i * 3 + k) }
            }
        }
        try combined.finish(frames: frames * 3 + CGImageSourceGetCount(source) * 3)
    }
    try rates.write(to: output.appendingPathComponent("desktop-rates.f32"))
    let trace: [String: Any] = [
        "mode": "Full map", "cells": model.cells, "connections": model.connections, "seed": 7,
        "modelStepMilliseconds": 0.2, "modelFrames": frames, "modelSecondsPerFrame": 0.1, "videoFPS": 30, "gifFPS": 10,
        "foodDropBeforeFrame": 12, "startingPortion": 0.1,
        "scene":
            "Drawn desktop and cursor. No screen recording. Sprite positions interpolate between actual trial steps. Movement remains guided. Food use reads actual MN9 output. The crumb drawing shows the remaining fraction of its initial 0.1 portion.",
        "combinedVideo":
            "A 12-second desktop trial followed by the earlier separate 8-second full-map recording. The model time restarts at the cut.",
        "rateFormat": "Little-endian Float32 rates in model-frame order, then Data/neurons.json cell order",
        "frames": states,
    ]
    try JSONSerialization.data(withJSONObject: trace, options: [.prettyPrinted, .sortedKeys]).write(
        to: output.appendingPathComponent("desktop-trace.json"))
    print("Saved desktop MP4, GIF, stills, and all model rates. Meals:", trial.meals)
}
