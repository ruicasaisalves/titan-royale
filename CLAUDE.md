# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Titan Royale — a 2D auto-battle royale prototype built in **Godot 4.2+** (GDScript). The player
controls 1 fighter among 99 AI-controlled opponents, survives to the top 6, and the survivors become
**×10 titans** in a shrunk arena for a final showdown. 7 classes (including a Necromancer that raises
loyal zombies, and a Priest that regenerates HP), plus a simple item/pickup system (weapons, armor,
amulets).

Code comments, UI strings, and the README are in **Portuguese**; identifiers (class/variable/function
names) are in English. Match the existing language split when editing: keep comments in Portuguese,
identifiers in English, unless the user asks otherwise.

There is no build system, package manager, linter, or test suite in this repo — it's a pure Godot
project. There is nothing to install/build/lint/test from the CLI.

## Running the project

1. Install Godot 4.2+.
2. Open the `titan-royale` folder in the Godot editor (imports via `project.godot`).
3. Press **Play (F5)**. The main scene is `scenes/Main.tscn`.

Controls: WASD/arrows to move, Space to attack, Shift to dash; dragging the mouse also moves the
player.

The scene tree itself is nearly empty (`scenes/Main.tscn` just hosts the `Main.gd` root node) —
essentially all UI (character creation screen + HUD) and all fighters/items are built and added at
runtime from GDScript rather than laid out in the editor. When changing UI, edit the `_build_*`
functions in `scripts/Main.gd` rather than looking for editor-authored nodes.

## Architecture

The design goal stated in the README is to support **future multiplayer without rewriting the game**.
Everything flows from one rule: **a `Fighter` never decides anything for itself.**

### Controller → Intent → Simulation

- Each tick, a fighter's `controller` (`scripts/Controller.gd` base class) produces an `Intent`
  (`scripts/Intent.gd`: move vector, attack bool, dash bool).
- `AIController` (`scripts/AIController.gd`) decides by finding the nearest valid enemy via the
  spatial grid and moving into range / attacking.
- `PlayerController` (`scripts/PlayerController.gd`) reads keyboard/mouse input into the same
  `Intent` shape.
- A future `RemoteController` would read an `Intent` off the network — the simulation would not
  need to change. Adding multiplayer means adding that controller and swapping it onto
  `Fighter.controller`; nothing else in `Arena` changes.
- `Fighter.is_player()` checks `controller is PlayerController` — that's the only place "is this the
  human" is determined.

### Arena is the authoritative simulation

`scripts/Arena.gd` is the core. It runs a fixed-step tick in `_physics_process` (60 Hz), in a fixed,
deterministic order each frame:

1. every controller decides its `Intent`
2. apply movement
3. separate overlapping fighters + clamp to world bounds
4. resolve attacks (`_do_attack` / `_apply_hit`)
5. regen/timers
6. phase transitions

This ordering matters — it's what would let the simulation later run on a server with clients only
sending Intents and rendering results. `Phase` enum: `IDLE → MELEE → TRANSITION → TITAN → VICTORY`.
`_check_top6()` triggers the `MELEE → TRANSITION → TITAN` shift; `_start_titans()` scales up the top-6
survivors ×10 (hp/atk/size), repositions them in a circle, and clears zombies/items.

### Teams and loyalty

Every `Fighter` has an integer `team` (unique per fighter by default). Zombies raised by a Necromancer
inherit the necromancer's `team`, so they fight for it and never attack it. `Fighter.contender`
(`true` by default, `false` for zombies) marks who can win / become a titan — check this rather than
assuming "alive" means "still in contention."

### Spatial grid

`scripts/SpatialGrid.gd` buckets fighters into cells (`cell_size = 100`) so `AIController` and
`Arena._separate`/`_do_attack` query nearby neighbors instead of doing all-vs-all comparisons. It's
rebuilt every tick (`Arena._rebuild_grid`) before intents are computed. Any code that needs "fighters
near position X" should go through `grid.query(pos, radius)`, not iterate `arena.fighters` directly
(there's a fallback full scan in `AIController._find_target` for the rare empty-neighborhood case, but
that's the exception, not the pattern to copy).

### Stats/classes

`scripts/Archetypes.gd` is an autoload singleton (`Arch`) holding the `DATA` dictionary of all 7
classes' base stats (hp/atk/def/speed/range/cd/size/color) plus class-specific flags (`necro`,
`regen`/`regen_every`). Each class's `name`/`role` are `{"pt": ..., "en": ...}` dicts (see
Localization below); read them via `Arch.disp(cls)`/`Arch.role(cls)`, never `DATA[cls]["name"]`
directly. The dictionary **keys** (`"Bruto"`, `"Assassino"`, ...) are the internal class identifiers
used everywhere in code (`Fighter.cls`, `is_necro` checks, etc.) — they are not display strings, so
don't localize them. `Arena._make_fighter`/`_make_player`/`_make_zombie` derive actual fighter
instances from this data (with per-fighter jitter, player bonuses, or zombie stat fractions). To
add/tune a class, edit `Archetypes.DATA`; to change how a class's flags translate into behavior, look
at `_make_fighter` and the corresponding check in `Arena` (e.g. `is_necro` handling in `_apply_hit`,
`regen_pct`/`regen_every` handling in `_regen`).

### Localization (PT/EN)

The game ships in Portuguese and English only. `scripts/Loc.gd` is an autoload singleton (`Loc`) that
detects the system language once at startup (`OS.get_locale_language() == "pt"` → `"pt"`, everyone
else → `"en"`) and exposes `Loc.lang` plus `Loc.t(key, args := [])`. Every player-facing string lives
in `Loc.STRINGS` as a `{"pt": ..., "en": ...}` entry (class name/role strings live in
`Archetypes.DATA` instead, keyed the same way). When adding or changing UI text, add a key to
`Loc.STRINGS` and call `Loc.t(...)` — never hard-code a display string in `Main.gd`/`Arena.gd`. `%`
formatting is done by passing `args` (e.g. `Loc.t("hud_alive", [n])`). This is distinct from the
Portuguese-comment / English-identifier rule, which still applies to code.

### Rendering

Fighters and items draw themselves via `_draw()` (`scripts/Fighter.gd`, `scripts/Item.gd`) — there are
no sprites/animations yet; `queue_redraw()` is called explicitly each tick from `Arena`. Swapping in
real sprites means replacing these `_draw()` calls with `AnimatedSprite2D` nodes, not touching the
simulation logic.
