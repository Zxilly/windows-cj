package windows_reactor_apps

// ============================================================================
// game_minesweeper — Minesweeper game body.
//
// Window title (supplied by main()): "windows_reactor — minesweeper"
//
// The board is a grid of `button` widgets with all state held in a single
// reducer cell (cx.useReducerFn). Left-click reveals a tile; right-tap cycles
// flag/question/hidden. Defaults to a 9×9 board with 10 mines, first click
// always safe, BFS flood-fill for zero-neighbour regions.
//
// Contract: a single top-level `public func minesweeperApp(cx: RenderCx)`.
//
// NOTE: every game_*.cj file shares ONE package (windows_reactor_apps), so all
// top-level symbols share a namespace. To avoid colliding with the other game
// bodies, every minesweeper-private declaration is prefixed `ms`/`Ms`; only
// `minesweeperApp` is the shared public entry point.
// ============================================================================

import std.collection.*
import std.time.*
import windows_reactor.core.*

// ---------------------------------------------------------------------------
// Board dimensions
// ---------------------------------------------------------------------------

let MS_WIDTH: Int64 = 9
let MS_HEIGHT: Int64 = 9
let MS_TOTAL: Int64 = MS_WIDTH * MS_HEIGHT
let MS_MINES: Int64 = 10

// ---------------------------------------------------------------------------
// Per-tile UI state
// ---------------------------------------------------------------------------

enum MsTileState {
    | Hidden | Flag | Question | Revealed

    func tag(): Int64 {
        match (this) {
            case Hidden => 0
            case Flag => 1
            case Question => 2
            case Revealed => 3
        }
    }

    // Cycle through flag/question/hidden on a flag-mode click. Revealed tiles
    // cannot be flagged; callers must check first.
    func cycle(): MsTileState {
        match (this) {
            case Hidden => MsTileState.Flag
            case Flag => MsTileState.Question
            case Question => MsTileState.Hidden
            case Revealed => MsTileState.Revealed
        }
    }

    func eq(other: MsTileState): Bool { tag() == other.tag() }
}

enum MsStatus {
    | Playing | Won | Lost

    func tag(): Int64 {
        match (this) {
            case Playing => 0
            case Won => 1
            case Lost => 2
        }
    }

    func eq(other: MsStatus): Bool { tag() == other.tag() }
}

// ---------------------------------------------------------------------------
// Game model — an Equatable value type so it can live in a reducer state cell.
//
// The board uses fixed-length Arrays of MS_TOTAL entries. A MsGame is treated
// as immutable from the caller's view: every transition clones into a fresh
// MsGame (mirroring the reference's value-clone semantics), so the reducer's
// equality short-circuit and the renderer's diffing both behave correctly.
// ---------------------------------------------------------------------------

class MsGame <: Equatable<MsGame> {
    // Per-tile UI state.
    var tiles: Array<MsTileState>
    // True iff the tile is a mine. Filled lazily on the first reveal so the
    // first click is always safe.
    var mines: Array<Bool>
    // Neighbour mine counts for non-mine tiles; -1 for mine tiles.
    var neighbors: Array<Int64>
    // True once mines/neighbors have been populated.
    var generated: Bool
    // Set to Some(index) when the player triggers a mine, so the UI can
    // highlight the fatal tile.
    var hitMine: ?Int64
    var status: MsStatus
    var seed: UInt64

    init(seed: UInt64) {
        this.tiles = Array<MsTileState>(MS_TOTAL, repeat: MsTileState.Hidden)
        this.mines = Array<Bool>(MS_TOTAL, repeat: false)
        this.neighbors = Array<Int64>(MS_TOTAL, repeat: 0)
        this.generated = false
        this.hitMine = None
        this.status = MsStatus.Playing
        this.seed = seed
    }

    // Private full-field constructor used by clone().
    private init(
        tiles: Array<MsTileState>,
        mines: Array<Bool>,
        neighbors: Array<Int64>,
        generated: Bool,
        hitMine: ?Int64,
        status: MsStatus,
        seed: UInt64
    ) {
        this.tiles = tiles
        this.mines = mines
        this.neighbors = neighbors
        this.generated = generated
        this.hitMine = hitMine
        this.status = status
        this.seed = seed
    }

