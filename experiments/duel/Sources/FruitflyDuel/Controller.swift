import AppKit
import DuelCore

final class DuelController {
  let folder: URL
  private let worker = DispatchQueue(label: "fruitfly.duel.model", qos: .userInitiated)
  private var duel: Duel?
  private var timer: Timer?
  private var generation = 0
  private var busy = false
  var mode: DuelMode = .full
  var frame: DuelFrame?
  var running = true
  var blood = true
  var seed: UInt64 = 42
  var status = "Loading two brains…"
  var changed: (() -> Void)?
  init(folder: URL) { self.folder = folder }
  func start() {
    load()
    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      self?.tick()
    }
  }
  func load() {
    generation += 1
    let token = generation
    let folder = folder
    let mode = mode
    let seed = seed
    busy = true
    frame = nil
    duel = nil
    status = "Loading two \(mode.rawValue.lowercased()) brains…"
    changed?()
    worker.async { [weak self] in
      do {
        let duel = try Duel(folder: folder, mode: mode, seed: seed)
        let first = duel.current
        DispatchQueue.main.async {
          guard let self, self.generation == token else { return }
          self.duel = duel
          self.frame = first
          self.busy = false
          self.status = "Ready"
          self.changed?()
        }
      } catch { self?.failed(error, token: token) }
    }
  }
  private func failed(_ error: Error, token: Int) {
    DispatchQueue.main.async { [weak self] in
      guard let self, self.generation == token else { return }
      self.busy = false
      self.running = false
      self.status = "Calculation stopped. \(error.localizedDescription)"
      self.changed?()
    }
  }
  func newRound() {
    seed &+= 1
    running = true
    load()
  }
  func setMode(_ mode: DuelMode) {
    self.mode = mode
    running = true
    load()
  }
  func tick() {
    guard running, !busy, let duel, frame?.match.complete == false else { return }
    busy = true
    let token = generation
    worker.async { [weak self] in
      do {
        let result = try duel.advance()
        DispatchQueue.main.async {
          guard let self, self.generation == token else { return }
          self.frame = result
          self.busy = false
          self.status = result.match.complete ? "Match complete" : "Running"
          self.changed?()
          // Continue when calculation finishes. A 100 ms timer alone would
          // halve the pace whenever a calculation takes just over 100 ms.
          DispatchQueue.main.asyncAfter(deadline: .now() + max(0, 0.1 - result.calculationSeconds))
          { [weak self] in
            guard let self, self.generation == token else { return }
            self.tick()
          }
        }
      } catch { self?.failed(error, token: token) }
    }
  }
}
