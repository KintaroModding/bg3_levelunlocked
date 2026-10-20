# Level Unlocked

Raises the level cap from 12 to 16 and lets you set an experience multiplier in the Mod Configuration Menu.

A mod for Baldur's Gate 3 (Patch 8), made with game version 4.1.1.7398727. It needs
[Norbyte's Script Extender](https://github.com/Norbyte/bg3se) and the
[Mod Configuration Menu](https://github.com/AtilioA/BG3-MCM) (MCM) 1.41. This README is for developers. What the mod
does, how to install it and its compatibility are in [openmods.md](openmods.md), the mod page on
[openmods](https://openmods.nexus).

## How it works

- Level cap: `Public/bg3_levelunlocked/Stats/Generated/Data/XPData.txt` sets `MaxXPLevel` to 16 and adds `Level13`
  to `Level16` (`LevelN` is the experience from level N to N + 1; the game's own `Level1` to `Level12` stay).
  `Data.txt` raises `MaximumXPCap` to 240000, the end of the bar at level 16. The game merges these `key` entries
  with its own; another mod that sets the same keys and loads later wins.
- Class levels 13 to 16: the game's class progression tables end at level 12.
  `Public/bg3_levelunlocked/Progressions/Progressions.lsx` adds one row per class and level in the class's own
  table: empty rows for 13 to 15 (hit points only; the game has empty rows itself) and a feat (`AllowImprovement`)
  at 16. The multiclass spell slot table gets empty rows too. Subclass tables need none: they only have rows where
  the subclass gives something. `scripts/gen_progressions.py` writes the file.
- Experience multiplier: `Server/XPMultiplier.lua` watches the `Experience` component of the party members
  (`Ext.Entity.Subscribe`). The game gives each member the gain; after a short wait to collect the gains of one
  event, the mod adds the difference to the scaled gain with `Osi.AddExplorationExperience`, so the game adds it and
  checks the level-up itself. Whether that call gives to one character or to the whole party is not documented: the
  mod corrects one member first, waits until the game applied it, and then corrects only the members it did not
  reach. Below 1 the correction is negative; the game has already flagged a level-up for the full gain and never
  checks again, so the mod rebuilds `AvailableLevel`, `CurrentLevelExperience` and the `CanLevelUp` component from
  the corrected total. These engine facts come from the game tests that
  [Path to Apotheosis](https://github.com/holypolarpanda7/dnd55e-13-20-Path-to-Apotheosis) published
  (`docs/XP_CURVE.md`). A hook before the update of the server's experience system
  (`Ext.Entity.OnSystemUpdate("ServerExperience")`) saw no pending gains in a game test, so the mod corrects after
  the fact.
- `Server/ExperienceWatch.lua` logs every change of a party member's experience.
- The hooks start on `SessionLoaded`, or on `LevelGameplayStarted` when that fails.

## Settings

The Mod Configuration Menu shows the settings of `MCM_blueprint.json`. `Shared/Settings.lua` reads them:
`Settings.Get(id)` returns the value and its source (`MCM` or `default`), and `Settings.OnChange(fn)` reports a change
or an MCM profile switch. Without MCM (missing, or loaded after this mod) the values of `Settings.Defaults` apply. The
tests check that `Settings.Defaults` and the blueprint list the same settings with the same defaults. `meta.lsx` lists
MCM 1.41.0.0 (`755a8a72-407f-4f0d-9a33-274ac0f0b53d`) as a dependency, so the mod managers load MCM first; only then
does MCM put its `MCM` table into this mod. The setting ids are part of the players' saved settings: never rename one
after a release.

## Build

Requirements: Windows PowerShell and [LSLib](https://github.com/Norbyte/lslib/releases) (`Divine.exe`).
`build.ps1` looks for `_tools\lslib\Packed\Tools\Divine.exe` in the parent folders of the project; set `BG3_TOOLS` to
a folder that holds `lslib\` to use another place.

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1             # dist\bg3_levelunlocked.pak
powershell -ExecutionPolicy Bypass -File .\build.ps1 -Deploy     # build, then copy the .pak to the Mods folder
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Wait      # copy the .pak when the game is closed
```

`deploy.ps1` copies the .pak to the `Mods` folder below `BG3_DATA_DIR` (the BG3 user-data folder), else to
`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods`; `-ModsDir` overrides both. The running game locks the .pak, so
the script stops (exit code 2) or, with `-Wait`, waits until the game is closed.

## Project layout

```
src/                                     Mod files (packed into the .pak)
  Mods/bg3_levelunlocked/meta.lsx           Mod metadata (UUID d38c1f73-193d-41c2-85ab-45bf2a591067), MCM dependency
  Mods/bg3_levelunlocked/MCM_blueprint.json The Mod Configuration Menu page (the settings)
  Mods/bg3_levelunlocked/ScriptExtender/
    Config.json
    Lua/BootstrapServer.lua              Server entry point
    Lua/BootstrapClient.lua              Client entry point
    Lua/Shared/Common.lua                Shared helpers (mod version)
    Lua/Shared/FileWriter.lua            Throttled file output in the Script Extender folder
    Lua/Shared/Settings.lua              MCM settings with defaults (Settings.Defaults)
    Lua/Server/XPMultiplier.lua          Multiplies the experience gains of the party
    Lua/Server/ExperienceWatch.lua       Logs the experience of party members
    Lua/Server/LevelCap.lua              Reads and checks the level cap the game uses
    Lua/Server/ServerLog.lua             server.log
    Lua/Client/ClientLog.lua             client.log
  Public/bg3_levelunlocked/Stats/Generated/Data/XPData.txt   Level cap 16, experience for levels 13 to 16
  Public/bg3_levelunlocked/Stats/Generated/Data/Data.txt     MaximumXPCap
  Public/bg3_levelunlocked/Progressions/Progressions.lsx     Class rows for levels 13 to 16
docs/                                    Cover and screenshots for openmods.md
tests/                                   Offline tests (Lua 5.4 through lupa)
scripts/bump_version.py                  Raises the last version digit in meta.lsx
scripts/show_log.py                      Prints the mod's log files and MCM settings
scripts/gen_progressions.py              Writes Progressions.lsx
build.ps1                                Builds dist/bg3_levelunlocked.pak from src/ (.loca.xml -> .loca, .lsf.lsx -> .lsf)
deploy.ps1                               Copies the .pak to the Mods folder
openmods.json, openmods.md               Data and mod page for openmods.nexus
```

Versioning: every change raises the last version digit (1.0.0.0 -> 1.0.0.1):

```powershell
python scripts\bump_version.py           # both Version64 values in meta.lsx
python scripts\bump_version.py --show
```

Logs: the mod writes `server.log` and `client.log` to
`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\bg3_levelunlocked\`. Each load writes a line like
`Level Unlocked 1.0.0.1 loaded.`, so the logs show which version runs, and server.log gets a line with every setting,
for example `Settings: xp_multiplier = 1.5 (MCM).`, also after each change. It also shows the level data the game
uses (`Level data: MaxXPLevel = 16, ...`), whether the experience hooks started, every scaled gain
(`Gain x1.5: Tav +100 -> +150.`) and every change of a party member's experience. MCM stores the settings in
`Script Extender\BG3MCM\Profiles\<Profile>\bg3_levelunlocked\settings.json`. `python scripts\show_log.py` prints the
newest log lines and these settings (from `BG3_DATA_DIR`, if set).

Tests:

```powershell
python -m pip install lupa
python tests\run_tests.py
```

The tests run every mod script against mocks of the Script Extender API (`tests/harness.lua`). The IMGUI, audio and
resource mocks are checked against the Script Extender IDE helpers (`tests/gen_extui_api.py` refreshes
`tests/extui_api.json`), so a property or method that does not exist in the real API fails the tests.

## License

MIT, see [LICENSE](LICENSE).
