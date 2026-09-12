import AppKit

let app = NSApplication.shared
if let i = CommandLine.arguments.firstIndex(of: "--record-activity") {
    guard i + 2 < CommandLine.arguments.count else {
        fputs("Usage: Fruitfly --record-activity OUTPUT_DIRECTORY SOURCE_ROOT\n", stderr); exit(1)
    }
    do { try ActivityRecorder.save(to: CommandLine.arguments[i + 1], sourceRoot: CommandLine.arguments[i + 2]) }
    catch { fputs("Recording failed: \(error)\n", stderr); exit(1) }
    exit(0)
}
if let i = CommandLine.arguments.firstIndex(of: "--export-icon"), i + 1 < CommandLine.arguments.count {
    do { try PreviewRenderer.saveIcon(to: CommandLine.arguments[i + 1]) }
    catch { fputs("Icon failed: \(error)\n", stderr); exit(1) }
    exit(0)
}
let delegate = AppDelegate()
app.delegate = delegate
app.run()
