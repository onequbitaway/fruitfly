import AppKit
import DuelCore

let args = CommandLine.arguments
func argument(_ key: String) -> String? {
  guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
  return args[i + 1]
}
let folder =
  argument("--data").map { URL(fileURLWithPath: $0) }
  ?? Bundle.main.resourceURL!.appendingPathComponent("Data")
let app = NSApplication.shared
if let output = argument("--export-icon") {
  do {
    try exportIcon(to: URL(fileURLWithPath: output))
    exit(0)
  } catch {
    fputs("Icon failed: \(error)\n", stderr)
    exit(1)
  }
}
if let output = argument("--record") {
  do {
    try record(
      folder: folder, output: URL(fileURLWithPath: output),
      mode: args.contains("--simple") ? .simple : .full)
    exit(0)
  } catch {
    fputs("Recording failed: \(error)\n", stderr)
    exit(1)
  }
}
if args.contains("--smoke-test") {
  do {
    for mode: DuelMode in [.simple, .full] {
      let duel = try Duel(folder: folder, mode: mode)
      let frame = try duel.advance()
      _ = try render(frame: frame, mode: mode)
      guard frame.activity.count == 2, frame.activity.allSatisfy({ $0.activeCells > 0 }) else {
        fatalError("Empty brain output")
      }
      print("Packaged app: \(mode.rawValue) passed")
    }
    exit(0)
  } catch {
    fputs("App check failed: \(error)\n", stderr)
    exit(1)
  }
}
app.setActivationPolicy(.regular)
let controller = DuelController(folder: folder)
if args.contains("--simple") { controller.mode = .simple }
let view = DuelView(controller: controller)
let window = NSWindow(
  contentRect: view.bounds, styleMask: [.titled, .closable, .miniaturizable, .resizable],
  backing: .buffered, defer: false)
window.title = "Fruitfly Duel"
window.appearance = NSAppearance(named: .aqua)
window.contentView = view
window.contentMinSize = NSSize(width: 960, height: 675)
window.setContentSize(NSSize(width: 1152, height: 810))
window.backgroundColor = Palette.paper
window.center()
let menu = NSMenu()
let item = NSMenuItem()
let appMenu = NSMenu()
menu.addItem(item)
item.submenu = appMenu
appMenu.addItem(
  withTitle: "Quit Fruitfly Duel", action: #selector(NSApplication.terminate(_:)),
  keyEquivalent: "q")
app.mainMenu = menu
final class Delegate: NSObject, NSApplicationDelegate {
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
let delegate = Delegate()
app.delegate = delegate
window.makeKeyAndOrderFront(nil)
window.makeFirstResponder(view)
app.activate(ignoringOtherApps: true)
controller.start()
app.run()
