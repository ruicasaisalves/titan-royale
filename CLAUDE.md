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

**Versioning:** bump the version on every change. Update `config/version` in `project.godot` (and
`version/name` — plus increment `version/code` — in `export_presets.cfg`) so they stay in sync. The
scheme is `0.0XX` + a letter suffix (current: `0.033a`).

## Context budget (keep a session under ~1M tokens)

The whole source tree is tiny (~15k tokens); a session's budget is spent on its **length** and on
**large tool outputs**, not on the code. So:

- **Never dump generated/large files whole.** `export_presets.cfg` (mostly a long, all-`false`
  Android permissions list) and every `*.import` are noise — read one key with Grep, or Read with
  `offset`/`limit`, and change it with a targeted Edit; never rewrite or `cat` the file.
- **Treat `assets/` as binary** — never print PNGs; (re)generate them with `tools/gen_floors.py` /
  `tools/compose_fighters.py`, don't inline their bytes.
- **Prefer Grep/Glob over reading whole files**; pass `limit`/`head_limit`, and `tail`/filter long
  command output instead of dumping it.
- **One task per session.** Start a fresh session (or `/clear`, `/compact`) between unrelated tasks;
  a long-running session is the main way the budget is blown.

## Running the project

1. Install Godot 4.2+.
2. Open the `titan-royale` folder in the Godot editor (imports via `project.godot`).
3. Press **Play (F5)**. The main scene is `scenes/Main.tscn`.

Controls: WASD/arrows to move, Space to attack, Shift to dash; dragging the mouse also moves the
player.

The scene tree itself is nearly empty (`scenes/Main.tscn` just hosts the `Main.gd` root node) —
essentially all UI (the menu screens + HUD) and all fighters/items are built and added at
runtime from GDScript rather than laid out in the editor. When changing UI, edit the `_build_*`
functions in `scripts/Main.gd` rather than looking for editor-authored nodes.

### Menu screens

`Main` builds four full-rect `Control` screens under the `ui` `CanvasLayer`, one visible at a time,
toggled by `_show_screen(root)` (which refreshes the target). From the intro logo you land on
`menu_root` (**JOGAR / ESTILOS / DEFINIÇÕES**, via `_goto`), and each sub-screen has a `‹ Voltar`
button back to it:

- **Jogar** (`_build_play`): a 7-button champion grid (`class_buttons`); clicking one calls
  `_select_class` and `_refresh_play` fills a description panel — name, role, and an attribute bar
  per stat (`ATTR_KEYS = hp/atk/def/speed/range`, each normalized against the max across
  `Arch.DATA` by `_attr_max`). An `ENTER THE ARENA` button starts the match. **Player stats are the
  class's own** (`Arena._make_player` reads `Arch.DATA[cls]` with only the +40% hero HP bonus) — the
  old player-chosen stat-point allocation was removed; attributes are fixed and logical per class.
- **Estilos** (`_build_styles`): a champion `‹ name ›` cycler (`_cycle_class`) over a large preview,
  plus **`‹ ›` arrow rows** (`_cycle_color`, not colour swatches) for hair and cloth colour, each
  showing a colour chip sampled at runtime (`_layer_avg_color`). Appearance is per class and saved in
  `Save.data["appearance"]`.
- **Definições** (`_build_settings`): player name (persisted to `Save.data["player_name"]`), and
  brightness + music + SFX sliders. Brightness dims a black `ColorRect` overlay on a top
  `CanvasLayer` (`_apply_brightness`, `layer = 128`). Volume sliders drive dedicated **Music/SFX
  audio buses** (created under Master by `_ensure_bus`, set via `_apply_bus_volume`) — wired now so
  audio "just works" once sound is added. All three persist via `Save.get_setting`/`set_setting` and
  are re-applied on startup by `_apply_saved_settings`.

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
survivors ×10 (hp/atk), ×2.6 (size), repositions them in a circle, and clears zombies/items.

### Camera / zoom (visibility)

`Arena` owns a `Camera2D` (`camera`, made current in `_ready`). During the royale phase it is zoomed
in (`STAGE1_ZOOM = 2.5`) and follows the player each tick (only while `phase == MELEE`), so fighters
read large and only part of the world is visible — moving pans the view to find other opponents.
Fighter body sizes and world size are **unchanged**; this is purely a camera zoom, so hitboxes,
separation and reach are untouched. At `_start_titans()` the camera tweens back to zoom 1.0 and
centers, so the shrunk-arena titan showdown shows everyone at once (that's why titans keep their usual
size). `reset_to_idle()` restores zoom 1.0/centered. The HUD and menus live on a `CanvasLayer`
(`Main.ui`) and are not affected by the camera. `PlayerController` mouse-drag uses
`arena.get_local_mouse_position()`, which already accounts for the camera transform.

### Persistence & coins

`scripts/Save.gd` is an autoload singleton (`Save`) that stores a player profile
(`wins`/`losses`/`games`/`best_place`/`coins`/`upgrades`/`appearance`/`player_name`/`settings`) as JSON
in `user://profile.json` — per-device persistent storage (survives restarts; on Android it's the app's
private data). `settings` holds the Definições prefs (`brightness`, `vol_music`, `vol_sfx`), read/written
through `Save.get_setting`/`set_setting`. When a match ends,
`Arena._record_result(won, place)` fires **once** per match (guarded by `_result_recorded`, reset in
`setup()`): on player death (loss, `place = contenders_alive()+1`) and on a player victory
(`place = 1`). It computes coins (`5 + (total-place)*3 + 60 if won`) and emits `match_ended`. `Main`
handles it (`_on_match_ended` → `Save.record_match`, shows `+N coins` on the end banner) and shows the
running totals on the main menu (`_refresh_menu_stats`). The `upgrades` dict is reserved for a
future store (apply bought upgrades in `Arena._make_player`).

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

