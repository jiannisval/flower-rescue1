import Foundation

/// Independent solvability check: searches for a self-avoiding path source -> flower
/// where every tile on it can be rotated (respecting locks) to link its neighbours.
/// Bounded; returns false when the node budget runs out (callers treat that as "reject").
public enum Solver {
    public static func isSolvable(_ board: Board, nodeBudget: Int = 200_000) -> Bool {
        var visited: Set<Position> = [board.source]
        var budget = nodeBudget
        return dfs(board, at: board.source, entry: nil, visited: &visited, budget: &budget)
    }

    private static func rotations(_ t: Tile) -> [Int] {
        (t.isLocked || !t.shape.isRotatable) ? [t.rotation] : [0, 1, 2, 3]
    }

    private static func dfs(_ b: Board, at p: Position, entry: Direction?,
                            visited: inout Set<Position>, budget: inout Int) -> Bool {
        budget -= 1
        if budget <= 0 { return false }
        let tile = b[p]
        for r in rotations(tile) {
            let conn = tile.shape.baseConnections.rotated(by: r)
            if let e = entry, !conn.contains(direction: e) { continue }
            let exits = Direction.allCases
                .filter { conn.contains(direction: $0) && $0 != entry }
                .sorted { p.moved($0).manhattan(to: b.flower) < p.moved($1).manhattan(to: b.flower) }
            for d in exits {
                let n = p.moved(d)
                guard b.contains(n), !visited.contains(n) else { continue }
                let nt = b[n]
                guard nt.shape.isPipe else { continue }
                if n == b.flower {
                    let ok = rotations(nt).contains {
                        nt.shape.baseConnections.rotated(by: $0).contains(direction: d.opposite)
                    }
                    if ok { return true }
                    continue
                }
                visited.insert(n)
                if dfs(b, at: n, entry: d.opposite, visited: &visited, budget: &budget) { return true }
                visited.remove(n)
                if budget <= 0 { return false }
            }
        }
        return false
    }
}