    static func index(x: Int64, y: Int64): Int64 { y * MS_WIDTH + x }
    static func xOf(index: Int64): Int64 { index % MS_WIDTH }
    static func yOf(index: Int64): Int64 { index / MS_WIDTH }

    // Deep clone: Arrays are value-semantically copied so a transition never
    // mutates the previous MsGame observed by the renderer.
    func clone(): MsGame {
        MsGame(
            this.tiles.clone(),
            this.mines.clone(),
            this.neighbors.clone(),
            this.generated,
            this.hitMine,
            this.status,
            this.seed
        )
    }

    // Count of Flag tiles. Used to derive "mines remaining".
    func flagCount(): Int64 {
        var n = 0
        for (t in tiles) {
            if (t.eq(MsTileState.Flag)) { n++ }
        }
        n
    }

    // Value equality (required by useReducerFn's S <: Equatable<S>).
    public operator func ==(other: MsGame): Bool {
        if (generated != other.generated) { return false }
        if (!status.eq(other.status)) { return false }
        if (seed != other.seed) { return false }
        if (!msOptIntEq(hitMine, other.hitMine)) { return false }
        var i = 0
        while (i < MS_TOTAL) {
            if (!tiles[i].eq(other.tiles[i])) { return false }
            if (mines[i] != other.mines[i]) { return false }
            if (neighbors[i] != other.neighbors[i]) { return false }
            i++
        }
        true
    }

    public operator func !=(other: MsGame): Bool { !(this == other) }
}

func msOptIntEq(a: ?Int64, b: ?Int64): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x == y
        case (None, None) => true
        case _ => false
    }
}

func msNewGame(): MsGame { MsGame(msSeedFromClock()) }

// ---------------------------------------------------------------------------
// Neighbour iteration
// ---------------------------------------------------------------------------

let MS_OFFSETS: Array<(Int64, Int64)> = [
    (-1, -1), (0, -1), (1, -1),
    (-1, 0),           (1, 0),
    (-1, 1),  (0, 1),  (1, 1)
]

// Collect the (up to) eight in-bounds neighbours of (x, y).
func msNeighborsOf(x: Int64, y: Int64): ArrayList<(Int64, Int64)> {
    let out = ArrayList<(Int64, Int64)>()
    for ((dx, dy) in MS_OFFSETS) {
        let nx = x + dx
        let ny = y + dy
        if (nx >= 0 && ny >= 0 && nx < MS_WIDTH && ny < MS_HEIGHT) {
            out.add((nx, ny))
        }
    }
    out
}

// Populate game.mines and game.neighbors, avoiding the tile at (excludeX,
// excludeY) so the first click is never a mine. Mutates `game` in place
// (caller passes a freshly-cloned MsGame).
func msGenerateMines(game: MsGame, excludeX: Int64, excludeY: Int64): Unit {
    let exclude = MsGame.index(excludeX, excludeY)
    let rng = MsXorShift64(game.seed)

    var placed = 0
    while (placed < MS_MINES) {
        let idx = Int64(rng.nextU64() % UInt64(MS_TOTAL))
        if (idx == exclude || game.mines[idx]) {
            continue
        }
        game.mines[idx] = true
        placed++
    }

    var i = 0
    while (i < MS_TOTAL) {
        let x = MsGame.xOf(i)
        let y = MsGame.yOf(i)
        if (game.mines[i]) {
            game.neighbors[i] = -1
        } else {
            var count = 0
            for ((nx, ny) in msNeighborsOf(x, y)) {
                if (game.mines[MsGame.index(nx, ny)]) { count++ }
            }
            game.neighbors[i] = count
        }
        i++
    }

    game.generated = true
}

