import AppKit

let app = NSApplication.shared
if let i = CommandLine.arguments.firstIndex(of: "--export-icon"), i + 1 < CommandLine.arguments.count {
    do { try PreviewRenderer.saveIcon(to: CommandLine.arguments[i + 1]) }
    catch { fputs("Icon failed: \(error)\n", stderr); exit(1) }
    exit(0)
}
let delegate = AppDelegate()
app.delegate = delegate
app.run()