Items still draw themselves via `_draw()` (`scripts/Item.gd`); `queue_redraw()` is called explicitly
each tick from `Arena`.

Fighters render with an `AnimatedSprite2D` built in code from a per-class pixel-art sheet in
`assets/fighters/<cls>.png` (7 classes + `Zombie.png`). Each sheet is an 8×17 grid of 100×40 cells;
`Fighter._get_frames()` slices named animations (idle/run/attack/cast/dash/die) defined in
`Fighter.ANIMS` and caches one `SpriteFrames` per class (shared across all fighters). `Fighter._process()`
picks the animation from state (`moving`, `dash_timer`, an attack pulse via `play_attack()`), flips by
`facing`, scales by `size` (so ×10 titans scale up), and tints zombies green / flashes white on hit.
`Arena._apply_movement` sets `moving`/`facing`; the attack loop calls `play_attack()`. `Fighter._draw()`
now only paints the shadow, auras/rings, HP bar and player name over the sprite (the sprite uses
`show_behind_parent`); the old circle body remains solely as a fallback when a sheet is missing.

The sheets are composed from the purchased **Heroes99** pack (not in the repo) by
`tools/compose_fighters.py` — edit its `CLASSES` table (cloth/hair/weapon/color per class) and re-run
`python3 tools/compose_fighters.py <path-to-Heroes99_v1.2>` to regenerate. Weapon ids: 1=sword,
2=axe, 3=dagger, 4=spear, 5=wand.

**Player appearance (runtime composition).** The human player picks a **hair colour** and a **cloth
colour** on the **Estilos** screen with `‹ ›` arrows (per class; remembered in `Save`). Only the needed
Heroes99 layers are committed at `assets/heroes_layers/<Class>/` (`skin`, `face`, `weapon_bot/top`, and
`hair_bot/top_c<c>` + `cloth_bot/top_c<c>` for colours 1–8), extracted by
`tools/extract_player_layers.py <path-to-Heroes99_v1.2>`. The UI colour chips are sampled from the
layer textures at runtime (`Main._layer_avg_color`), so no extra palette file ships in the export.
`CharacterComposer.compose(cls, hair_c, cloth_c)`
(`scripts/CharacterComposer.gd`, static, cached) stacks those layers in the same z-order as
`compose_fighters.py` into an 800×680 `ImageTexture`; `Arena._make_player` assigns it to
`Fighter.sheet_override` **before** `add_child`, and `Fighter._frames_from_texture` slices it exactly
like a class sheet. The 99 AI keep the pre-composed per-class sheets (no perf hit). If a class has no
layers, `compose` returns `null` and the fighter falls back to its class sheet. Full skin/weapon
selection is still a future extension.

The startup logo is a pixel-art "TITAN ROYALE" wordmark at `assets/ui/logo.png` — a hand-made art
asset supplied by the author (**not procedurally generated**; do not overwrite it). It is shown as an
animated in-game intro: `Main._build_intro()` fades/pops it over a dark full-rect `Control` on
startup, then fades to the main menu (a tap/key skips it via `_end_intro()`). The engine **boot
splash** (`application/boot_splash/*` in `project.godot`, replacing the Godot logo) uses a separate
composite `assets/ui/boot_splash.png` — the logo centered, smaller, on the dark background — built by
`tools/gen_boot_splash.py` (re-run it if `logo.png` changes); it is shown at native size, centered
(`boot_splash/fullsize=false`).

When a match ends (player eliminated, or the arena resolves to a winner), `Main._on_banner` reveals a
**"Main menu"** button in the banner box; pressing it calls `Main._return_to_menu()`, which stops and
clears the sim via `Arena.reset_to_idle()` and shows the main menu again for a fresh game.

The arena floor uses seamless 64×64 tiles from `assets/arena/`, grouped into themes by
`FLOOR_THEMES` in `Arena.gd` (each theme = `[stage1_royale, stage2_titans]`). Each match
`Arena._pick_floors()` picks a random theme; `_draw()` tiles the current phase's floor under the
ring/fighters. Tiles are generated procedurally by `tools/gen_floors.py` (run it to regenerate/add) —
except `stone_floor.png`, the original. Themes: Castelo, Areia, Natureza, Lava, Mágico.

## Future ideas (not built yet)

- **In-game character selector.** Hair-colour and cloth-colour picking is **done** (Estilos screen,
  runtime composition — see "Player appearance" under Rendering). Still open: letting the player also
  choose the skin tone, hair style and weapon (add more layers to `extract_player_layers.py` and arrow
  rows to `Main`), and a future **store** that spends `Save.coins` on upgrades (apply in
  `Arena._make_player`, persist in `Save.data["upgrades"]`).
- **Sound.** The Definições screen already exposes music/SFX volume sliders wired to `Music`/`SFX`
  audio buses; adding actual `AudioStreamPlayer`s that route to those buses is all that's left.
- **Per-class symbols.** The Jogar grid uses text buttons; the author plans an icon per class.
