# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a fork of [OpenRA](https://github.com/OpenRA/OpenRA) (remote `upstream`; the fork is `origin`). OpenRA is a C# (.NET 10, LangVersion 13) RTS engine that re-implements Red Alert (`ra`), Tiberian Dawn (`cnc`), Dune 2000 (`d2k`) and an experimental Tiberian Sun (`ts`). The upstream main branch is `bleed`.

The fork adds a Red Alert co-op wave-defense mode (`mods/racoop`, see below). That work happens on the `coop-game` branch. `GameModeDesignDoc.md` is the spec for the mode and lists what still needs building.

## Commands

On Windows use `make.cmd <target>` / `.\make.ps1 <target>`. On Linux/macOS use `make <target>`. Targets are the same on both:

| Target | What it does |
|---|---|
| `all` (default) | `dotnet build -c Release`, output to `bin/`, plus GeoIP DB download |
| `check` | Clean Debug build with `-warnaserror` (StyleCop/Roslynator/.editorconfig analyzers run only in Debug), then `--check-explicit-interfaces` and `--check-conditional-trait-interface-overrides` |
| `tests` | Builds `OpenRA.Test` (NUnit) and runs `dotnet test bin/OpenRA.Test.dll --test-adapter-path:.` |
| `test` | Lints every mod's MiniYAML/maps/Lua (`utility <mod> --check-yaml`). Needs a prior build. CI sets `TREAT_WARNINGS_AS_ERRORS=true` |
| `check-scripts` | `luac -p` syntax check over `mods/*/maps` and `mods/*/scripts` (needs Lua 5.1) |
| `clean` | Removes `bin/` and `*/obj` |

CI runs `check`, `tests`, `check-scripts` and `test` with warnings as errors. A release build that compiles cleanly can still fail `check`.

- **Single test:** `dotnet test bin/OpenRA.Test.dll --test-adapter-path:. --filter "FullyQualifiedName~MiniYamlTest"` (build the test project first, as the `tests` target does).
- **Lint one mod:** `./utility.sh ra --check-yaml` (Windows: `utility.cmd ra --check-yaml`).
- **Run the game:** `launch-game.cmd Game.Mod=ra` / `./launch-game.sh Game.Mod=ra`. Dedicated server: `launch-dedicated.*`.
- **Utility:** `OpenRA.Utility` (`utility.sh`/`utility.cmd <mod> --<command>`) provides `--update-mod`/`--update-map` (apply YAML update rules), `--resolved-rules`, `--check-yaml`, and other tools.

## Architecture

**Projects** (`OpenRA.slnx`; all build into the shared `bin/`):
- `OpenRA.Game`: core engine. `Game`, `World`, `Actor`, `Player`, `ModData`/`Manifest`, MiniYaml + `FieldLoader`, networking/orders, rendering abstractions, the widget framework, Lua scripting host, and the trait system plumbing (`TraitDictionary`, `Traits/`).
- `OpenRA.Mods.Common`: most gameplay. Traits, activities, warheads, projectiles, pathfinder, widgets and their logic, server traits, lint rules (`Lint/`), YAML update rules (`UpdateRules/`), utility commands, the map editor and generator.
- `OpenRA.Mods.Cnc` / `OpenRA.Mods.D2k`: game-specific traits and file formats. RA and TS load `OpenRA.Mods.Common.dll, OpenRA.Mods.Cnc.dll` (see `Assemblies:` in `mods/<mod>/mod.yaml`).
- `OpenRA.Platforms.Default`: SDL2/OpenGL/OpenAL backend. `OpenRA.Launcher`, `OpenRA.WindowsLauncher`, `OpenRA.Server`, `OpenRA.Utility`: entry points.
- `glsl/`: shaders.

