import AppKit
import SwiftUI
import FlyCore

final class PetController: ObservableObject {
    let world: FlyWorld
    var panels: [DesktopPanel] = []
    var dismissControls: (() -> Void)?
    @Published var paused = false { didSet { world.paused = paused } }
    @Published var hidden = false { didSet { updateVisibility() } }
    @Published var showBrain: Bool { didSet { UserDefaults.standard.set(showBrain, forKey: "showBrain"); refreshAll() } }
    @Published var size: Double { didSet { UserDefaults.standard.set(size, forKey: "flySize"); refreshAll() } }
    @Published var stateName = "Exploring"
    @Published var meals = 0
    @Published var crumbCount = 0
    @Published var activity: Double = 0
    @Published var placingFood = false
    @Published var dataError = false
    private var timer: Timer?
    private var placementTimeout: Timer?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var lastTime = ProcessInfo.processInfo.systemUptime
    private var lastPublished = 0.0
    private var suspended = false
    private var lastFoodClickTime = -1.0
    private var lastFoodClickPoint = Point(-10000, -10000)

    init() {
        let savedSize = UserDefaults.standard.double(forKey: "flySize")
        size = savedSize > 0 ? min(2.2, max(0.8, savedSize)) : 1.3
        showBrain = UserDefaults.standard.bool(forKey: "showBrain")
        let circuit = try? SmellCircuit(data: CircuitData.bundled())
        world = FlyWorld(areas: Self.screenAreas(), seed: UInt64.random(in: 1...UInt64.max), circuit: circuit)
        dataError = circuit == nil
        world.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    static func screenAreas() -> [Area] {
        NSScreen.screens.map { screen in
            let r = screen.visibleFrame
            return Area(x: r.minX, y: r.minY, width: r.width, height: r.height)
        }
    }

    func start() {
        rebuildPanels()
        // Mouse-only monitors do not ask for access to keyboard input.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleFoodShortcut(event)
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if self.placingFood && event.type == .keyDown && event.keyCode == 53 {
                self.endPlacement(); return nil
            }
            if event.type == .leftMouseDown && !self.placingFood { self.handleFoodShortcut(event) }
            return event
        }
        timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.tick() }
        timer?.tolerance = 0.004
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(sleep), name: NSWorkspace.willSleepNotification, object: nil)
        nc.addObserver(self, selector: #selector(sleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        nc.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
        nc.addObserver(self, selector: #selector(wake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        nc.addObserver(self, selector: #selector(accessibilityChanged), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    func stop() {
        timer?.invalidate(); timer = nil
        placementTimeout?.invalidate()
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        for panel in panels { panel.close() }
        panels.removeAll()
    }

    func placeFood() {
        dismissControls?()
        hidden = false
        placingFood = true
        for panel in panels {
            panel.placingFood = true
            panel.ignoresMouseEvents = false
            if let view = panel.contentView as? DesktopView {
                view.placingFood = true
                view.needsDisplay = true
                panel.invalidateCursorRects(for: view)
            }
        }
        let pointer = NSEvent.mouseLocation
        let panel = panels.first { $0.frame.contains(pointer) } ?? panels.first
        panel?.makeKeyAndOrderFront(nil)
        panel?.makeFirstResponder(panel?.contentView)
        placementTimeout?.invalidate()
        placementTimeout = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in self?.endPlacement() }
    }

    func endPlacement() {
        placementTimeout?.invalidate(); placementTimeout = nil
        placingFood = false
        for panel in panels {
            panel.placingFood = false
            panel.ignoresMouseEvents = true
            if panel.isKeyWindow { panel.resignKey() }
            if let view = panel.contentView as? DesktopView {
                view.placingFood = false
                view.needsDisplay = true
                panel.invalidateCursorRects(for: view)
            }
        }
    }

    func dropNearby() {
        let p = world.position + Point(90, -30)
        let area = world.areas.first { $0.contains(world.position) } ?? world.areas[0]
        _ = world.dropFood(at: area.clamp(p, inset: 40))
        hidden = false
        publishState(); refreshAll()
    }

    func clearFood() { world.clearFood(); publishState(); refreshAll() }
    func bringHere() {
        let point = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        if let screen { world.bringHere(Point(screen.visibleFrame.midX, screen.visibleFrame.midY)) }
        hidden = false
        refreshAll()
        dismissControls?()
    }

    private func handleFoodShortcut(_ event: NSEvent) {
        guard !placingFood else { return }
        guard event.modifierFlags.contains(.option) else { lastFoodClickTime = -1; return }
        let nsPoint = NSEvent.mouseLocation
        let point = Point(nsPoint.x, nsPoint.y)
        let now = event.timestamp
        // Some global monitors report clickCount as zero. Count the pair here.
        let isDouble = now - lastFoodClickTime <= NSEvent.doubleClickInterval && point.distance(to: lastFoodClickPoint) < 8
        if isDouble {
            _ = world.dropFood(at: point)
            lastFoodClickTime = -1
            hidden = false
            publishState(); refreshAll()
        } else {
            lastFoodClickTime = now
            lastFoodClickPoint = point
        }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.05, now - lastTime)
        lastTime = now
        guard !suspended, !hidden else { return }
        let mouse = NSEvent.mouseLocation
        world.step(dt: dt, cursor: placingFood ? nil : Point(mouse.x, mouse.y))
        if !paused { for panel in panels { (panel.contentView as? DesktopView)?.refresh() } }
        if now - lastPublished > 0.3 { publishState(); lastPublished = now }
    }
    private func publishState() {
        stateName = world.state.rawValue
        meals = world.eaten
        crumbCount = world.food.count
        activity = world.circuit?.activity ?? 0
    }
    private func refreshAll() {
        for panel in panels {
            if let view = panel.contentView as? DesktopView {
                view.size = size; view.showBrain = showBrain
                view.needsDisplay = true
            }
        }
    }
    private func updateVisibility() {
        if hidden { endPlacement() }
        for panel in panels {
            if hidden { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
        }
    }
    private func rebuildPanels() {
        endPlacement()
        for panel in panels { panel.close() }
        world.setAreas(Self.screenAreas())
        panels = NSScreen.screens.map { screen in
            let panel = DesktopPanel(screen: screen, world: world)
            if let view = panel.contentView as? DesktopView {
                view.size = size; view.showBrain = showBrain
                view.onPlaceFood = { [weak self] point in
                    self?.world.dropFood(at: point)
                    self?.endPlacement()
                    self?.publishState()
                    self?.refreshAll()
                }
                view.onCancel = { [weak self] in self?.endPlacement() }
            }
            if !hidden { panel.orderFrontRegardless() }
            return panel
        }
    }
    @objc private func screensChanged() { rebuildPanels() }
    @objc private func sleep() { suspended = true; endPlacement() }
    @objc private func wake() { lastTime = ProcessInfo.processInfo.systemUptime; suspended = false }
    @objc private func accessibilityChanged() {
        world.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var controller: PetController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let controller = PetController()
        self.controller = controller
        let item = NSStatusBar.system.statusItem(withLength: 30)
        statusItem = item
        item.button?.image = FlyPainter.icon()
        item.button?.toolTip = "Fruitfly — click for food and controls"
        item.button?.setAccessibilityLabel("Fruitfly")
        item.button?.target = self
        item.button?.action = #selector(toggleControls)
        let popover = NSPopover()
        popover.behavior = .transient
        let hosting = NSHostingController(rootView: ControlPanel(controller: controller))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        self.popover = popover
        controller.dismissControls = { [weak popover] in popover?.performClose(nil) }

        if CommandLine.arguments.contains("--render-preview") {
            let args = CommandLine.arguments
            if let i = args.firstIndex(of: "--render-preview"), i + 1 < args.count {
                do { try PreviewRenderer.save(to: args[i + 1], controller: controller) }
                catch { fputs("Preview failed: \(error)\n", stderr); exit(1) }
                NSApp.terminate(nil)
                return
            }
        }
        controller.start()
        if CommandLine.arguments.contains("--smoke-test") {
            controller.dropNearby()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                var valid = !controller.panels.isEmpty && controller.panels.allSatisfy { $0.ignoresMouseEvents }
                    && controller.world.time > 0 && controller.world.circuit != nil
                controller.placeFood()
                valid = valid && controller.panels.allSatisfy { !$0.ignoresMouseEvents }
                    && controller.panels.contains { $0.isKeyWindow }
                if let panel = controller.panels.first, let view = panel.contentView as? DesktopView,
                   let click = NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 150, y: 150),
                        modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                        windowNumber: panel.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1) {
                    let before = controller.world.food.count
                    view.mouseDown(with: click)
                    valid = valid && controller.world.food.count == before + 1
                        && controller.panels.allSatisfy { $0.ignoresMouseEvents }
                } else { valid = false }
                controller.placeFood()
                controller.endPlacement()
                valid = valid && controller.panels.allSatisfy { $0.ignoresMouseEvents }
                controller.hidden = true
                valid = valid && controller.panels.allSatisfy { !$0.isVisible }
                print("App check: \(valid ? "passed" : "failed"); screens: \(controller.panels.count); cells: \(controller.world.circuit?.neuronCount ?? 0)")
                controller.stop()
                exit(valid ? 0 : 1)
            }
        } else if !UserDefaults.standard.bool(forKey: "hasOpened") {
            UserDefaults.standard.set(true, forKey: "hasOpened")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.toggleControls() }
        }
    }
    @objc private func toggleControls() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            controller?.endPlacement()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    func applicationWillTerminate(_ notification: Notification) { controller?.stop() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        toggleControls(); return true
    }
}
