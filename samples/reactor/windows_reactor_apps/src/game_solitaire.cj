package windows_reactor_apps

// ============================================================================
// game_solitaire — Klondike Solitaire game body.
//
// Reference: apps/examples/solitaire.rs
// Window title: "Solitaire"
//
// Click any face-up card to auto-move it to its best destination (foundation
// first, then tableau). Click the stock to draw; click the recycle icon to
// flip the waste back. Only Kings may fill empty tableau columns.
//
// Port notes (behaviour equivalence, not API-surface match):
//   * The reference `Game` is a value struct used with `use_reducer`; here it is
//     an Equatable class (SolGame) with deep value-equality + an explicit deep
//     `clone()`, so `Updater.call(prev -> next)` short-circuits on no-op moves
//     exactly like the reference (which relied on derive(PartialEq)).
//   * `Suit as usize` is modelled as `index(): Int64`.
//   * Vecs are ArrayList; every mutation path clones first (no in-place mutation
//     of `prev`), matching the reference `game.clone()` discipline.
//   * Card click is wired through Canvas-child pointer-released handlers, the
//     framework's behaviour-equivalent of the reference `.on_pointer_released`.
//   * The "New Game" seed uses wall-clock nanoseconds since the Unix epoch — the
//     behaviour-equivalent of the reference SystemTime::now().as_nanos().
//   * All top-level identifiers are `Sol`/`sol`-prefixed so this file shares the
//     `windows_reactor_apps` package namespace without colliding with the other
//     game files (which also define `Game`, `buildBoard`, `statusLine`, `Lcg`).
// ============================================================================

import std.collection.*
import std.overflow.*
import std.time.DateTime
import windows_reactor.core.*

// ─── Constants ──────────────────────────────────────────────────────────────

let SOL_PILES: Int64 = 7
let SOL_FOUNDATIONS: Int64 = 4
let SOL_DECK_SIZE: Int64 = 52

// ─── Suit ───────────────────────────────────────────────────────────────────

enum SolSuit <: Equatable<SolSuit> {
    | SuitSpades
    | SuitHearts
    | SuitDiamonds
    | SuitClubs

    // Stable 0..=3 index (the reference `Suit as u8`).
    func index(): Int64 {
        match (this) {
            case SuitSpades => 0
            case SuitHearts => 1
            case SuitDiamonds => 2
            case SuitClubs => 3
        }
    }

    static func all(): Array<SolSuit> {
        [SolSuit.SuitSpades, SolSuit.SuitHearts, SolSuit.SuitDiamonds, SolSuit.SuitClubs]
    }

    func isRed(): Bool {
        match (this) {
            case SuitHearts => true
            case SuitDiamonds => true
            case _ => false
        }
    }

    func symbol(): String {
        match (this) {
            case SuitSpades => "\u{2660}"   // ♠
            case SuitHearts => "\u{2665}"   // ♥
            case SuitDiamonds => "\u{2666}" // ♦
            case SuitClubs => "\u{2663}"    // ♣
        }
    }

    public operator func ==(other: SolSuit): Bool { index() == other.index() }
    public operator func !=(other: SolSuit): Bool { index() != other.index() }
}

// ─── Card ───────────────────────────────────────────────────────────────────

struct SolCard <: Equatable<SolCard> {
    let rank: Int64 // 1=A, 11=J, 12=Q, 13=K
    let suit: SolSuit

    init(rank: Int64, suit: SolSuit) {
        this.rank = rank
        this.suit = suit
    }

    func isRed(): Bool { suit.isRed() }

    func rankLabel(): String {
        match (rank) {
            case 1 => "A"
            case 2 => "2"
            case 3 => "3"
            case 4 => "4"
            case 5 => "5"
            case 6 => "6"
            case 7 => "7"
            case 8 => "8"
            case 9 => "9"
            case 10 => "10"
            case 11 => "J"
            case 12 => "Q"
            case 13 => "K"
            case _ => "?"
        }
    }

    func label(): String { "${rankLabel()}${suit.symbol()}" }

    public operator func ==(other: SolCard): Bool {
        rank == other.rank && suit == other.suit
    }
    public operator func !=(other: SolCard): Bool { !(this == other) }
}

// ─── Click / Source / Dest / LastMove / FailedMove ─────────────────────────

enum SolClick {
    | ClickStock
    | ClickWaste
    | ClickFoundation(Int64)
    | ClickTableau(Int64, Int64) // (pile, card_index)
}