**Mods are data.** `mods/<mod>/mod.yaml` is the manifest. It lists packages, rules, weapons, sequences, chrome layouts, Fluent translation files and assemblies. `mods/common` holds content shared between mods. `*-content` mods are the content installers. Gameplay is defined by composing C# traits in MiniYAML:
- Actor definitions in `rules/*.yaml` list traits by name: the `Foo` key maps to the `FooInfo` class. Each trait has an immutable `*Info` class (loaded by `FieldLoader`, documented with `[Desc]`) that creates the per-actor runtime trait object. `^Name` defines abstract templates used through `Inherits:`, and `-Trait:` removes an inherited trait.
- Behaviour is wired through interfaces (`INotify*`, `ITick`, `IResolveOrder`, etc., in `OpenRA.Game/Traits/TraitsInterfaces.cs` and `OpenRA.Mods.Common/TraitsInterfaces.cs`), which actors query with `actor.TraitsImplementing<T>()`.
- Many traits derive from `ConditionalTrait<TInfo>` / `PausableConditionalTrait<TInfo>`. These toggle via `RequiresCondition:` expressions on conditions granted by `GrantCondition*` traits. When overriding interface methods on conditional traits, follow the patterns enforced by `--check-conditional-trait-interface-overrides`.
- Unit behaviour over time runs through `Activity` chains (`Activities/`), and player input arrives as `Order`s.

**Determinism.** Multiplayer is lockstep with sync-hash checks. Simulation code must be deterministic: use the fixed-point world types (`WPos`, `WVec`, `WDist`, `WAngle`, `WRot`, `CPos`/`MPos` for cells), and `world.SharedRandom` for game-affecting randomness (never `LocalRandom`, `System.Random`, or float math). Mark sync-relevant trait state with `[Sync]`. The `CheckSyncAnnotations` lint verifies this. Rendering and UI code may use floats.

**Changing YAML-facing APIs.** Renaming or removing trait fields or traits requires an `UpdateRule` in `OpenRA.Mods.Common/UpdateRules/Rules/`, registered in `UpdatePath.cs`. The mod and map YAML must then be updated as well, for example with `--update-mod`. Shared engine or mod changes should be tested against all four default mods (`ra`, `cnc`, `d2k`, `ts`).

**UI and text.** Chrome layouts are YAML under `mods/*/chrome/`, with C# logic classes in `Widgets/Logic/`. User-facing strings are Fluent (`.ftl`) keys in `mods/*/fluent/` and are lint-checked (`CheckFluentReferences`). Mission scripts are Lua in `mods/*/maps/*/` and use the API in `Scripting/`.

## Co-op mod (racoop)

**First-time setup on a new machine:**
1. Install the .NET 10 SDK (`winget install Microsoft.DotNet.SDK.10`). The engine targets net10.0, and an older SDK fails with `NETSDK1045`.
2. Run `.\coop` to build and launch the game.
3. Install the Red Alert content. It isn't in the repo, and the game reads it from `%APPDATA%\OpenRA\Content\ra\v2`. Until it's installed, the game opens the content installer instead of the map, and `smoke`/`test`/`check` time out waiting for `coop: WorldLoaded`. To install it, click **Quick Install** on the game's content prompt. This downloads the freeware package, and the click can't be automated. Assume a fresh machine doesn't have the content anywhere else.
4. Run `.\coop check` to confirm everything works.

Running PowerShell with `2>&1` on `coop.ps1` breaks the build: `dotnet` writes to stderr and the script runs with `$ErrorActionPreference = "Stop"`. `lint` doesn't build, so it needs an earlier build.

- `mods/racoop` layers on Red Alert. Its `mod.yaml` reuses the `ra|` rules, assets and installed content, and `rules/coop.yaml` (loaded last) holds co-op overrides. Map-specific rules go in each map's `rules.yaml`. Chrome layouts can't be partially overridden (duplicate widget IDs throw), so `chrome/ingame-player.yaml` is a full copy of RA's sidebar with co-op changes (the Power button replaced by Send money). Upstream RA sidebar changes have to be merged into it by hand. The Sell and Send money icons (`coop-order-icons` in `mods/racoop/chrome.yaml`) are generated by `.\coop-icons.ps1`. To change the icons, edit that script and re-run it rather than editing the PNGs.
- **Maps:**
  - `maps/two-lane` is the main map. Up to 4 allied humans (Multi0–3) build in the west and face a non-combatant `Enemy` with no AI, base or starting units. Waves come from the east down a north and a south lane, along named `waypoint` actors (`NorthSpawn`, `NorthEastGap`, `NorthWestGap`, and the same for South).
  - `maps/coop-01` is the older test map, with its own simple fixed-interval script.
  - Slots nobody joined aren't created, so human players may be nil.
