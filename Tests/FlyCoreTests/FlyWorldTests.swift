import Foundation
import FlyCore

final class FlyWorldTests {
    let screen = Area(x: 0, y: 0, width: 1440, height: 900)

    func testFlyFindsAndEatsFoodAcrossSeeds() {
        for seed: UInt64 in [1, 4, 11, 24, 99] {
            let world = FlyWorld(areas: [screen], seed: seed)
            expect(world.dropFood(at: Point(250, 200)))
            for _ in 0..<2400 { world.step(dt: 1.0 / 30) }
            expectEqual(world.eaten, 1, "Seed \(seed) did not finish the crumb")
            expect(world.food.isEmpty)
        }
    }

    func testPauseFreezesMovementFoodAndCircuitTime() {
        let world = FlyWorld(areas: [screen])
        world.dropFood(at: Point(300, 400))
        world.step(dt: 0.03)
        let position = world.position, time = world.time, foodAge = world.food[0].age
        world.paused = true
        for _ in 0..<100 { world.step(dt: 0.03, cursor: Point(100, 100)) }
        expectEqual(world.position, position)
        expectEqual(world.time, time)
        expectEqual(world.food[0].age, foodAge)
    }

    func testFlyStaysVisibleDuringLongRunAndScreenRemoval() {
        let other = Area(x: -1920, y: -200, width: 1920, height: 1080)
        let world = FlyWorld(areas: [screen, other], seed: 23)
        world.bringHere(other.center)
        for _ in 0..<18000 {
            world.step(dt: 1.0 / 30)
            expect(other.contains(world.position))
        }
        world.dropFood(at: other.center)
        world.setAreas([screen])
        expect(screen.contains(world.position))
        expect(world.food.isEmpty)
    }

    func testFoodLimitExpiryAndInvalidCoordinates() {
        let world = FlyWorld(areas: [screen])
        expectFalse(world.dropFood(at: Point(.nan, 0)))
        expectFalse(world.dropFood(at: Point(-100, 0)))
        for _ in 0..<20 { world.dropFood(at: Point(35, 35)) }
        expectEqual(world.food.count, 12)
        world.clearFood()
        expectEqual(world.food.count, 0)
        let other = Area(x: 1600, y: 0, width: 1000, height: 800)
        world.setAreas([screen, other])
        world.dropFood(at: other.center)
        for _ in 0..<5500 { world.step(dt: 1.0 / 30) }
        expect(world.food.isEmpty, "Unvisited crumbs must expire")
    }

    func testStillCursorDoesNotPreventEating() {
        let world = FlyWorld(areas: [screen])
        let target = world.position + Point(30, 0)
        world.dropFood(at: target)
        for _ in 0..<900 { world.step(dt: 1.0 / 30, cursor: target) }
        expectEqual(world.eaten, 1)
    }

    func testFastCursorStartlesFly() {
        let world = FlyWorld(areas: [screen])
        world.step(dt: 0.03, cursor: Point(0, 0))
        world.step(dt: 0.03, cursor: world.position + Point(10, 0))
        expectEqual(world.state, .startled)
    }

    func testInvalidFrameTimesDoNotCorruptPosition() {
        let world = FlyWorld(areas: [screen])
        let before = world.position
        for dt in [Double.nan, .infinity, -1, 0] { world.step(dt: dt) }
        expectEqual(world.position, before)
        world.step(dt: 1000)
        expect(screen.contains(world.position))
        expectAtMost(world.time, 0.05)
    }
}