enum SolSource {
    | SrcWaste
    | SrcFoundation(Int64)
    | SrcTableau(Int64, Int64) // (pile, first_card_index)
}

enum SolDest {
    | DestTableau(Int64)
    | DestFoundation(Int64)
}

enum SolLastMove <: Equatable<SolLastMove> {
    | LastToFoundation(Int64)
    | LastToTableau(Int64)

    public operator func ==(other: SolLastMove): Bool {
        match ((this, other)) {
            case (LastToFoundation(a), LastToFoundation(b)) => a == b
            case (LastToTableau(a), LastToTableau(b)) => a == b
            case _ => false
        }
    }
    public operator func !=(other: SolLastMove): Bool { !(this == other) }
}

enum SolFailedMove <: Equatable<SolFailedMove> {
    | FailedTableau(Int64, Int64)
    | FailedWaste

    public operator func ==(other: SolFailedMove): Bool {
        match ((this, other)) {
            case (FailedTableau(a, b), FailedTableau(c, d)) => a == c && b == d
            case (FailedWaste, FailedWaste) => true
            case _ => false
        }
    }
    public operator func !=(other: SolFailedMove): Bool { !(this == other) }
}

// ─── Game state ─────────────────────────────────────────────────────────────
//
// Reference-equivalent class with deep value-equality. useReducer requires
// Equatable; the reducer compares prev == next to short-circuit no-op moves
// (the reference relied on derive(PartialEq)).

class SolGame <: Equatable<SolGame> {
    var tableau: ArrayList<ArrayList<SolCard>>     // SOL_PILES columns
    var faceUp: ArrayList<Int64>                   // cards at idx >= faceUp[p] are face-up
    var foundations: ArrayList<ArrayList<SolCard>> // indexed by Suit, builds A→K
    var stock: ArrayList<SolCard>                  // last = next to draw
    var waste: ArrayList<SolCard>                  // last = top
    var lastMove: ?SolLastMove
    var failedMove: ?SolFailedMove
    var moves: Int64

    init(
        tableau: ArrayList<ArrayList<SolCard>>,
        faceUp: ArrayList<Int64>,
        foundations: ArrayList<ArrayList<SolCard>>,
        stock: ArrayList<SolCard>,
        waste: ArrayList<SolCard>,
        lastMove: ?SolLastMove,
        failedMove: ?SolFailedMove,
        moves: Int64
    ) {
        this.tableau = tableau
        this.faceUp = faceUp
        this.foundations = foundations
        this.stock = stock
        this.waste = waste
        this.lastMove = lastMove
        this.failedMove = failedMove
        this.moves = moves
    }

    static func newGame(seed: UInt64): SolGame {
        let deck = solFullDeck()
        solShuffle(deck, seed)

        let tableau = ArrayList<ArrayList<SolCard>>()
        for (_ in 0..SOL_PILES) {
            tableau.add(ArrayList<SolCard>())
        }
        // Deal: for p in 0..PILES, push one card onto every pile from index p up.
        for (p in 0..SOL_PILES) {
            for (q in p..SOL_PILES) {
                tableau[q].add(solPopLast(deck))
            }
        }
        let faceUp = ArrayList<Int64>()
        for (p in 0..SOL_PILES) {
            faceUp.add(tableau[p].size - 1)
        }

        // Ace rescue: swap any face-down Ace in the tableau with a non-Ace from
        // the stock so Aces are always reachable.
        for (p in 0..SOL_PILES) {
            var i = 0
            while (i < faceUp[p]) {
                if (tableau[p][i].rank == 1) {
                    match (solPositionNonAce(deck)) {
                        case Some(swapIdx) =>
                            let tmp = tableau[p][i]
                            tableau[p][i] = deck[swapIdx]
                            deck[swapIdx] = tmp
                        case None => ()
                    }
                }
                i++
            }
        }

        let foundations = ArrayList<ArrayList<SolCard>>()
        for (_ in 0..SOL_FOUNDATIONS) {
            foundations.add(ArrayList<SolCard>())
        }

        SolGame(
            tableau,
            faceUp,
            foundations,
            deck,
            ArrayList<SolCard>(),
            None,
            None,
            0
        )
    }

    func isWon(): Bool {
        for (f in foundations) {
            if (f.size != 13) {
                return false
            }
        }
        true
    }

