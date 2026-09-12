import Foundation

public struct Trial: Codable {
    public var x: Double = 45
    public var y: Double = 70
    public var heading: Double = 0.3
    public var time: Double = 0
    public var foodX: Double? = nil
    public var foodY: Double? = nil
    public var foodAmount: Double = 0
    public var meals: Int = 0
    public var phase = "Exploring"
    public var atFood: Bool {
        guard let fx = foodX, let fy = foodY else { return false }
        return hypot(fx - x, fy - y) < 14
    }
    public init() {}
    public mutating func dropFood(x: Double = 220, y: Double = 165) {
        foodX = x
        foodY = y
        foodAmount = 1
    }
    public mutating func clearFood() {
        foodX = nil
        foodY = nil
        foodAmount = 0
    }
    public func input() -> BrainInput {
        guard let fx = foodX, let fy = foodY else { return BrainInput() }
        let distance = hypot(fx - x, fy - y)
        let angle = atan2(fy - y, fx - x) - heading
        let scent = 120 * exp(-distance / 260)
        return BrainInput(
            odorLeft: Float(scent * (0.75 + 0.25 * sin(angle))),
            odorRight: Float(scent * (0.75 - 0.25 * sin(angle))), taste: atFood ? 150 : 0)
    }
    public mutating func advance(_ reading: BrainSnapshot, mode: BrainMode) {
        time += 0.1
        if let fx = foodX, let fy = foodY {
            let distance = hypot(fx - x, fy - y)
            if distance >= 14 {
                // This is a guided preview. The destination is still a pet rule.
                // The model's measured DNa02 readout adds a turn bias.
                heading = atan2(fy - y, fx - x) + Double(reading.steeringLeftHz - reading.steeringRightHz) * 0.001
                let travel = min(8, distance - 8)
                x += cos(heading) * travel
                y += sin(heading) * travel
                phase = "Guided approach"
            } else {
                let eating = mode == .simple ? 1 : min(1, Double(reading.feedingHz) / 40)
                phase =
                    eating > 0
                    ? (mode == .full ? "Eating · MN9 output" : "Eating · pet rule") : "At food · waiting for MN9"
                foodAmount -= 0.1 * eating / 2
                heading = 0.1
                if foodAmount <= 0 {
                    meals += 1
                    clearFood()
                    phase = "Food gone"
                }
            }
        } else {
            phase = meals > 0 ? "Food gone" : "Exploring"
            heading = 0.3 + sin(time * 0.7) * 1.1
            x = max(22, min(248, x + cos(heading) * 1.5))
            y = max(24, min(198, y + sin(heading) * 1.2))
        }
    }
}
public struct TracePoint: Codable {
    public let time: Double
    public let means: [Double]
    public let active: [Int]
    public let feeding: Float
    public let steeringLeft: Float
    public let steeringRight: Float
    public init(_ snapshot: BrainSnapshot) {
        time = snapshot.time
        means = snapshot.groupMeanHz
        active = snapshot.groupActive
        feeding = snapshot.feedingHz
        steeringLeft = snapshot.steeringLeftHz
        steeringRight = snapshot.steeringRightHz
    }
}
