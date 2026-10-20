# Level Unlocked

Raises the level cap from 12 to 16 and lets you set an experience multiplier in the Mod Configuration Menu.

## What it does

- **Level cap 16.** Your characters can level up past 12, up to 16.
- **Levels 13 to 16** give every class its hit points. Level 16 also gives a feat, as the 5e rules do for every class.
  There are no new class features or spell slots: the game has no spells above level 6.
- **Experience multiplier** from 0.5x to 5x, in the Mod Configuration Menu. It changes every gain of experience the
  game gives (combat, exploration, quests) before the game adds it, so level-ups work as usual.
- The mod is a normal `.pak`: it replaces no game files.

Experience needed in total (levels 1 to 12 are the game's own values):

| Level | Total experience |
|---|---|
| 12 | 100,000 |
| 13 | 130,000 |
| 14 | 150,000 |
| 15 | 175,000 |
| 16 | 205,000 |

## Screenshots

![Level Unlocked cover](docs/cover.jpg)

## How to install

1. Install [Norbyte's Script Extender](https://github.com/Norbyte/bg3se). It updates itself.
2. Install the [Mod Configuration Menu](https://github.com/KintaroModding/bg3_mcm/releases/latest), version 1.41 or
   later. The official Mod Configuration Menu 1.41 or later works too; keep only one of them.
3. Download `bg3_levelunlocked.pak` from the latest release on GitHub.
4. Copy it to `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods`.
5. Enable **Level Unlocked** in your mod manager (BG3 Mod Manager or the in-game mod manager), below the Mod
   Configuration Menu.

To update the mod, replace the `.pak` with the one from the new release. To remove it, disable it in the mod manager
and delete the `.pak`. Saves made with the mod can then show a warning about a missing mod.

## How to use

- Open the Mod Configuration Menu (main menu, Esc menu, or the Insert key) and select **Level Unlocked**.
- **Experience multiplier** (default 1.0, the normal game): 2.0 gives double experience, 0.5 half. A change counts
  for the next experience you gain; you do not need to load again.
- The level cap needs no setting. Level up past 12 as usual.
- In multiplayer, the host's setting counts.
- The Mod Configuration Menu stores the settings in its profile, not in the savegame.

## Compatibility

- Game version: Patch 8
- Use no other mod that changes the level cap or adds class levels above 12 (for example other "Level 20" mods): they
  change the same values and tables, and the mod that loads later wins. Remove old level mods that replace game
  files.
- Classes from other mods get no levels above 12 from this mod. Level them past 12 only when their own mod supports
  it.

## Known issues

- Removing the mod from a save with characters above level 12 is not tested. Keep a save from before level 13.

## How to build

Anyone can build this mod from its source code and check that the download matches it.

1. Install the tools: Windows PowerShell 5.1 (part of Windows) and [LSLib](https://github.com/Norbyte/lslib/releases)
   v1.20.4. Put LSLib into a folder `_tools\lslib\` above the repository, or set `BG3_TOOLS` to the folder that holds
   `lslib\`.
2. Build it: `powershell -ExecutionPolicy Bypass -File .\build.ps1`
3. Find the file: `dist\bg3_levelunlocked.pak`

The offline tests need Python 3 with lupa: `python -m pip install lupa`, then `python tests\run_tests.py`.

## Credits

Made by Kintaro. MIT license: you may use, change and share this mod.