    // Deep clone — every mutation path clones first (the reference game.clone()).
    func clone(): SolGame {
        let t = ArrayList<ArrayList<SolCard>>()
        for (col in tableau) {
            t.add(col.clone())
        }
        let fu = ArrayList<Int64>()
        for (v in faceUp) {
            fu.add(v)
        }
        let fnd = ArrayList<ArrayList<SolCard>>()
        for (col in foundations) {
            fnd.add(col.clone())
        }
        SolGame(t, fu, fnd, stock.clone(), waste.clone(), lastMove, failedMove, moves)
    }

    public operator func ==(other: SolGame): Bool {
        moves == other.moves &&
        solCardGridEq(tableau, other.tableau) &&
        solIntListEq(faceUp, other.faceUp) &&
        solCardGridEq(foundations, other.foundations) &&
        solCardListEq(stock, other.stock) &&
        solCardListEq(waste, other.waste) &&
        solOptLastMoveEq(lastMove, other.lastMove) &&
        solOptFailedMoveEq(failedMove, other.failedMove)
    }
    public operator func !=(other: SolGame): Bool { !(this == other) }
}

// ─── Equality helpers ───────────────────────────────────────────────────────

func solCardListEq(a: ArrayList<SolCard>, b: ArrayList<SolCard>): Bool {
    if (a.size != b.size) { return false }
    var i = 0
    while (i < a.size) {
        if (a[i] != b[i]) { return false }
        i++
    }
    true
}

func solCardGridEq(a: ArrayList<ArrayList<SolCard>>, b: ArrayList<ArrayList<SolCard>>): Bool {
    if (a.size != b.size) { return false }
    var i = 0
    while (i < a.size) {
        if (!solCardListEq(a[i], b[i])) { return false }
        i++
    }
    true
}

func solIntListEq(a: ArrayList<Int64>, b: ArrayList<Int64>): Bool {
    if (a.size != b.size) { return false }
    var i = 0
    while (i < a.size) {
        if (a[i] != b[i]) { return false }
        i++
    }
    true
}

func solOptLastMoveEq(a: ?SolLastMove, b: ?SolLastMove): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x == y
        case (None, None) => true
        case _ => false
    }
}

func solOptFailedMoveEq(a: ?SolFailedMove, b: ?SolFailedMove): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x == y
        case (None, None) => true
        case _ => false
    }
}

// ─── ArrayList helpers (Vec::pop / last / position) ─────────────────────────

// Remove and return the last element. Caller guarantees non-empty.
func solPopLast(list: ArrayList<SolCard>): SolCard {
    let idx = list.size - 1
    let c = list[idx]
    list.remove(at: idx)
    c
}

func solLastCard(list: ArrayList<SolCard>): ?SolCard {
    if (list.size == 0) {
        return None
    }
    Some(list[list.size - 1])
}

// Index of the first non-Ace card in the deck (Vec::iter().position).
func solPositionNonAce(deck: ArrayList<SolCard>): ?Int64 {
    var i = 0
    while (i < deck.size) {
        if (deck[i].rank != 1) {
            return Some(i)
        }
        i++
    }
    None
}

// ─── Deck construction / shuffle / PRNG ─────────────────────────────────────

func solFullDeck(): ArrayList<SolCard> {
    let deck = ArrayList<SolCard>()
    for (suit in SolSuit.all()) {
        for (rank in 1..=13) {
            deck.add(SolCard(rank, suit))
        }
    }
    deck
}

// Fisher–Yates over a deterministic LCG, matching the reference exactly:
// for i in (1..len).rev() { j = rng.next() % (i+1); swap(i, j) }
func solShuffle(deck: ArrayList<SolCard>, seed: UInt64): Unit {
    let rng = SolLcg(seed)
    var i = deck.size - 1
    while (i >= 1) {
        let j = Int64(rng.next() % UInt64(i + 1))
        let tmp = deck[i]
        deck[i] = deck[j]
        deck[j] = tmp
        i--
    }
}

// Deterministic LCG PRNG. Wrapping (high-bit-truncating) arithmetic mirrors the
// reference wrapping_mul / wrapping_add.
class SolLcg {
    var state: UInt64

    init(seed: UInt64) {
        this.state = if (seed > 0) { seed } else { 1 }
    }

    func next(): UInt64 {
        state = state.wrappingMul(6364136223846793005u64).wrappingAdd(1442695040888963407u64)
        state
    }
}

// ─── Move rules ─────────────────────────────────────────────────────────────

