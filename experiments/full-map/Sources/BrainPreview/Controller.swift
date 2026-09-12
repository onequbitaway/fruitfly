import AppKit
import BrainCore

final class PreviewController {
    let folder: URL
    let queue = DispatchQueue(label: "Fruitfly.full-map", qos: .userInitiated)
    private var model: BrainModel?
    private var workerTrial = Trial()
    private var testName: String?
    private var testUntil = 0.0
    private var timer: Timer?
    private var busy = false
    private var pendingMode: BrainMode?
    private(set) var metadata: BrainMetadata?
    private(set) var snapshot: BrainSnapshot?
    private(set) var trial = Trial()
    private(set) var history: [TracePoint] = []
    private(set) var mode: BrainMode = .full
    private(set) var connections = 0
    private(set) var processor = ""
    private(set) var inputLabel = "No input"
    private(set) var error: String?
    private(set) var loading = true
    var paused = false
    var blockFeeding = false
    var onChange: (() -> Void)?
    init(folder: URL) { self.folder = folder }
    func start() {
        load(.full)
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
    }
    func load(_ mode: BrainMode) {
        guard !busy else {
            pendingMode = mode
            return
        }
        loading = true
        busy = true
        self.mode = mode
        error = nil
        history = []
        snapshot = nil
        metadata = nil
        blockFeeding = false
        onChange?()
        queue.async {
            do {
                let model = try BrainModel(folder: self.folder, mode: mode, useGPU: mode == .full)
                self.model = model
                self.workerTrial = Trial()
                self.testName = nil
                let reading = model.snapshot()
                DispatchQueue.main.async {
                    self.metadata = model.metadata
                    self.snapshot = reading
                    self.trial = self.workerTrial
                    self.connections = model.connections
                    self.processor = model.processor
                    self.inputLabel = "No input"
                    self.loading = false
                    self.busy = false
                    self.onChange?()
                    self.applyPendingMode()
                }
            } catch { self.fail(error) }
        }
    }
    func pause() {
        paused.toggle()
        onChange?()
    }
    func dropFood(x: Double = 220, y: Double = 165) {
        queue.async {
            self.workerTrial.dropFood(x: x, y: y)
            self.testName = nil
            let trial = self.workerTrial
            DispatchQueue.main.async {
                self.trial = trial
                self.onChange?()
            }
        }
    }
    func clearFood() {
        queue.async {
            self.workerTrial.clearFood()
            self.testName = nil
            let trial = self.workerTrial
            DispatchQueue.main.async {
                self.trial = trial
                self.onChange?()
            }
        }
    }
    func reset() {
        queue.async {
            self.model?.reset()
            self.workerTrial = Trial()
            self.testName = nil
            guard let reading = self.model?.snapshot() else { return }
            DispatchQueue.main.async {
                self.history = []
                self.snapshot = reading
                self.trial = Trial()
                self.inputLabel = "No input"
                self.onChange?()
            }
        }
    }
    func test(_ name: String) {
        queue.async {
            // A test changes only the chosen input. It does not set any cell readout.
            self.testName = name
            self.testUntil = (self.model?.time ?? 0) + 2
        }
    }
    func block() {
        blockFeeding.toggle()
        let enabled = blockFeeding
        queue.async {
            guard let model = self.model else { return }
            model.silence(model.metadata.channels["mn9"] ?? [], enabled: enabled)
        }
        onChange?()
    }
    private func tick() {
        guard !loading, !busy, !paused, error == nil else { return }
        busy = true
        queue.async {
            guard let model = self.model else { return }
            var input = self.workerTrial.input()
            var label = "Food trial"
            if let name = self.testName, model.time < self.testUntil {
                switch name {
                case "Smell": input = BrainInput(odorLeft: 120, odorRight: 80)
                case "Taste": input = BrainInput(taste: 150)
                case "Visual": input = BrainInput(visualLeft: 140, visualRight: 30)
                default: input = BrainInput(feeding: 150)
                }
                label = "\(name) test · direct stimulation"
            } else {
                self.testName = nil
                if !input.hasInput { label = "No input" }
            }
            do {
                let reading = try model.advance(input)
                self.workerTrial.advance(reading, mode: model.mode)
                let trial = self.workerTrial
                DispatchQueue.main.async {
                    if reading.time < (self.history.last?.time ?? 0) { self.history = [] }
                    self.snapshot = reading
                    self.trial = trial
                    self.inputLabel = label
                    self.history.append(TracePoint(reading))
                    self.history.removeAll { $0.time < reading.time - 10 }
                    self.busy = false
                    self.onChange?()
                    self.applyPendingMode()
                }
            } catch { self.fail(error) }
        }
    }
    private func applyPendingMode() {
        if let next = pendingMode {
            pendingMode = nil
            load(next)
        }
    }
    func displayRecorded(model: BrainModel, snapshot: BrainSnapshot, trial: Trial, label: String, history: [TracePoint])
    {
        self.metadata = model.metadata
        self.mode = model.mode
        self.connections = model.connections
        self.processor = model.processor
        self.snapshot = snapshot
        self.trial = trial
        self.inputLabel = label
        self.history = history
        self.loading = false
        onChange?()
    }
    private func fail(_ error: Error) {
        DispatchQueue.main.async {
            self.error = error.localizedDescription
            self.loading = false
            self.busy = false
            self.onChange?()
            self.applyPendingMode()
        }
    }
}
