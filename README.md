# LogicRace

A ranked logic-puzzle runner for iOS and Android, built with Godot 4.7.

Every puzzle is generated on the spot, the pool is drawn at random each time, and
you get two lives. A wrong answer costs one. Letting the clock run out costs one.
At zero the round ends and your IQ points move — up or down.

---

## Playing

- **Play** starts a round at level 1.
- Each puzzle comes from one of seven pools, picked at random:

| Pool | What you do | Time budget |
| --- | --- | --- |
| Mini Sudoku | Fill a 4×4 (or 6×6 from mid difficulty) grid; every entry flashes green or red at once | 45–112 s |
| Pattern Snap | Five elements of a sequence, pick the sixth from four options | 18–33 s |
| Target Number | Fold four numbers into the target (usually 24) with + − × ÷ | 40–60 s |
| Minesweeper | Clear every safe cell on a 5×5 to 8×8 board; long-press or the flag button to mark | 36–83 s |
| Mental Math | One expression, four answers | 11–20 s |
| Chess Mate | Find mate in 1, 2 or 3 on a 3×3 to 6×6 board | 40–97 s |
| Water Sort | Pour coloured liquid between tubes until each holds a single colour | 68–108 s |

- Solving a puzzle advances the level. Difficulty only ever grows with the level —
  **the clock is never shortened to make things harder**, it grows with the size of
  the task instead.
- Only the level, the remaining lives and a hairline timer are on screen. The timer
  can be turned off in settings.
- Leaving a round mid-way is not an escape hatch: it is scored exactly as if the
  last life had been lost. Two taps, so it never happens by accident.

### Mini Sudoku

Tap a cell, tap a digit. The cell flashes green and the digit locks in, or it
flashes red — and a red flash is a wrong answer, so it costs a life just like a
wrong pick anywhere else. Digits grey out on the pad as soon as all of their
copies are on the board, so the pad doubles as a tally.

### Pattern Snap

The visual pools carry the weight here: 40 % of sequences are shapes, 30 % letters,
30 % numbers. A shape element has five attributes — glyph, rotation, fill, repeat
count and accent colour — and the harder rules advance several at once. Letters run
from plain alphabet steps up to both-ends weaves, Fibonacci positions and squares;
numbers up to tribonacci, primes and digit reversal.

### Chess Mate

A complete miniature chess engine: legal moves for K/Q/R/B/N/P, check, mate and
stalemate, and a forced-mate search. No castling, no en passant, no double pawn
step; pawns promote to a queen. Every position is proved before it is served —
White must have a forced mate in exactly N with exactly one winning first move.
Each of your moves has to keep the mate alive; anything else is a wrong answer.

### Water Sort

Four units per tube, three to seven colours, one or two spares. You may pour onto
a matching colour or into an empty tube, and the whole top run moves at once.
Deals are random but *proved solvable* by a depth-first search over canonical
states before they are handed out. Undo is always available.

## Ranks and IQ points

Eight ranks, each split into three divisions — twenty-four steps from **Bronze 1**
to **Champion 3**. Everyone starts at 0 IQ.

| Rank | From | Divisions at |
| --- | --- | --- |
| Bronze | 0 | 0 / 233 / 467 |
| Silver | 700 | 700 / 967 / 1 233 |
| Gold | 1 500 | 1 500 / 1 800 / 2 100 |
| Platinum | 2 400 | 2 400 / 2 733 / 3 067 |
| Diamond | 3 400 | 3 400 / 3 767 / 4 133 |
| Master | 4 500 | 4 500 / 4 900 / 5 300 |
| Grandmaster | 5 700 | 5 700 / 6 133 / 6 567 |
| Champion | 7 000 | 7 000 / 7 800 / 8 600 |

A round is scored on two things:

**Levels cleared (the heavy component).** Each rating has an expected number of
cleared levels — `5 + IQ × 0.0042`, so about 5 at Bronze entry and about 34 at
Champion entry. Every level above that expectation is worth `+34` raw points,
every level below it `−34`. The result is then scaled by rank: Bronze gains ×1.35
and loses ×0.50, Champion gains ×0.65 and loses ×1.50. The ladder is meant to bite
— a bad round at a high rank hurts.

**Speed (bonus only).** The expectation is that, averaged over the puzzles you
solved, 35 % of the time budget is still on the clock. Beat that and you get bonus
IQ on top (capped at +55, rank-scaled). Fall short and nothing happens — speed can
never subtract points. Only the level component can.

IQ never drops below 0.

Difficulty also ramps per rank: a Bronze player reaches maximum puzzle difficulty at
level 46, a Diamond player at level 27, a Champion at level 18. Same level, harder
puzzle, the higher you are.

## Developer mode