func solCanStackOnTableau(moving: SolCard, top: ?SolCard): Bool {
    match (top) {
        case None => moving.rank == 13
        case Some(t) => t.rank == moving.rank + 1 && t.isRed() != moving.isRed()
    }
}

func solCanPlaceOnFoundation(moving: SolCard, foundation: ArrayList<SolCard>, fIdx: Int64): Bool {
    if (moving.suit.index() != fIdx) {
        return false
    }
    match (solLastCard(foundation)) {
        case None => moving.rank == 1
        case Some(t) => t.rank + 1 == moving.rank
    }
}

// Returns the card(s) that `src` would move (a single card, or a tableau run).
func solMovingCards(game: SolGame, src: SolSource): ?ArrayList<SolCard> {
    match (src) {
        case SrcWaste =>
            match (solLastCard(game.waste)) {
                case Some(c) =>
                    let out = ArrayList<SolCard>()
                    out.add(c)
                    Some(out)
                case None => None
            }
        case SrcFoundation(f) =>
            if (f >= game.foundations.size) {
                return None
            }
            match (solLastCard(game.foundations[f])) {
                case Some(c) =>
                    let out = ArrayList<SolCard>()
                    out.add(c)
                    Some(out)
                case None => None
            }
        case SrcTableau(p, i) =>
            if (p >= game.tableau.size) {
                return None
            }
            let pile = game.tableau[p]
            if (i >= pile.size || i < game.faceUp[p]) {
                return None
            }
            let out = ArrayList<SolCard>()
            var k = i
            while (k < pile.size) {
                out.add(pile[k])
                k++
            }
            Some(out)
    }
}

// Apply `src` → `dst`. Returns None if the move is illegal.
func solTryApply(game: SolGame, src: SolSource, dst: SolDest): ?SolGame {
    let cards = match (solMovingCards(game, src)) {
        case Some(c) => c
        case None => return None
    }
    if (cards.size == 0) {
        return None
    }
    // Reject src == dst on the same pile / foundation.
    match ((src, dst)) {
        case (SrcTableau(p1, _), DestTableau(p2)) => if (p1 == p2) { return None }
        case (SrcFoundation(f1), DestFoundation(f2)) => if (f1 == f2) { return None }
        case _ => ()
    }
    let first = cards[0]
    let valid = match (dst) {
        case DestFoundation(f) =>
            cards.size == 1 && solCanPlaceOnFoundation(first, game.foundations[f], f)
        case DestTableau(p) =>
            solCanStackOnTableau(first, solLastCard(game.tableau[p]))
    }
    if (!valid) {
        return None
    }

    let next = game.clone()
    match (src) {
        case SrcWaste =>
            let _ = solPopLast(next.waste)
        case SrcFoundation(f) =>
            let _ = solPopLast(next.foundations[f])
        case SrcTableau(p, i) =>
            solTruncate(next.tableau[p], i)
            if (next.tableau[p].size == 0) {
                next.faceUp[p] = 0
            } else if (next.faceUp[p] >= next.tableau[p].size) {
                next.faceUp[p] = next.tableau[p].size - 1
            }
    }
    match (dst) {
        case DestTableau(p) =>
            let wasEmpty = next.tableau[p].size == 0
            for (c in cards) {
                next.tableau[p].add(c)
            }
            if (wasEmpty) {
                next.faceUp[p] = 0
            }
        case DestFoundation(f) =>
            next.foundations[f].add(first)
    }
    next.moves = solSaturatingAddU32(next.moves)
    next.lastMove = match (dst) {
        case DestFoundation(f) => Some(SolLastMove.LastToFoundation(f))
        case DestTableau(p) => Some(SolLastMove.LastToTableau(p))
    }
    Some(next)
}

// Vec::truncate(len): drop everything at index >= len.
func solTruncate(list: ArrayList<SolCard>, len: Int64): Unit {
    while (list.size > len) {
        list.remove(at: list.size - 1)
    }
}

// moves: u32 saturating_add(1). u32::MAX == 4294967295.
func solSaturatingAddU32(v: Int64): Int64 {
    if (v >= 4294967295) { 4294967295 } else { v + 1 }
}

func solDrawStock(game: SolGame): SolGame {
    let next = game.clone()
    if (next.stock.size > 0) {
        let c = solPopLast(next.stock)
        next.waste.add(c)
        next.moves = solSaturatingAddU32(next.moves)
    } else if (next.waste.size > 0) {
        while (next.waste.size > 0) {
            let c = solPopLast(next.waste)
            next.stock.add(c)
        }
        next.moves = solSaturatingAddU32(next.moves)
    }
    next.lastMove = None
    next
}

