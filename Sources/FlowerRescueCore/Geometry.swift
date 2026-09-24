import Foundation

public enum Direction: Int, CaseIterable, Sendable, Codable {
    case up = 0, right, down, left

    public var opposite: Direction { Direction(rawValue: (rawValue + 2) % 4)! }
    public var dx: Int { switch self { case .right: return 1; case .left: return -1; default: return 0 } }
    public var dy: Int { switch self { case .down: return 1; case .up: return -1; default: return 0 } }

    /// Clockwise rotation by `steps` quarter turns.
    public func rotated(by steps: Int) -> Direction {
        Direction(rawValue: (((rawValue + steps) % 4) + 4) % 4)!
    }

    public static func between(_ a: Position, _ b: Position) -> Direction {
        for d in Direction.allCases where a.moved(d) == b { return d }
        preconditionFailure("Positions are not adjacent")
    }
}

public struct Position: Hashable, Sendable, Codable {
    public var x: Int
    public var y: Int
    public init(x: Int, y: Int) { self.x = x; self.y = y }
    public func moved(_ d: Direction) -> Position { Position(x: x + d.dx, y: y + d.dy) }
    public func manhattan(to o: Position) -> Int { abs(x - o.x) + abs(y - o.y) }
}

public struct DirectionSet: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public init(_ d: Direction) { self.init(rawValue: UInt8(1) << UInt8(d.rawValue)) }

    public func contains(direction d: Direction) -> Bool { contains(DirectionSet(d)) }

    public func rotated(by steps: Int) -> DirectionSet {
        var result = DirectionSet()
        for d in Direction.allCases where contains(direction: d) {
            result.insert(DirectionSet(d.rotated(by: steps)))
        }
        return result
    }
    public var count: Int { rawValue.nonzeroBitCount }
}
