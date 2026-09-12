import AppKit
import RoyaleCore

func smoke(folder: URL) throws {
    for mode in FleetMode.allCases {
        let fleet = try BrainFleet(folder: folder, mode: mode)
        let frame = try fleet.advance()
        guard frame.activity.count == 10, frame.activity.allSatisfy({ $0.activeCells > 0 }) else {
            throw NSError(domain: "RoyaleSmoke", code: 1)
        }
        let image = try render(frame: frame, mode: mode)
        guard image.width == 1280, image.height == 900 else { throw NSError(domain: "RoyaleSmoke", code: 2) }
        print("Packaged \(mode.rawValue): ten brains and arena render passed")
    }
}
