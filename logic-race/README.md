# LogicRace

A ranked logic-puzzle runner for iOS and Android, built with Godot 4.7.

Every puzzle is generated on the spot, the pool is drawn at random each time, and
you get two lives. A wrong answer costs one. Letting the clock run out costs one.
At zero the round ends and your MMR moves — up or down.

---

## Playing

- **Play** starts a round at level 1.
- Each puzzle comes from one of five pools, picked at random:

| Pool | What you do | Time budget |
| --- | --- | --- |
| Mini Sudoku | Fill a 4×4 (or 6×6 from mid difficulty) grid; it checks itself when the last blank is filled | 45–112 s |
| Pattern Snap | Five elements of a sequence, pick the sixth from four options | 18–32 s |
| Target Number | Fold four numbers into the target (usually 24) with + − × ÷ | 40–60 s |
| Minesweeper | Clear every safe cell on a 5×5 to 8×8 board; long-press or the flag button to mark | 31–83 s |
| Mental Math | One expression, four answers | 11–20 s |

- Solving a puzzle advances the level. Difficulty only ever grows with the level —
  **the clock is never shortened to make things harder**, it grows with the size of
  the task instead.
- Only the level, the remaining lives and a hairline timer are on screen. The timer
  can be turned off in settings.

## Ranks and MMR

Eight ranks, starting at 0 MMR:

| Rank | From |
| --- | --- |
| Bronze | 0 |
| Silver | 700 |
| Gold | 1 500 |
| Platinum | 2 400 |
| Diamond | 3 400 |
| Master | 4 500 |
| Grandmaster | 5 700 |
| Champion | 7 000 |

A round is scored on two things:

**Levels cleared (the heavy component).** Each rating has an expected number of
cleared levels — `5 + MMR × 0.0055`, so about 5 at Bronze entry and about 41 at
Champion entry. Every level above that expectation is worth `+26` raw points,
every level below it is worth `−26`. The result is then scaled by tier: Bronze
gains ×1.35 and loses ×0.50, Champion gains ×0.65 and loses ×1.50. The ladder is
meant to bite — a bad round at a high rank hurts.

**Speed (bonus only).** The expectation is that, averaged over the puzzles you
solved, 35 % of the time budget is still on the clock. Beat that and you get bonus
MMR on top (capped at +40, tier-scaled). Fall short and nothing happens — speed can
never subtract rating. Only the level component can.

MMR never drops below 0.

Difficulty also ramps per rank: a Bronze player reaches maximum puzzle difficulty at
level 46, a Diamond player at level 27, a Champion at level 18. Same level, harder
puzzle, the higher you are.

## Saving

No account, no login, no network. Everything lives in one JSON file in `user://`
(app-private storage on Android, the app sandbox on iOS): rating, rank, stats,
settings, and the fingerprint history that stops a puzzle from being served twice.

The history keeps the last 3 000 fingerprints **per pool**. Every generated puzzle
is hashed, and the factory retries up to 48 times to find one you have not seen. A
repeat only happens when the generator genuinely cannot produce anything new at that
difficulty.

---

## Project layout

```
scenes/main.tscn            the only scene; every screen is built in code
scripts/
  main.gd                   root controller: background, safe area, screen stack
  autoload/
    save_data.gd            persistence + puzzle history
    palette.gd              colours, type, theme, animated light/dark blend
    sfx.gd                  synthesised UI sounds (no audio files ship)
    ranks.gd                ladder + MMR maths
    puzzle_factory.gd       random pool pick, generation, dedupe
  gen/                      the five procedural generators (engine-free RefCounteds)
  puzzles/                  one view per pool, all extending PuzzleView
  screens/                  menu, game, result, settings sheet
  ui/                       buttons, cards, switches, logo, HUD pieces
assets/shaders/             rounded-gradient and backdrop shaders
tools/                      test harnesses (not part of a build)
```

Nothing is loaded from disk except the two shaders and the icon. The logo, every
icon, every sound and every puzzle is generated in code, which is why the whole
project is a few hundred kilobytes.

### Design

Light and dark are two complete palettes in `palette.gd`; the toggle cross-fades
between them instead of cutting, and every custom control redraws off one
`Palette.changed` signal. Type is the platform UI font (SF Pro on iOS, Roboto on
Android, Segoe UI on Windows) at three weights. Surfaces are white cards on a soft
tinted backdrop, 22–48 px corner radii, blue accent gradients on anything actionable.

## Running the tests

```bash
godot --headless --path . --script res://tools/selftest.gd
```

Validates the generators across the whole difficulty range: sudoku puzzles have
exactly one solution, minesweeper boards are solvable by logic alone, every target
is reachable, every arithmetic expression is re-evaluated independently with Godot's
`Expression` parser, and answer options are unique and correctly indexed. It also
reports generation cost and fingerprint spread.

```bash
godot --headless --path . --script res://tools/playtest.gd
```

Drives a real round through the real screens: each pool is solved through its own
input path, a wrong answer and a timeout each cost exactly one life, two lost lives
end the round, and the MMR result is written and survives a reload.

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
