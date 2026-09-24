import Foundation

public enum PipeShape: String, Sendable, Codable, CaseIterable {
    case empty, straight, corner, tee, cross, cap, rock

    /// Openings at rotation 0.
    public var baseConnections: DirectionSet {
        switch self {
        case .empty, .rock: return []
        case .straight: return [DirectionSet(.up), DirectionSet(.down)]
        case .corner: return [DirectionSet(.up), DirectionSet(.right)]
        case .tee: return [DirectionSet(.up), DirectionSet(.right), DirectionSet(.left)]
        case .cross: return [DirectionSet(.up), DirectionSet(.right), DirectionSet(.down), DirectionSet(.left)]
        case .cap: return [DirectionSet(.up)]
        }
    }
    public var isRotatable: Bool { self != .empty && self != .rock && self != .cross }
    public var isPipe: Bool { self != .empty && self != .rock }
}

public struct Tile: Equatable, Sendable, Codable {
    public var shape: PipeShape
    public var rotation: Int          // 0...3, clockwise quarter turns
    public var isLocked: Bool

    public init(shape: PipeShape, rotation: Int = 0, isLocked: Bool = false) {
        self.shape = shape
        self.rotation = ((rotation % 4) + 4) % 4
        self.isLocked = isLocked
    }
    public var connections: DirectionSet { shape.baseConnections.rotated(by: rotation) }
}

public struct Board: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public private(set) var tiles: [Tile]
    public let source: Position
    public let flower: Position

    public init(width: Int, height: Int, tiles: [Tile], source: Position, flower: Position) {
        precondition(tiles.count == width * height)
        self.width = width; self.height = height
        self.tiles = tiles; self.source = source; self.flower = flower
    }

    public func contains(_ p: Position) -> Bool { p.x >= 0 && p.x < width && p.y >= 0 && p.y < height }
    public func index(of p: Position) -> Int { p.y * width + p.x }
    public func position(atIndex i: Int) -> Position { Position(x: i % width, y: i / width) }
    public subscript(p: Position) -> Tile { tiles[index(of: p)] }

    /// Player tap: rotate one quarter turn clockwise. Returns false if the tile can't rotate.
    @discardableResult
    public mutating func rotateTile(at p: Position) -> Bool {
        guard contains(p) else { return false }
        let i = index(of: p)
        guard tiles[i].shape.isRotatable, !tiles[i].isLocked else { return false }
        tiles[i].rotation = (tiles[i].rotation + 1) % 4
        return true
    }

    public mutating func setRotation(_ r: Int, atIndex i: Int) {
        tiles[i].rotation = ((r % 4) + 4) % 4
    }

    /// All cells water reaches from the source (BFS over mutually open edges).
    public func wetPositions() -> Set<Position> {
        guard self[source].shape.isPipe else { return [] }
        var wet: Set<Position> = [source]
        var queue = [source]
        var head = 0
        while head < queue.count {
            let p = queue[head]; head += 1
            let conn = self[p].connections
            for d in Direction.allCases where conn.contains(direction: d) {
                let n = p.moved(d)
                guard contains(n), !wet.contains(n),
                      self[n].connections.contains(direction: d.opposite) else { continue }
                wet.insert(n); queue.append(n)
            }
        }
        return wet
    }

    public var isSolved: Bool { wetPositions().contains(flower) }
}
