import Foundation

public struct Point: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    public static func + (a: Point, b: Point) -> Point { Point(a.x + b.x, a.y + b.y) }
    public static func - (a: Point, b: Point) -> Point { Point(a.x - b.x, a.y - b.y) }
    public static func * (a: Point, b: Double) -> Point { Point(a.x * b, a.y * b) }
    public var length: Double { hypot(x, y) }
    public var angle: Double { atan2(y, x) }
    public func distance(to other: Point) -> Double { (self - other).length }
}

public struct Area: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public var center: Point { Point(x + width / 2, y + height / 2) }
    public func contains(_ p: Point) -> Bool {
        p.x >= x && p.x <= x + width && p.y >= y && p.y <= y + height
    }
    public func clamp(_ p: Point, inset: Double = 20) -> Point {
        let ix = min(inset, width / 2), iy = min(inset, height / 2)
        return Point(bounded(p.x, x + ix, x + width - ix), bounded(p.y, y + iy, y + height - iy))
    }
}

func bounded(_ value: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, value)) }
func angleDifference(_ a: Double, _ b: Double) -> Double { atan2(sin(a - b), cos(a - b)) }

struct SeededRandom {
    var state: UInt64
    mutating func unit() -> Double {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return Double(z ^ (z >> 31)) / Double(UInt64.max)
    }
    mutating func between(_ lo: Double, _ hi: Double) -> Double { lo + unit() * (hi - lo) }
}