// Auto-move: try foundation first (single card), then the tableau pile with the
// most face-down cards (productive move), then an empty pile (Kings only).
func solAutoMove(game: SolGame, src: SolSource): ?SolGame {
    let cards = match (solMovingCards(game, src)) {
        case Some(c) => c
        case None => return None
    }
    if (cards.size == 0) {
        return None
    }
    let first = cards[0]

    if (cards.size == 1) {
        let f = first.suit.index()
        match (solTryApply(game, src, SolDest.DestFoundation(f))) {
            case Some(g) => return Some(g)
            case None => ()
        }
    }

    let srcPile: ?Int64 = match (src) {
        case SrcTableau(p, _) => Some(p)
        case _ => None
    }

    var bestFaceDown: ?Int64 = None
    var bestGame: ?SolGame = None
    for (p in 0..SOL_PILES) {
        let isSrc = match (srcPile) {
            case Some(sp) => sp == p
            case None => false
        }
        if (isSrc || game.tableau[p].size == 0) {
            continue
        }
        match (solTryApply(game, src, SolDest.DestTableau(p))) {
            case Some(g) =>
                let faceDown = game.faceUp[p]
                let replace = match (bestFaceDown) {
                    case Some(bfd) => bfd < faceDown
                    case None => true
                }
                if (replace) {
                    bestFaceDown = Some(faceDown)
                    bestGame = Some(g)
                }
            case None => ()
        }
    }
    match (bestGame) {
        case Some(g) => return Some(g)
        case None => ()
    }

    if (first.rank == 13) {
        let dominated = match (src) {
            case SrcTableau(p, idx) => idx == 0 && game.faceUp[p] == 0
            case _ => false
        }
        if (!dominated) {
            for (p in 0..SOL_PILES) {
                let isSrc = match (srcPile) {
                    case Some(sp) => sp == p
                    case None => false
                }
                if (isSrc || game.tableau[p].size != 0) {
                    continue
                }
                match (solTryApply(game, src, SolDest.DestTableau(p))) {
                    case Some(g) => return Some(g)
                    case None => ()
                }
            }
        }
    }

    None
}

// Interpret a click and return the new game state.
func solHandleClick(game: SolGame, click: SolClick): SolGame {
    match (click) {
        case ClickStock =>
            let g = solDrawStock(game)
            g.failedMove = None
            g
        case ClickWaste =>
            if (game.waste.size == 0) {
                return game.clone()
            }
            match (solAutoMove(game, SolSource.SrcWaste)) {
                case Some(g) =>
                    g.failedMove = None
                    g
                case None =>
                    let next = game.clone()
                    next.lastMove = None
                    next.failedMove = Some(SolFailedMove.FailedWaste)
                    next
            }
        case ClickFoundation(f) =>
            if (game.foundations[f].size == 0) {
                return game.clone()
            }
            match (solAutoMove(game, SolSource.SrcFoundation(f))) {
                case Some(g) =>
                    g.failedMove = None
                    g
                case None =>
                    let next = game.clone()
                    next.lastMove = None
                    next.failedMove = None
                    next
            }
        case ClickTableau(p, i) =>
            let pile = game.tableau[p]
            if (pile.size == 0 || i < game.faceUp[p] || i >= pile.size) {
                return game.clone()
            }
            match (solAutoMove(game, SolSource.SrcTableau(p, i))) {
                case Some(g) =>
                    g.failedMove = None
                    g
                case None =>
                    let next = game.clone()
                    next.lastMove = None
                    next.failedMove = Some(SolFailedMove.FailedTableau(p, i))
                    next
            }
    }
}

// ─── Layout constants ───────────────────────────────────────────────────────

let SOL_CARD_W: Float64 = 56.0
let SOL_CARD_H: Float64 = 80.0
let SOL_CARD_GAP_X: Float64 = 14.0
let SOL_FACE_UP_OFFSET: Float64 = 22.0
let SOL_FACE_DOWN_OFFSET: Float64 = 8.0
let SOL_TOP_ROW_Y: Float64 = 20.0
let SOL_TABLEAU_Y: Float64 = 130.0
let SOL_BOARD_LEFT: Float64 = 20.0
let SOL_TOP_ROW_Z: Int32 = 200
let SOL_BOARD_W: Float64 = SOL_BOARD_LEFT + (SOL_CARD_W + SOL_CARD_GAP_X) * 7.0 + 20.0
let SOL_BOARD_H: Float64 = 620.0

