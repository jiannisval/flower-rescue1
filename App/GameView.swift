import SwiftUI
import FlowerRescueCore

struct GameView: View {
    @StateObject private var vm = GameViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Level \(vm.levelNumber)").font(.title.bold())
            Text("Moves: \(vm.moves)").font(.headline).foregroundStyle(.secondary)
            BoardView(vm: vm)
            if vm.solved {
                Text("🌸 Bloomed!").font(.largeTitle)
                Button("Next level") { withAnimation { vm.next() } }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.87, green: 0.96, blue: 0.87).ignoresSafeArea())
    }
}

struct BoardView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        let b = vm.board
        VStack(spacing: 4) {
            ForEach(0..<b.height, id: \.self) { y in
                HStack(spacing: 4) {
                    ForEach(0..<b.width, id: \.self) { x in
                        let p = Position(x: x, y: y)
                        TileView(tile: b[p],
                                 degrees: Double(vm.turns[b.index(of: p)]) * 90,
                                 wet: vm.wet.contains(p),
                                 isSource: p == b.source,
                                 isFlower: p == b.flower)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) { vm.tap(p) }
                            }
                    }
                }
            }
        }
        .aspectRatio(CGFloat(b.width) / CGFloat(b.height), contentMode: .fit)
    }
}

struct TileView: View {
    let tile: Tile
    let degrees: Double
    let wet: Bool
    let isSource: Bool
    let isFlower: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(tile.shape == .rock ? Color.gray.opacity(0.6) : Color.white.opacity(0.7))
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            if tile.shape.isPipe {
                PipeGlyph(connections: tile.shape.baseConnections)
                    .stroke(wet ? Color.blue : Color(white: 0.55),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(degrees))
                    .padding(6)
            }
            if isSource { Text("💧").font(.title2) }
            if isFlower { Text(wet ? "🌸" : "🌱").font(.title2) }
            if tile.shape == .rock { Text("🪨") }
            if tile.isLocked { Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary) }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(isSource ? "Water source" : isFlower ? "Flower" : "Pipe")
    }
}

/// Draws the openings of a pipe from the tile centre to each edge midpoint.
struct PipeGlyph: Shape {
    let connections: DirectionSet

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: c)   // ensures a dot for single-opening caps
        path.addLine(to: c)
        for d in Direction.allCases where connections.contains(direction: d) {
            path.move(to: c)
            path.addLine(to: CGPoint(x: c.x + CGFloat(d.dx) * rect.width / 2,
                                     y: c.y + CGFloat(d.dy) * rect.height / 2))
        }
        return path
    }
}