// Try to reveal (x, y). Returns None if the click is a no-op (game over,
// already revealed, or flagged); otherwise returns the new MsGame.
func msApplyReveal(game: MsGame, x: Int64, y: Int64): ?MsGame {
    if (x < 0 || y < 0 || x >= MS_WIDTH || y >= MS_HEIGHT) {
        return None
    }
    if (!game.status.eq(MsStatus.Playing)) {
        return None
    }
    let idx = MsGame.index(x, y)
    match (game.tiles[idx]) {
        case Revealed => return None
        case Flag => return None
        case Question => return None
        case Hidden => ()
    }

    let next = game.clone()
    if (!next.generated) {
        msGenerateMines(next, x, y)
    }

    if (next.mines[idx]) {
        // Reveal every mine so the player can see the layout, then mark the
        // fatal tile and lose.
        var i = 0
        while (i < MS_TOTAL) {
            if (next.mines[i]) {
                next.tiles[i] = MsTileState.Revealed
            }
            i++
        }
        next.hitMine = Some(idx)
        next.status = MsStatus.Lost
        return Some(next)
    }

    // BFS flood fill: reveal this tile and, for every revealed 0-neighbour
    // tile, expand to its hidden neighbours.
    let queue = ArrayList<Int64>()
    queue.add(idx)
    next.tiles[idx] = MsTileState.Revealed
    while (!queue.isEmpty()) {
        let cur = queue.remove(at: queue.size - 1)
        if (next.neighbors[cur] != 0) {
            continue
        }
        let cx = MsGame.xOf(cur)
        let cy = MsGame.yOf(cur)
        for ((nx, ny) in msNeighborsOf(cx, cy)) {
            let nidx = MsGame.index(nx, ny)
            // Only reveal hidden tiles — flag/question stay as the player left
            // them, which matches typical minesweeper behaviour.
            if (next.tiles[nidx].eq(MsTileState.Hidden) && !next.mines[nidx]) {
                next.tiles[nidx] = MsTileState.Revealed
                queue.add(nidx)
            }
        }
    }

    if (msCheckWon(next)) {
        next.status = MsStatus.Won
    }
    Some(next)
}

// Cycle hidden → flag → question → hidden on (x, y). Returns None if the click
// is a no-op (game over or tile already revealed).
func msApplyFlag(game: MsGame, x: Int64, y: Int64): ?MsGame {
    if (x < 0 || y < 0 || x >= MS_WIDTH || y >= MS_HEIGHT) {
        return None
    }
    if (!game.status.eq(MsStatus.Playing)) {
        return None
    }
    let idx = MsGame.index(x, y)
    if (game.tiles[idx].eq(MsTileState.Revealed)) {
        return None
    }
    let next = game.clone()
    next.tiles[idx] = next.tiles[idx].cycle()
    Some(next)
}

// Win = every non-mine tile is revealed.
func msCheckWon(game: MsGame): Bool {
    if (!game.generated) {
        return false
    }
    var i = 0
    while (i < MS_TOTAL) {
        if (!game.mines[i] && !game.tiles[i].eq(MsTileState.Revealed)) {
            return false
        }
        i++
    }
    true
}

// ---------------------------------------------------------------------------
// Tiny seedable PRNG (Marsaglia xorshift64). Plenty good for scattering ten
// mines across an 81-tile board; seeds deterministically.
// ---------------------------------------------------------------------------

class MsXorShift64 {
    var state: UInt64

    init(seed: UInt64) {
        // 0 is a fixed point for xorshift64; substitute a non-zero constant.
        if (seed == 0) {
            this.state = 0xDEAD_BEEF_CAFE_F00D
        } else {
            this.state = seed
        }
    }

    func nextU64(): UInt64 {
        var x = state
        x = x ^ (x << 13)
        x = x ^ (x >> 7)
        x = x ^ (x << 17)
        state = x
        x
    }
}

// Process-monotonic base captured once, mixed with a counter so each new game
// (initial + every "New Game") gets a distinct seed.
let msSeedBase: MonoTime = MonoTime.now()
let msSeedCounter: MsSeedCounter = MsSeedCounter()

class MsSeedCounter {
    var value: UInt64 = 0
    init() {}
    // Plain increment (never overflows in practice) used only as XOR salt, so
    // two "New Game" presses within the same clock tick still differ.
    func next(): UInt64 { value = value + 1; value }
}

