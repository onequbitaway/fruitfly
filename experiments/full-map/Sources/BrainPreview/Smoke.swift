import AppKit
import BrainCore

func smoke(_ controller: PreviewController) {
    var stage = 0
    var checks = 0
    var until = 0.0
    var held = 0.0
    let start = ProcessInfo.processInfo.systemUptime
    func verify(_ condition: Bool, _ text: String) {
        guard condition else {
            fputs("FAIL UI: \(text)\n", stderr)
            exit(1)
        }
        checks += 1
    }
    Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
        let now = ProcessInfo.processInfo.systemUptime
        if now - start > 40 {
            fputs("UI check timeout at \(stage)\n", stderr)
            exit(1)
        }
        guard !controller.loading, controller.error == nil, let s = controller.snapshot else { return }
        switch stage {
        case 0 where s.time >= 0.2:
            controller.pause()
            until = now + 0.25
            stage = 1
        case 1 where now >= until:
            held = s.time
            until = now + 0.25
            stage = 2
        case 2 where now >= until:
            verify(s.time == held, "pause stops the clock")
            controller.load(.simple)
            stage = 3
        case 3 where controller.mode == .simple:
            verify(controller.metadata?.ids.count == 3745, "Simple mode loads")
            controller.dropFood()
            until = now + 0.15
            stage = 4
        case 4 where now >= until:
            verify(controller.trial.foodAmount == 1, "food can be placed while paused")
            controller.reset()
            until = now + 0.15
            stage = 5
        case 5 where now >= until:
            verify(s.time == 0 && controller.trial.foodX == nil, "reset clears state")
            controller.load(.full)
            stage = 6
        case 6 where controller.mode == .full:
            verify(controller.metadata?.ids.count == 166700, "Full map loads")
            controller.test("Feeding")
            controller.pause()
            stage = 7
        case 7 where s.time >= 0.5:
            verify(s.feedingHz > 0, "feeding test reaches MN9")
            controller.pause()
            controller.block()
            controller.reset()
            until = now + 0.2
            stage = 8
        case 8 where now >= until:
            controller.test("Feeding")
            controller.pause()
            stage = 9
        case 9 where s.time >= 0.5:
            verify(controller.blockFeeding && s.feedingHz == 0, "block works through controller")
            controller.pause()
            print("Passed \(checks) live UI checks")
            timer.invalidate()
            NSApplication.shared.terminate(nil)
        default: break
        }
    }
    controller.start()
}
