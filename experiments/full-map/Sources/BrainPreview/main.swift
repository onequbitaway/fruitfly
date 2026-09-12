import AppKit
import BrainCore
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
func argument(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}
let bundledData = Bundle.main.resourceURL?.appendingPathComponent("Data")
let localData = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Data")
let dataFolder =
    argument("--data").map { URL(fileURLWithPath: $0) }
    ?? (bundledData.flatMap {
        FileManager.default.fileExists(atPath: $0.appendingPathComponent("network.bin").path) ? $0 : nil
    } ?? localData)
let app = NSApplication.shared
app.setActivationPolicy(.regular)
if let output = argument("--export-icon") {
    do {
        try exportIcon(to: URL(fileURLWithPath: output))
        exit(0)
    } catch {
        fputs("Could not export icon: \(error)\n", stderr)
        exit(1)
    }
}
let controller = PreviewController(folder: dataFolder)
let view = PreviewView(controller: controller)
let window = NSWindow(
    contentRect: view.bounds, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
    defer: false)
window.title = "Fruitfly Preview"
window.contentView = view
window.minSize = NSSize(width: 1200, height: 810)
window.center()
window.backgroundColor = Ink.background
let menu = NSMenu()
let item = NSMenuItem()
menu.addItem(item)
let sub = NSMenu()
item.submenu = sub
sub.addItem(withTitle: "Quit Fruitfly Preview", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
app.mainMenu = menu
final class Delegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
let delegate = Delegate()
app.delegate = delegate
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
if let output = argument("--record-desktop") {
    DispatchQueue.main.async {
        do {
            try recordDesktop(
                folder: dataFolder, output: URL(fileURLWithPath: output),
                brainGIF: argument("--brain-gif").map { URL(fileURLWithPath: $0) })
            app.terminate(nil)
        } catch {
            fputs("Desktop recording failed: \(error)\n", stderr)
            exit(1)
        }
    }
} else if let output = argument("--record") {
    view.recorded = true
    DispatchQueue.main.async {
        do {
            try recordPreview(
                folder: dataFolder, output: URL(fileURLWithPath: output), controller: controller, view: view)
            app.terminate(nil)
        } catch {
            fputs("Recording failed: \(error)\n", stderr)
            exit(1)
        }
    }
} else if args.contains("--smoke-tests") {
    smoke(controller)
} else {
    controller.start()
}
app.run()