func solCurrentSeed(): UInt64 {
    // Wall-clock nanoseconds since the Unix epoch — varies per deal, exactly the
    // behaviour the reference seed relied on.
    let ns = DateTime.nowUTC().toUnixTimeStamp().toNanoseconds()
    if (ns <= 0) {
        return 0xDEADBEEFu64
    }
    UInt64(ns)
}

func solPileX(p: Int64): Float64 {
    SOL_BOARD_LEFT + Float64(p) * (SOL_CARD_W + SOL_CARD_GAP_X)
}

func solFoundationX(f: Int64): Float64 {
    solPileX(SOL_PILES - SOL_FOUNDATIONS + f)
}

// ─── Element attached-prop helpers ──────────────────────────────────────────
//
// Canvas.Left/Top/ZIndex and pointer-released are attached props stored on the
// child's shared Modifiers. The widget builders don't expose them directly, so
// we mutate the lowered element's Modifiers in place (the proven layout idiom).

func solWithCanvas(el: Element, left: Float64, top: Float64, z: Int32): Element {
    match (el.modifiers()) {
        case Some(m) => m.canvasPosition = Some(CanvasPosition(left, top, z))
        case None => ()
    }
    el
}

func solWithCanvasTopZ(el: Element, top: Float64, z: Int32): Element {
    solWithCanvas(el, 0.0, top, z)
}

func solWithClick(el: Element, onClick: () -> Unit): Element {
    match (el.modifiers()) {
        case Some(m) =>
            let ph = match (m.pointerHandlers) {
                case Some(existing) => existing
                case None =>
                    let p = PointerHandlers()
                    m.pointerHandlers = Some(p)
                    p
            }
            ph.onPointerReleased = Some(Callback<PointerEventInfo>({ _ => onClick() }))
        case None => ()
    }
    el
}

// ─── Root component ─────────────────────────────────────────────────────────

public func solitaireApp(cx: RenderCx): Element {
    let (game, update) = cx.useReducer<SolGame>(SolGame.newGame(solCurrentSeed()))

    let clickHandler: (SolClick) -> Unit = { c: SolClick =>
        update.call({ prev: SolGame => solHandleClick(prev, c) })
    }

    let newGameHandler: () -> Unit = { =>
        let seed = solCurrentSeed()
        update.call({ _prev: SolGame => SolGame.newGame(seed) })
    }

    let header = hstack([
        button("New Game").onClick(newGameHandler).toElement(),
        text_block(solStatusLine(game))
            .vAlign(VerticalAlignment.Center)
            .foregroundTheme(ThemeRef.PrimaryText)
            .toElement()
    ])
        .spacing(12.0)
        .margin(Thickness(12.0, 8.0, 12.0, 4.0))
        .toElement()

    let titleBar = title_bar("Solitaire")
        .subtitleOf(if (game.isWon()) { "\u{1F389} You win!" } else { "" })
        .toElement()

    let board = viewbox(solBuildBoard(game, clickHandler)).toElement()

    vstack([titleBar, header, board])
        .background(Brush.Solid(Color.rgb(20u8, 100u8, 60u8)))
        .toElement()
}

func solStatusLine(game: SolGame): String {
    if (game.isWon()) {
        "\u{1F389} You won! Press New Game to deal again."
    } else {
        "Moves: ${game.moves}    Stock: ${game.stock.size}    Waste: ${game.waste.size}"
    }
}

func solBuildBoard(game: SolGame, click: (SolClick) -> Unit): Element {
    let children = ArrayList<Element>()

    children.add(solStockView(game, click))
    children.add(solWasteView(game, click))
    for (f in 0..SOL_FOUNDATIONS) {
        children.add(solFoundationView(game, f, click))
    }
    // Stable-keyed nested Canvas per pile isolates card add/remove diffs.
    for (p in 0..SOL_PILES) {
        children.add(solTableauPileView(game, p, click))
    }

    canvas(children.toArray())
        .width(SOL_BOARD_W)
        .height(SOL_BOARD_H)
        .background(Brush.Solid(Color.rgb(20u8, 100u8, 60u8)))
        .hAlign(HorizontalAlignment.Center)
        .toElement()
}

