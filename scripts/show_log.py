r"""Prints the newest lines of the mod's log files and its Mod Configuration Menu settings.

The mod writes server.log and client.log to Script Extender/bg3_levelunlocked/ in the BG3 user-data folder
(Shared/FileWriter.lua). The Mod Configuration Menu (MCM) stores the mod's settings per profile in
Script Extender/BG3MCM/Profiles/<Profile>/bg3_levelunlocked/settings.json. The script reads both from $BG3_DATA_DIR
(for example a share of the game PC), else from %LOCALAPPDATA%/Larian Studios/Baldur's Gate 3.

Usage:
    python scripts/show_log.py          # newest 40 lines of each file, then the MCM settings
    python scripts/show_log.py -n 200
"""

import argparse
import os
from pathlib import Path

MOD_FOLDER = "bg3_levelunlocked"
DATA_DIR = Path(os.environ.get("BG3_DATA_DIR")
                or Path(os.environ.get("LOCALAPPDATA", "")) / "Larian Studios" / "Baldur's Gate 3")
LOG_DIR = DATA_DIR / "Script Extender" / MOD_FOLDER
MCM_PROFILES = DATA_DIR / "Script Extender" / "BG3MCM" / "Profiles"


def main() -> None:
    parser = argparse.ArgumentParser(description="Print the newest lines of the mod's log files and its MCM settings.")
    parser.add_argument("-n", type=int, default=40, help="lines per file (default 40)")
    args = parser.parse_args()

    for name in ("server.log", "client.log"):
        path = LOG_DIR / name
        print(f"=== {path}")
        if not path.is_file():
            print("(not there: the mod did not write it yet, or the folder is not reachable)")
            continue
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        for line in lines[-args.n:]:
            print(line)

    settings = sorted(MCM_PROFILES.glob(f"*/{MOD_FOLDER}/settings.json"))
    print(f"=== MCM settings in {MCM_PROFILES}")
    if not settings:
        print("(none: MCM did not save settings for this mod yet, or the folder is not reachable)")
    for path in settings:
        print(f"--- profile {path.parent.parent.name}: {path.read_text(encoding='utf-8', errors='replace').strip()}")


if __name__ == "__main__":
    main()
