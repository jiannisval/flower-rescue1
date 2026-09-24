import Foundation

public struct Level: Sendable {
    public let number: Int
    public let seed: UInt64
    public let world: Int
    public let board: Board              // scrambled, as shown to the player
    public let solutionRotations: [Int]  // per tile index (debug "Show Solution", hints)
    public let minimumMoves: Int         // tap count of an optimal solution
}

public enum LevelGenerator {
    public static func seed(forLevel n: Int) -> UInt64 {
        var g = SplitMix64(seed: UInt64(truncatingIfNeeded: n) &* 0x2545F4914F6CDD1D ^ 0xF10E5C0DE)
        return g.next()
    }

    public static func generate(number: Int) -> Level {
        generate(number: number, seed: seed(forLevel: number), profileLevel: number)
    }

    public static func generate(number: Int, seed: UInt64, profileLevel: Int) -> Level {
        let profile = DifficultyProfile(level: profileLevel)
        for attempt in 0..<400 {
            let s = seed &+ UInt64(attempt) &* 0x9E3779B1
            if let level = build(number: number, baseSeed: seed, seed: s, profile: profile, relaxed: attempt >= 200) {
                return level
            }
        }
        preconditionFailure("Level generation failed for \(number)")
    }

    // MARK: - Construction

    private static func build(number: Int, baseSeed: UInt64, seed: UInt64,
                              profile: DifficultyProfile, relaxed: Bool) -> Level? {
        var rng = SplitMix64(seed: seed)
        let w = profile.width, h = profile.height
        let source = Position(x: 0, y: Int.random(in: 0..<h, using: &rng))
        let flower = Position(x: w - 1, y: Int.random(in: 0..<h, using: &rng))

        // 1. Solution path
        var visited: Set<Position> = [source]
        var path = [source]
        var budget = 5_000
        guard findPath(current: source, target: flower, w: w, h: h,
                       visited: &visited, path: &path, rng: &rng, budget: &budget) else { return nil }
        if !relaxed && path.count < profile.minPathLength { return nil }
        let pathSet = Set(path)

        // 2. Required openings per path tile (+ optional tee branches into non-path cells)
        var needed = [Int: DirectionSet]()
        for (i, p) in path.enumerated() {
            var set = DirectionSet()
            if i > 0 { set.insert(DirectionSet(Direction.between(p, path[i - 1]))) }
            if i < path.count - 1 { set.insert(DirectionSet(Direction.between(p, path[i + 1]))) }
            if i > 0, i < path.count - 1, Double.random(in: 0..<1, using: &rng) < profile.teeChance {
                let options = Direction.allCases.filter { d in
                    let n = p.moved(d)
                    return n.x >= 0 && n.x < w && n.y >= 0 && n.y < h
                        && !pathSet.contains(n) && !set.contains(direction: d)
                }
                if let d = options.randomElement(using: &rng) { set.insert(DirectionSet(d)) }
            }
            needed[p.y * w + p.x] = set
        }

        // 3. Tiles (solved state) + obstacles/decoys
        var solved = [Tile](repeating: Tile(shape: .empty), count: w * h)
        let decoyShapes: [PipeShape] = [.corner, .corner, .straight, .straight, .tee, .cap, .cross]
        for i in 0..<(w * h) {
            if let set = needed[i] {
                let (shape, rot) = match(set)
                solved[i] = Tile(shape: shape, rotation: rot)
            } else {
                let roll = Double.random(in: 0..<1, using: &rng)
                if roll < profile.rockDensity {
                    solved[i] = Tile(shape: .rock)
                } else if Double.random(in: 0..<1, using: &rng) < profile.decoyDensity {
                    let shape = decoyShapes.randomElement(using: &rng)!
                    solved[i] = Tile(shape: shape, rotation: Int.random(in: 0..<4, using: &rng))
                }
            }
        }
        let solutionRotations = solved.map { $0.rotation }

        // 4. Scramble path tiles (never leave them correct), lock some untouched ones
        var scrambled = solved
        var minMoves = 0
        for (i, p) in path.enumerated() {
            let idx = p.y * w + p.x
            let set = needed[idx]!
            let isEndpoint = i == 0 || i == path.count - 1
            if !isEndpoint, profile.lockedChance > 0,
               Double.random(in: 0..<1, using: &rng) < profile.lockedChance {
                scrambled[idx].isLocked = true
                continue
            }
            let shape = solved[idx].shape
            guard shape.isRotatable else { continue }
            var r = Int.random(in: 0..<4, using: &rng)
            var guardCount = 0
            while shape.baseConnections.rotated(by: r) == set && guardCount < 16 {
                r = Int.random(in: 0..<4, using: &rng); guardCount += 1
            }
            scrambled[idx].rotation = r
            var k = 0
            while shape.baseConnections.rotated(by: r + k) != set && k < 4 { k += 1 }
            minMoves += k
        }
        let board = Board(width: w, height: h, tiles: scrambled, source: source, flower: flower)

        // 5. Validation
        if !relaxed && minMoves < profile.minMoves { return nil }
        if minMoves < 1 { return nil }
        if board.isSolved { return nil }
        var check = board
        for i in 0..<(w * h) where !check.tiles[i].isLocked { check.setRotation(solutionRotations[i], atIndex: i) }
        guard check.isSolved else { return nil }
        guard Solver.isSolvable(board) else { return nil }

        return Level(number: number, seed: baseSeed, world: DifficultyProfile.world(forLevel: number),
                     board: board, solutionRotations: solutionRotations, minimumMoves: minMoves)
    }

    private static func match(_ set: DirectionSet) -> (PipeShape, Int) {
        for shape in [PipeShape.cap, .straight, .corner, .tee, .cross] {
            for r in 0..<4 where shape.baseConnections.rotated(by: r) == set { return (shape, r) }
        }
        preconditionFailure("No shape for \(set)")
    }

    private static func findPath(current: Position, target: Position, w: Int, h: Int,
                                 visited: inout Set<Position>, path: inout [Position],
                                 rng: inout SplitMix64, budget: inout Int) -> Bool {
        if current == target { return true }
        budget -= 1
        if budget <= 0 { return false }
        for d in Direction.allCases.shuffled(using: &rng) {
            let n = current.moved(d)
            guard n.x >= 0, n.x < w, n.y >= 0, n.y < h, !visited.contains(n) else { continue }
            visited.insert(n); path.append(n)
            if findPath(current: n, target: target, w: w, h: h, visited: &visited,
                        path: &path, rng: &rng, budget: &budget) { return true }
            visited.remove(n); path.removeLast()
            if budget <= 0 { return false }
        }
        return false
    }
}

public enum DailyChallenge {
    public static func seed(year: Int, month: Int, day: Int) -> UInt64 {
        UInt64(year * 10_000 + month * 100 + day) &* 0x9E3779B97F4A7C15 ^ 0xDA11
    }
    /// Same date -> same puzzle on every device.
    public static func level(year: Int, month: Int, day: Int, difficulty: Int = 150) -> Level {
        LevelGenerator.generate(number: 0, seed: seed(year: year, month: month, day: day), profileLevel: difficulty)
    }
}