func msSeedFromClock(): UInt64 {
    let elapsed = (MonoTime.now() - msSeedBase).toNanoseconds()
    // Fold the signed nanosecond delta into UInt64 (mask off the sign bit so
    // the cast is always in range) and XOR-mix the counter + a constant. XOR
    // never overflows, so this is safe under the default throwing policy.
    let base = UInt64(elapsed & 0x7FFF_FFFF_FFFF_FFFF)
    let salt = msSeedCounter.next() << 32
    base ^ salt ^ 0xA5A5_5A5A_A5A5_5A5A
}

// ---------------------------------------------------------------------------
// Rendering helpers
// ---------------------------------------------------------------------------

// Color-coded foreground for a revealed number tile (classic palette).
func msNumberColor(n: Int64): Color {
    match (n) {
        case 1 => Color.rgb(0u8, 0u8, 200u8)
        case 2 => Color.rgb(0u8, 128u8, 0u8)
        case 3 => Color.rgb(200u8, 0u8, 0u8)
        case 4 => Color.rgb(0u8, 0u8, 128u8)
        case 5 => Color.rgb(128u8, 0u8, 0u8)
        case 6 => Color.rgb(0u8, 128u8, 128u8)
        case 7 => Color.rgb(0u8, 0u8, 0u8)
        case _ => Color.rgb(128u8, 128u8, 128u8)
    }
}

func msTileLabel(game: MsGame, idx: Int64): String {
    match (game.tiles[idx]) {
        case Hidden => ""
        case Flag => "🚩"
        case Question => "?"
        case Revealed =>
            if (game.mines[idx]) {
                "💣"
            } else {
                let n = game.neighbors[idx]
                if (n == 0) { "" } else { "${n}" }
            }
    }
}

func msStatusLine(game: MsGame): String {
    let remaining = MS_MINES - game.flagCount()
    match (game.status) {
        case Playing => "Mines remaining: ${remaining}"
        case Won => "🎉 You cleared the board!"
        case Lost => "💥 Boom! Game over."
    }
}

// Per-tile screen-reader label, derived from the same data that drives the
// visible glyph. Without this, hidden tiles and revealed zero-neighbour tiles
// have empty button content and become indistinguishable to assistive tech.
func msTileAutomationName(game: MsGame, idx: Int64): String {
    let x = MsGame.xOf(idx)
    let y = MsGame.yOf(idx)
    let position = "row ${y + 1}, column ${x + 1}"
    let state = match (game.tiles[idx]) {
        case Hidden => "hidden"
        case Flag => "flagged"
        case Question => "question mark"
        case Revealed =>
            if (game.mines[idx]) {
                "mine"
            } else {
                let n = game.neighbors[idx]
                if (n == 0) {
                    "empty"
                } else if (n == 1) {
                    "1 mine nearby"
                } else {
                    "${n} mines nearby"
                }
            }
    }
    "Tile ${position}, ${state}"
}

// ---------------------------------------------------------------------------
// Actions + reducer
//
// Routing clicks through actions (instead of capturing the rendered MsGame in
// the click handler) lets the reducer always see the latest board state, so
// two clicks delivered before the next render are both applied in order.
// ---------------------------------------------------------------------------

enum MsAction {
    | Reveal(Int64, Int64)
    | FlagAt(Int64, Int64)
    | Reset
}

func msReduce(state: MsGame, action: MsAction): MsGame {
    match (action) {
        case Reveal(x, y) => match (msApplyReveal(state, x, y)) {
            case Some(g) => g
            case None => state
        }
        case FlagAt(x, y) => match (msApplyFlag(state, x, y)) {
            case Some(g) => g
            case None => state
        }
        case Reset => msNewGame()
    }
}

// ---------------------------------------------------------------------------
// Lowered-element decoration: attach a right-tap handler.
//
// The widget builders expose left-click via `.onClick` but right-tap lives on
// the shared Modifiers carried by every element (Modifiers.pointerHandlers).
// We mutate the lowered element's Modifiers directly — the same idiom the
// minimal examples use for keyboard accelerators / animations.
// ---------------------------------------------------------------------------

