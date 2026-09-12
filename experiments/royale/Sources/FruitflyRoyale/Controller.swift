import AppKit
import RoyaleCore

final class RoyaleController {
    let folder: URL
    private let worker = DispatchQueue(label: "fruitfly.royale.model", qos: .userInitiated)
    private var fleet: BrainFleet?
    private var timer: Timer?
    private var generation = 0
    private var busy = false
    private var pendingFood: [Vector] = []
    var mode: FleetMode = .simple
    var frame: FleetFrame?
    var previousFrame: FleetFrame?
    var running = true
    var blood = true
    var selected = 0
    var seed: UInt64 = 42
    var status = "Loading ten brains…"
    var changed: (() -> Void)?

    init(folder: URL) { self.folder = folder }
    func start() {
        load()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
    }
    func load() {
        generation += 1
        let token = generation
        let folder = folder
        let mode = mode
        let seed = seed
        busy = true
        frame = nil
        previousFrame = nil
        fleet = nil
        pendingFood = []
        status = "Loading ten \(mode.rawValue.lowercased()) brains…"
        changed?()
        worker.async { [weak self] in
            do {
                let fleet = try BrainFleet(folder: folder, mode: mode, seed: seed)
                let first = fleet.frame()
                DispatchQueue.main.async {
                    guard let self, token == self.generation else { return }
                    self.fleet = fleet
                    self.frame = first
                    self.busy = false
                    self.status = "Ready"
                    self.changed?()
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self, token == self.generation else { return }
                    self.busy = false
                    self.running = false
                    self.status = "Could not load the brains. \(error.localizedDescription)"
                    self.changed?()
                }
            }
        }
    }
    func newRound() {
        seed &+= 1
        running = true
        load()
    }
    func setMode(_ mode: FleetMode) {
        self.mode = mode
        running = true
        load()
    }
    func dropFood(_ point: Vector) {
        guard frame != nil, pendingFood.count < 8 else { return }
        pendingFood.append(point)
    }
    func tick() {
        guard running, !busy, let fleet, frame?.arena.complete == false else { return }
        busy = true
        let token = generation
        let food = pendingFood
        pendingFood = []
        worker.async { [weak self] in
            do {
                for p in food { fleet.dropFood(at: p) }
                let result = try fleet.advance()
                DispatchQueue.main.async {
                    guard let self, token == self.generation else { return }
                    self.previousFrame = self.frame
                    self.frame = result
                    self.busy = false
                    self.status = result.arena.complete ? "Round complete" : "Running"
                    self.changed?()
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self, token == self.generation else { return }
                    self.busy = false
                    self.running = false
                    self.status = "Calculation stopped. \(error.localizedDescription)"
                    self.changed?()
                }
            }
        }
    }
}
