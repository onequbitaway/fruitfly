import Foundation

public enum FlyState: String, Sendable {
    case flying = "Exploring"
    case approaching = "Found food"
    case eating = "Eating"
    case resting = "Resting"
    case startled = "Startled"
}

public struct Crumb: Identifiable, Sendable {
    public let id: Int
    public let position: Point
    public var amount: Double = 1
    public var age: Double = 0
}

public final class FlyWorld {
    public private(set) var position: Point
    public private(set) var heading: Double = 0.3
    public private(set) var state: FlyState = .flying
    public private(set) var food: [Crumb] = []
    public private(set) var time: Double = 0
    public private(set) var eaten: Int = 0
    public private(set) var hunger: Double = 0.65
    public private(set) var speed: Double = 80
    public private(set) var areas: [Area]
    public var paused = false
    public var reducedMotion = false
    public let circuit: SmellCircuit?

    private var random: SeededRandom
    private var destination: Point
    private var stateUntil: Double = 0
    private var destinationUntil: Double = 0
    private var scaredUntil: Double = 0
    private var eatingID: Int?
    private var nextFoodID = 0
    private var previousCursor: Point?
    private var circuitElapsed = 0.0

    public init(areas: [Area], seed: UInt64 = 42, circuit: SmellCircuit? = nil) {
        let valid = areas.filter { $0.width > 40 && $0.height > 40 }
        self.areas = valid.isEmpty ? [Area(x: 0, y: 0, width: 1000, height: 700)] : valid
        position = self.areas[0].center
        destination = position + Point(120, 70)
        random = SeededRandom(state: seed)
        self.circuit = circuit
    }

    public func setAreas(_ newAreas: [Area]) {
        let valid = newAreas.filter { $0.width > 40 && $0.height > 40 }
        guard !valid.isEmpty else { return }
        areas = valid
        if !areas.contains(where: { $0.contains(position) }) { position = areas[0].center }
        food.removeAll { crumb in !areas.contains { $0.contains(crumb.position) } }
        if !areas.contains(where: { $0.contains(destination) }) { destination = position }
    }

    @discardableResult
    public func dropFood(at point: Point) -> Bool {
        guard point.x.isFinite && point.y.isFinite,
              let area = areas.first(where: { $0.contains(point) }) else { return false }
        nextFoodID += 1
        if food.count >= 12 { food.removeFirst() }
        food.append(Crumb(id: nextFoodID, position: area.clamp(point)))
        if state == .resting { state = .flying }
        return true
    }

    public func clearFood() {
        food.removeAll()
        eatingID = nil
        if state == .eating || state == .approaching { state = .flying }
    }

    public func bringHere(_ point: Point) {
        guard let area = areas.first(where: { $0.contains(point) }) else { return }
        position = area.clamp(point)
        state = .flying; eatingID = nil
        destinationUntil = 0
    }

    public func step(dt rawDT: Double, cursor: Point? = nil) {
        guard !paused, rawDT.isFinite, rawDT > 0 else { return }
        let dt = min(rawDT, 0.05)
        time += dt
        hunger = min(1, hunger + dt * 0.003)
        for i in food.indices { food[i].age += dt }
        food.removeAll { $0.age > 180 || $0.amount <= 0 }

        // Only fast cursor movement near the fly triggers this animation rule.
        // A still cursor beside food must not prevent the fly from eating.
        if let cursor {
            let motion = previousCursor.map { cursor.distance(to: $0) / dt } ?? 0
            if cursor.distance(to: position) < 68, motion > 180, time > scaredUntil {
                state = .startled
                eatingID = nil
                let away = position - cursor
                let direction = away.length > 1 ? away.angle : heading + .pi
                destination = position + Point(cos(direction), sin(direction)) * 200
                stateUntil = time + 0.7
                scaredUntil = time + 2.0
            }
            previousCursor = cursor
        }

        let area = areas.first(where: { $0.contains(position) }) ?? areas[0]
        // Food is local to each screen. Use Bring fly here to move between screens.
        let target = food.filter { area.contains($0.position) }
            .min { $0.position.distance(to: position) < $1.position.distance(to: position) }
        let offset = target.map { $0.position - position } ?? Point(0, 0)
        let angle = angleDifference(offset.angle, heading)
        let scent = target == nil ? 0 : exp(-offset.length / 500)
        circuitElapsed += dt
        if circuitElapsed >= 0.05 {
            circuit?.step(left: scent * (0.75 + 0.25 * sin(angle)),
                          right: scent * (0.75 - 0.25 * sin(angle)), dt: circuitElapsed)
            circuitElapsed = 0
        }

        if state == .startled && time >= stateUntil { state = .flying }
        if state == .eating {
            if let index = food.firstIndex(where: { $0.id == eatingID }) {
                food[index].amount -= dt / 4.5
                hunger = max(0.05, hunger - dt * 0.09)
                if food[index].amount <= 0 {
                    eaten += 1
                    food.remove(at: index)
                    eatingID = nil
                    state = .resting
                    stateUntil = time + random.between(2, 5)
                }
                speed = 0
                return
            }
            eatingID = nil; state = .flying
        }
        if state == .resting {
            speed = 0
            if time < stateUntil { return }
            state = .flying
            destinationUntil = 0
        }

        if state != .startled, let target {
            state = .approaching
            destination = target.position
            if offset.length < 13 {
                position = target.position + Point(-6, 3)
                heading = -0.45
                state = .eating
                eatingID = target.id
                speed = 0
                return
            }
        } else if state != .startled {
            state = .flying
            if time > destinationUntil || destination.distance(to: position) < 24 {
                // Rest between flights. No window text or pixels are read.
                if random.unit() < 0.18 && time > 8 {
                    state = .resting
                    stateUntil = time + random.between(2, 6)
                    speed = 0
                    return
                }
                destination = area.clamp(Point(random.between(area.x, area.x + area.width),
                                               random.between(area.y, area.y + area.height)))
                destinationUntil = time + random.between(3, 7)
            }
        }

        let toGoal = destination - position
        // The measured circuit changes the turn and speed. The goal, landing,
        // eating, and cursor response are explicit pet-animation rules.
        let turnBias = ((circuit?.left ?? 0) - (circuit?.right ?? 0)) * 0.8
        let wiggle = state == .approaching ? 0.05 : sin(time * 2.1) * 0.26 + sin(time * 5.3) * 0.09
        let wantedHeading = toGoal.angle + wiggle + turnBias
        heading += angleDifference(wantedHeading, heading) * min(1, dt * (state == .startled ? 12 : 4))
        let activity = circuit?.activity ?? 0
        let desiredSpeed: Double
        if state == .startled { desiredSpeed = 350 }
        else if state == .approaching { desiredSpeed = min(160 + activity * 45, max(35, toGoal.length * 1.8)) }
        else { desiredSpeed = 85 + 24 * sin(time * 0.8) + activity * 35 }
        let motionScale = reducedMotion ? 0.55 : 1.0
        speed += (desiredSpeed * motionScale - speed) * min(1, dt * 5)
        let proposed = position + Point(cos(heading), sin(heading)) * min(speed * dt, toGoal.length)
        position = area.clamp(proposed, inset: 16)
        if position != proposed {
            destination = area.center
            destinationUntil = time + 1
            heading = (destination - position).angle
        }
    }
}