- **Forces:**
  - `rules/forces.yaml` replaces RA's factions with the four forces (`infantry`, `tanks`, `air`, `support`). The old factions stay non-selectable for the Enemy, Neutral and shellmap players.
  - The Construction Yard provides `force`, `force.<name>` and `force.vehicles` prerequisites. Each force builds only its own buildings and units; every other buildable RA actor gets `~disabled`. Set it on the actor itself: a `Buildable` inherited from a template is overridden by the actor's own.
  - Each force's sidebar look, voices and lobby flag map to the Allied or Soviet versions, in `metrics.yaml`, `audio/voices.yaml` and the `flags` regions in `chrome.yaml`.
  - The Air force's War Factory is a separate actor, `weap.air`, so it can cost less and build Mobile Flak in the Aircraft tab.
- **Waves:**
  - A map defines its waves as `WaveConfig` in `waves.lua`, which documents the format. `scripts/coopwaves.lua` runs them with `CoopWaves.Start(config, lanes, humans, enemy)`. It validates the config on load, spawns groups, makes enemies prefer units over buildings, and decides victory (every wave unit dead) and defeat (no human Construction Yard or MCV left).
  - `rules/coop.yaml` removes `ConquestVictoryConditions`, because its objective can't complete against a non-combatant enemy.
  - The runner's strings are in `fluent/lua.ftl`, which maps list in `FluentMessages`. Strings in `racoop.ftl` that only Lua uses would fail lint as unused.
  - The status display and "Call next wave" button use the `WaveStatus` world trait, the `CallNextWave` player order trait, `WaveStatusLogic`, and the Lua global `Waves`.
  - Enemy aircraft get unlimited ammo through the `wave-unit` condition, which only the script grants.
  - Units never gain veterancy from kills (`GainsExperienceMultiplier@NOAUTO`). Ranks come from `GiveLevels`.
- **Dev loop:** `.\coop [command]` (`coop.ps1`, or `coop.cmd`):
  - `play` (default): build and launch straight into the map.
  - `duo`: local server plus two clients.
  - `smoke`: fail on Lua errors or crashes.
  - `test`: run the scenarios.
  - `lint`, and `check` (lint + smoke + all tests).
  - Options: `-Map <folder>` (default coop-01), `-Scenario <name>`, `-NoBuild`, `-Show` (show the window for smoke/test), `-Faction <force>` (default random).
  - Test scenarios named `force-<faction>` always run as that faction.
  - `smoke`, `test` and `check` run in a hidden window.
- **Automated tests:** each scenario is a Lua function in `<map>-tests.lua` (`Scenarios["name"] = function() ... end`) using the `CoopTest.*` helpers from `scripts/cooptest.lua`. List each scenario in the map's hidden `ScriptLobbyDropdown@test`, and call `CoopTest.Run(Scenarios)` from `WorldLoaded`. On two-lane it runs before `CoopWaves.Start`, so a scenario can swap in its own `WaveConfig`. Results are written as `coop-test:` lines to lua.log, and screenshots go to `test-results/` (gitignored).
  - `check` only covers coop-01. Run `.\coop test -Map two-lane` as well.
  - Close any running game first: an open game holds `lua.log`, so test runs log to `lua.log.1` and time out.
  - The test speed is about 8× normal, so on-screen countdowns, which are in real time like the game clock, read shorter.
- **Engine additions for this:**
  - `Launch.LobbyOptions=id=value,...`, applied with `Launch.Map` or when joining a server as its admin. `faction=<name>` sets the local player's faction.
  - The Lua function `Test.BuildableItems(player)`, which lists what the player can currently build.
  - Environment variables `OPENRA_HIDDEN_WINDOW=1` and `OPENRA_SCREENSHOT_DIR`.
  - The Lua global `Test.Screenshot(name)` (`OpenRA.Mods.Common/Scripting/Global/TestGlobal.cs`).
  - `actor.Detonate(target)` for MAD tanks (`OpenRA.Mods.Cnc/Scripting/Properties/MadTankProperties.cs`). To allow it, `MadTank` and `MadTankInfo` are now public.

## Conventions

- Tabs (width 4) and LF line endings for `.cs`, `.yaml`, `.lua`, `.sh` and `.ps1`. Style is enforced by `.editorconfig` analyzers in Debug builds.
- Every `.cs` file starts with the `#region Copyright & License Information` GPLv3 header block. Copy it from an existing file.
- Nullable reference types are disabled. `.csproj` files include `**/*.cs` explicitly, so new files are picked up automatically.
- Upstream contribution expectations: rebase on `bleed`, run `make check` and `make test`, and add new contributors to `AUTHORS`.
