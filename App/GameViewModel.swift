import SwiftUI
import FlowerRescueCore

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var board: Board
    @Published private(set) var turns: [Int]      // cumulative quarter turns, for smooth animation
    @Published private(set) var moves = 0
    @Published private(set) var levelNumber: Int
    @Published private(set) var wet: Set<Position>
    @Published private(set) var solved = false

    init(levelNumber: Int = 1) {
        let level = LevelGenerator.generate(number: levelNumber)
        self.levelNumber = levelNumber
        self.board = level.board
        self.turns = level.board.tiles.map { $0.rotation }
        self.wet = level.board.wetPositions()
    }

    func load(_ n: Int) {
        let level = LevelGenerator.generate(number: n)
        levelNumber = n
        board = level.board
        turns = level.board.tiles.map { $0.rotation }
        wet = level.board.wetPositions()
        moves = 0
        solved = false
    }

    func tap(_ p: Position) {
        guard !solved, board.rotateTile(at: p) else { return }
        turns[board.index(of: p)] += 1
        moves += 1
        wet = board.wetPositions()
        solved = board.isSolved
    }

    func next() { load(levelNumber + 1) }
}