func msWithRightTapped(el: Element, handler: () -> Unit): Element {
    match (el.modifiers()) {
        case Some(m) =>
            let ph = match (m.pointerHandlers) {
                case Some(existing) => existing
                case None =>
                    let p = PointerHandlers()
                    m.pointerHandlers = Some(p)
                    p
            }
            ph.onRightTapped = Some(Callback<Unit>({ _ => handler() }))
        case None => ()
    }
    el
}

// ---------------------------------------------------------------------------
// Board construction
// ---------------------------------------------------------------------------

func msBuildCells(game: MsGame, dispatch: Dispatch<MsAction>): Array<Element> {
    let gameOver = !game.status.eq(MsStatus.Playing)
    let cells = ArrayList<Element>()
    var idx = 0
    while (idx < MS_TOTAL) {
        let x = MsGame.xOf(idx)
        let y = MsGame.yOf(idx)
        let tile = game.tiles[idx]
        let label = msTileLabel(game, idx)
        let automation = msTileAutomationName(game, idx)

        // Per-cell handlers capture the cell coordinates and dispatch actions
        // (the reducer always reads the freshest board state).
        let revealDispatch = dispatch
        let flagDispatch = dispatch
        let cx = x
        let cy = y

        var btn = button(label)
            .onClick({ => revealDispatch.call(MsAction.Reveal(cx, cy)) })
            .keyOf("tile-${idx}")
            .hAlign(HorizontalAlignment.Stretch)
            .vAlign(VerticalAlignment.Stretch)

        // Classic-palette foreground for number tiles; red highlight for the
        // mine that ended the game.
        if (tile.eq(MsTileState.Revealed) && !game.mines[idx] && game.neighbors[idx] > 0) {
            btn = btn.foreground(Brush.Solid(msNumberColor(game.neighbors[idx])))
        }
        match (game.hitMine) {
            case Some(h) where h == idx =>
                btn = btn.background(Brush.Solid(Color.rgb(220u8, 80u8, 80u8)))
            case _ => ()
        }

        // Disable every tile once the game ends, and any already-revealed tile
        // (revealed tiles, including 0-neighbour blanks, carry no further
        // interaction).
        let isInertRevealed = tile.eq(MsTileState.Revealed)
        if (gameOver || isInertRevealed) {
            btn = btn.enabled(false)
        }

        let placed = btn
            .automationName(automation)
            .gridRow(Int32(y))
            .gridColumn(Int32(x))
            .toElement()

        cells.add(msWithRightTapped(placed, { => flagDispatch.call(MsAction.FlagAt(cx, cy)) }))
        idx++
    }
    cells.toArray()
}

func msBuildBoard(game: MsGame, dispatch: Dispatch<MsAction>): Element {
    let cells = msBuildCells(game, dispatch)
    grid(cells)
        .rowsOf(Array<GridLength>(MS_HEIGHT, repeat: GridLength.Star(1.0)))
        .columnsOf(Array<GridLength>(MS_WIDTH, repeat: GridLength.Star(1.0)))
        .rowSpacing(2.0)
        .columnSpacing(2.0)
        .width(420.0)
        .height(420.0)
        .hAlign(HorizontalAlignment.Center)
        .toElement()
}

// ---------------------------------------------------------------------------
// Root component
// ---------------------------------------------------------------------------

public func minesweeperApp(cx: RenderCx): Element {
    let (game, dispatch) = cx.useReducerFn<MsGame, MsAction>(msReduce, msNewGame())

    let resetDispatch = dispatch
    let resetHandler = { => resetDispatch.call(MsAction.Reset) }

    let header = vstack([
        text_block(msStatusLine(game))
            .bold()
            .fontSize(20.0)
            .hAlign(HorizontalAlignment.Center)
            .toElement(),
        button("New Game")
            .onClick(resetHandler)
            .hAlign(HorizontalAlignment.Center)
            .toElement()
    ])
        .spacing(8.0)
        .margin(Thickness(0.0, 12.0, 0.0, 4.0))
        .toElement()

    let board = msBuildBoard(game, dispatch)

    let titleBar = TitleBar("windows_reactor — minesweeper").toElement()

    vstack([
        titleBar,
        vstack([header, board]).spacing(12.0).toElement()
    ]).toElement()
}
