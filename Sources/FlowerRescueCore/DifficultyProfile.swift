import Foundation

/// Parametric difficulty. Data-driven knobs only; new mechanics extend this struct.
public struct DifficultyProfile: Sendable, Equatable {
    public var width: Int
    public var height: Int
    public var decoyDensity: Double
    public var rockDensity: Double
    public var lockedChance: Double
    public var teeChance: Double
    public var minPathLength: Int
    public var minMoves: Int

    public static func world(forLevel n: Int) -> Int { min(10, max(1, (n - 1) / 100 + 1)) }

    public init(level n: Int) {
        let l = max(1, n)
        width = min(8, 3 + l / 45)
        height = min(9, 3 + l / 40)
        decoyDensity = min(0.85, 0.25 + Double(l) * 0.0008)
        rockDensity = l < 51 ? 0 : min(0.22, 0.05 + Double(l - 51) * 0.0002)
        lockedChance = l < 51 ? 0 : min(0.2, 0.05 + Double(l - 51) * 0.0002)
        teeChance = l < 21 ? 0 : min(0.5, 0.1 + Double(l) * 0.0004)
        minPathLength = max(3, Int(Double(width * height) * min(0.6, 0.3 + Double(l) * 0.0004)))
        minMoves = min(12, 2 + l / 10)
    }
}