A switch at the bottom of Settings. Turning it **on** takes a snapshot of your real
progress; turning it **off** puts that snapshot back, so nothing done while testing
can reach the record — not the rating, not the best level, not even the puzzle
history.

While it is on you get:

- **IQ points** ±400, and a **rank step** that jumps to the next or previous division
- **Start level** ±5, so a round can begin deep in the difficulty ramp
- **Force pool** — cycle through the seven pools or leave it random
- **Infinite lives** and **freeze timer**
- an in-round strip with **Solve**, **+5 Lv**, **+Life** and **Skip**

## Saving

No account, no login, no network. Everything lives in one JSON file in `user://`
(app-private storage on Android, the app sandbox on iOS): rating, rank, stats,
settings, and the fingerprint history that stops a puzzle from being served twice.

The history keeps the last 8 000 fingerprints **per pool**. Every generated puzzle
is hashed, and the factory retries up to 64 times to find one you have not seen —
and if a pool really is exhausted at that difficulty it moves to a different pool
rather than repeat itself. A repeat only happens once every pool has run dry.

---

## Project layout

```
scenes/main.tscn            the only scene; every screen is built in code
scripts/
  main.gd                   root controller: background, safe area, screen stack
  autoload/
    save_data.gd            persistence, puzzle history, developer snapshot
    palette.gd              colours, type, animated light/dark blend
    sfx.gd                  synthesised UI sounds (no audio files ship)
    ranks.gd                ladder, divisions and IQ maths
    puzzle_factory.gd       random pool pick, generation, dedupe
  gen/                      the seven procedural generators (engine-free)
  puzzles/                  one view per pool, all extending PuzzleView
  screens/                  menu, game, result, settings sheet
  ui/                       buttons, cards, switches, logo, chess glyphs, HUD
assets/shaders/             rounded-gradient and backdrop shaders
tools/                      test harnesses (not part of a build)
```

Nothing is loaded from disk except the two shaders and the icon. The logo, every
icon, every chess piece and every sound is generated in code.

### Design

Arcade violet. A deep indigo stage with two saturated blooms behind it, panels that
sit on the stage with a faint light edge, and buttons built as a coloured face on a
darker plate — pressing pushes the face down onto the plate rather than shrinking
it. Violet-to-fuchsia for anything you can press, mint for success, gold for
records. Both light and dark themes share that identity.

The `Theme` resource carries type only and is built once; colours live on nodes
(`TintLabel`) or are read at draw time, so switching themes is a repaint rather
than a theme re-propagation through the whole tree every frame. Type is the
platform UI font (SF Pro on iOS, Roboto on Android, Segoe UI on Windows) at three
weights.

The chessboard keeps its own lavender/periwinkle palette and coordinate frame in
both themes, so it always reads as a chessboard.

## Running the tests

```bash
godot --headless --path . --script res://tools/selftest.gd
```

Validates the generators across the whole difficulty range: sudoku puzzles have
exactly one solution, minesweeper boards are solvable by logic alone, every target
is reachable, every water-sort deal re-proves as solvable, every chess puzzle
re-proves as a unique mate at the stated depth, and every arithmetic expression is
re-evaluated independently with Godot's `Expression` parser. It also reports
generation cost and fingerprint spread.

```bash
godot --headless --path . --script res://tools/chesstest.gd
```

Chess engine checks against positions worked out by hand — a known mate in one, a
stalemate that must not count as mate, pawn promotion — so the generator is not
merely agreeing with itself.

```bash
godot --headless --path . --script res://tools/playtest.gd
```

Drives a real round through the real screens: each pool is solved through its own
input path, a wrong answer and a timeout each cost exactly one life, two lost lives
end the round, quitting is armed and still scored, developer mode leaves the save
untouched, and the IQ result survives a reload.

```bash
godot --path . --script res://tools/shots.gd
```

Writes screenshots of every screen to `user://shots/` for design review.

## Building for mobile

The project is already configured for handhelds: portrait lock, `canvas_items`
stretch on a 720×1560 design canvas, the GL Compatibility renderer on mobile,
ETC2/ASTC texture import, touch input, and safe-area insets read from
`DisplayServer.get_display_safe_area()` so notches and home indicators are avoided.

To produce builds you still need the platform toolchains, which are not part of this
repository:

1. Install the export templates for 4.7 (`Editor → Manage Export Templates`).
2. **Android**: install the Android SDK and a debug keystore, point the editor at them
   in `Editor Settings → Export → Android`, then add an Android preset. Enable the
   `VIBRATE` permission — the haptics setting uses `Input.vibrate_handheld()`.
3. **iOS**: export on macOS with Xcode installed, then build and sign the generated
   Xcode project.

`tools/` is only test code; exclude it with an export filter (`tools/*`) so it does
not ship.