// ─── Top row views ──────────────────────────────────────────────────────────

func solStockView(game: SolGame, click: (SolClick) -> Unit): Element {
    let x = solPileX(0)
    if (game.stock.size == 0 && game.waste.size == 0) {
        let el = solEmptySlot("\u{00B7}", "stock", Color.rgb(220u8, 230u8, 220u8),
            { => click(SolClick.ClickStock) })
        return solWithCanvas(el, x, SOL_TOP_ROW_Y, SOL_TOP_ROW_Z)
    } else if (game.stock.size == 0) {
        let label = text_block("\u{21BB}")
            .fontSize(22.0)
            .foreground(Brush.Solid(Color.rgb(255u8, 255u8, 255u8)))
            .vAlign(VerticalAlignment.Center)
            .hAlign(HorizontalAlignment.Center)
            .toElement()
        let b = border(label)
            .cornerRadius(4.0)
            .borderBrush(BrushBinding.ofColor(Color.rgb(50u8, 90u8, 60u8)))
            .borderThickness(Thickness.uniform(1.5))
            .background(Brush.Solid(Color.rgb(70u8, 110u8, 80u8)))
            .width(SOL_CARD_W)
            .height(SOL_CARD_H)
            .keyOf("stock")
            .toElement()
        let clicked = solWithClick(b, { => click(SolClick.ClickStock) })
        return solWithCanvas(clicked, x, SOL_TOP_ROW_Y, SOL_TOP_ROW_Z)
    } else {
        let el = solCardBack("stock", { => click(SolClick.ClickStock) })
        return solWithCanvas(el, x, SOL_TOP_ROW_Y, SOL_TOP_ROW_Z)
    }
}

func solWasteView(game: SolGame, click: (SolClick) -> Unit): Element {
    let x = solPileX(1)
    let failed = match (game.failedMove) {
        case Some(FailedWaste) => true
        case _ => false
    }
    match (solLastCard(game.waste)) {
        case Some(card) =>
            let el = solCardFace(card, false, failed, "waste", { => click(SolClick.ClickWaste) })
            solWithCanvas(el, x, SOL_TOP_ROW_Y, SOL_TOP_ROW_Z)
        case None =>
            let el = solEmptySlot("\u{00B7}", "waste", Color.rgb(220u8, 230u8, 220u8),
                { => click(SolClick.ClickWaste) })
            solWithCanvas(el, x, SOL_TOP_ROW_Y, SOL_TOP_ROW_Z)
    }
}

func solFoundationView(game: SolGame, f: Int64, click: (SolClick) -> Unit): Element {
    let highlighted = match (game.lastMove) {
        case Some(LastToFoundation(s)) => s == f
        case _ => false
    }
    let suit = SolSuit.all()[f]
    let x = solFoundationX(f)
    let key = "foundation-${f}"
    match (solLastCard(game.foundations[f])) {
        case Some(card) =>
            let el = solCardFace(card, highlighted, false, key, { => click(SolClick.ClickFoundation(f)) })
            solWithCanvas(el, x, SOL_TOP_ROW_Y, SOL_TOP_ROW_Z)
        case None =>
            let fg = if (suit.isRed()) {
                Color.rgb(180u8, 120u8, 120u8)
            } else {
                Color.rgb(180u8, 180u8, 180u8)
            }
            let el = solEmptySlot(suit.symbol(), key, fg, { => click(SolClick.ClickFoundation(f)) })
            solWithCanvas(el, x, SOL_TOP_ROW_Y, SOL_TOP_ROW_Z)
    }
}

// ─── Tableau ────────────────────────────────────────────────────────────────

func solTableauPileView(game: SolGame, p: Int64, click: (SolClick) -> Unit): Element {
    let pile = game.tableau[p]
    let x = solPileX(p)

    let cards = ArrayList<Element>()

    if (pile.size == 0) {
        cards.add(solEmptySlot("K", "0", Color.rgb(180u8, 200u8, 180u8),
            { => click(SolClick.ClickTableau(p, 0)) }))
    } else {
        var y = 0.0
        var i = 0
        while (i < pile.size) {
            let card = pile[i]
            let isFaceUp = i >= game.faceUp[p]
            let z = Int32(i) + 1
            let slotKey = "${i}"
            let idx = i
            let element = if (isFaceUp) {
                let highlighted = (match (game.lastMove) {
                        case Some(LastToTableau(tp)) => tp == p
                        case _ => false
                    }) && idx == pile.size - 1
                let failed = match (game.failedMove) {
                    case Some(FailedTableau(fp, fi)) => fp == p && fi == idx
                    case _ => false
                }
                let face = solCardFace(card, highlighted, failed, slotKey,
                    { => click(SolClick.ClickTableau(p, idx)) })
                solWithCanvasTopZ(face, y, z)
            } else {
                let back = solCardBack(slotKey, { => click(SolClick.ClickTableau(p, idx)) })
                solWithCanvasTopZ(back, y, z)
            }
            cards.add(element)
            y += if (isFaceUp) { SOL_FACE_UP_OFFSET } else { SOL_FACE_DOWN_OFFSET }
            i++
        }
    }

    let pileCanvas = canvas(cards.toArray())
        .width(SOL_CARD_W)
        .height(SOL_BOARD_H - SOL_TABLEAU_Y)
        .keyOf("pile-${p}")
        .toElement()
    solWithCanvas(pileCanvas, x, SOL_TABLEAU_Y, 0)
}

// ─── Card visuals ───────────────────────────────────────────────────────────

func solCardFace(card: SolCard, highlighted: Bool, failed: Bool, key: String, onClick: () -> Unit): Element {
    let fg = if (card.isRed()) {
        Color.rgb(192u8, 0u8, 32u8)
    } else {
        Color.rgb(20u8, 20u8, 20u8)
    }
    let bg = if (failed) {
        Color.rgb(255u8, 220u8, 220u8)
    } else if (highlighted) {
        Color.rgb(220u8, 245u8, 220u8)
    } else {
        Color.rgb(255u8, 255u8, 255u8)
    }
    let borderColor = if (failed) {
        Color.rgb(220u8, 80u8, 80u8)
    } else {
        Color.rgb(180u8, 180u8, 180u8)
    }
    let topLabel = text_block(card.label())
        .fontSize(13.0)
        .foreground(Brush.Solid(fg))
        .hAlign(HorizontalAlignment.Left)
        .toElement()
    let centerSuit = text_block(card.suit.symbol())
        .fontSize(22.0)
        .foreground(Brush.Solid(fg))
        .hAlign(HorizontalAlignment.Center)
        .vAlign(VerticalAlignment.Center)
        .toElement()
    let content = vstack([topLabel, centerSuit]).toElement()
    let b = border(content)
        .cornerRadius(4.0)
        .borderBrush(BrushBinding.ofColor(borderColor))
        .borderThickness(Thickness.uniform(1.0))
        .background(Brush.Solid(bg))
        .width(SOL_CARD_W)
        .height(SOL_CARD_H)
        .padding(Thickness(4.0, 3.0, 2.0, 2.0))
        .keyOf(key)
        .toElement()
    solWithClick(b, onClick)
}

func solCardBack(key: String, onClick: () -> Unit): Element {
    let label = text_block("\u{1F0A0}")
        .fontSize(18.0)
        .foreground(Brush.Solid(Color.rgb(240u8, 240u8, 255u8)))
        .vAlign(VerticalAlignment.Center)
        .hAlign(HorizontalAlignment.Center)
        .toElement()
    let b = border(label)
        .cornerRadius(4.0)
        .borderBrush(BrushBinding.ofColor(Color.rgb(30u8, 60u8, 130u8)))
        .borderThickness(Thickness.uniform(1.0))
        .background(Brush.Solid(Color.rgb(40u8, 80u8, 160u8)))
        .width(SOL_CARD_W)
        .height(SOL_CARD_H)
        .keyOf(key)
        .toElement()
    solWithClick(b, onClick)
}

func solEmptySlot(label: String, key: String, fg: Color, onClick: () -> Unit): Element {
    let tb = text_block(label)
        .fontSize(16.0)
        .foreground(Brush.Solid(fg))
        .vAlign(VerticalAlignment.Center)
        .hAlign(HorizontalAlignment.Center)
        .toElement()
    let b = border(tb)
        .cornerRadius(4.0)
        .borderBrush(BrushBinding.ofColor(Color.rgb(50u8, 110u8, 70u8)))
        .borderThickness(Thickness.uniform(1.5))
        .background(Brush.Solid(Color.rgb(40u8, 90u8, 55u8)))
        .width(SOL_CARD_W)
        .height(SOL_CARD_H)
        .opacity(0.7)
        .keyOf(key)
        .toElement()
    solWithClick(b, onClick)
}
