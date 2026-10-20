"""Writes src/Public/bg3_levelunlocked/Progressions/Progressions.lsx: the class levels 13 to 16.

The game's class progression tables (Public/Shared(Dev)/Progressions/Progressions.lsx in Shared.pak, Patch 8) have a
row for every level from 1 to 12 and none above, so a level-up past 12 has no row to apply. This script adds one row
per class and level from 13 to 16, in the class's own table (TableUUID):

- Levels 13 to 15 are empty rows: the level gives the class's hit points and nothing else. The game has such rows
  itself (Fighter 7 and 10, Rogue 9, Warlock 6, Barbarian 10).
- Level 16 allows a feat (AllowImprovement), as the 5e rules give every class at 16.
- The multiclass spell slot table gets empty rows too, because the caster level of a multiclass character can pass 12.
  No class gets new spell slots: the game has no spells above level 6 to use them on.

Subclass tables have rows only at the levels where the subclass gives something, so they need none. The row UUIDs are
UUID5 values of the mod UUID and "<table>:<level>", so every run writes the same file.

Usage:
    python scripts/gen_progressions.py
"""

import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGET = ROOT / "src" / "Public" / "bg3_levelunlocked" / "Progressions" / "Progressions.lsx"
MOD_UUID = uuid.UUID("d38c1f73-193d-41c2-85ab-45bf2a591067")

LEVELS = range(13, 17)
FEAT_LEVELS = {16}

# Name and TableUUID of the class tables in the game data (ProgressionType 0).
CLASS_TABLES = [
    ("Barbarian", "60bbcc97-5381-4898-bc15-908c072895de"),
    ("Bard", "229c98da-2cd1-4a5e-8051-9d90ec7931e7"),
    ("Cleric", "64474b62-b4f5-46b3-b94a-c676c6da3116"),
    ("Druid", "6e7b7bad-e122-4679-8b3c-8f8987a9d466"),
    ("Fighter", "ba4e707e-4bbd-4630-963b-ce2f2947f971"),
    ("Monk", "fe1319a2-86be-469c-aab5-e3b0bd714e0e"),
    ("Paladin", "ba2afe85-acba-4ea1-a238-2b4543f47821"),
    ("Ranger", "8f068974-ed32-43fc-a9d9-028be1c01a9c"),
    ("Rogue", "9a44e828-92db-4d6c-acbc-a4f8ef340415"),
    ("Sorcerer", "e2416b02-953a-4ce8-aa8f-eb98d549d86d"),
    ("Warlock", "a7a958f1-d858-4021-9fa7-cf87e7d71377"),
    ("Wizard", "d18eda7e-4b7d-490d-9952-cd33a3c60479"),
]
MULTICLASS_TABLE = ("MulticlassSpellSlots", "a6f80028-fee2-41e0-bd24-d2f0758d936f")

HEADER = """<?xml version="1.0" encoding="UTF-8"?>
<save>
    <version major="4" minor="6" revision="0" build="1"/>
    <region id="Progressions">
        <node id="root">
            <children>
"""
FOOTER = """            </children>
        </node>
    </region>
</save>
"""


def row(name: str, table: str, level: int, feat: bool) -> str:
    row_uuid = uuid.uuid5(MOD_UUID, f"{table}:{level}")
    lines = ['                <node id="Progression">']
    if feat:
        lines.append('                    <attribute id="AllowImprovement" type="bool" value="true"/>')
    lines += [
        f'                    <attribute id="Level" type="uint8" value="{level}"/>',
        f'                    <attribute id="Name" type="LSString" value="{name}"/>',
        '                    <attribute id="ProgressionType" type="uint8" value="0"/>',
        f'                    <attribute id="TableUUID" type="guid" value="{table}"/>',
        f'                    <attribute id="UUID" type="guid" value="{row_uuid}"/>',
        '                </node>',
    ]
    return "\n".join(lines) + "\n"


def main() -> None:
    parts = [HEADER]
    for name, table in CLASS_TABLES:
        for level in LEVELS:
            parts.append(row(name, table, level, level in FEAT_LEVELS))
    name, table = MULTICLASS_TABLE
    for level in LEVELS:
        parts.append(row(name, table, level, False))
    parts.append(FOOTER)
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text("".join(parts), encoding="utf-8", newline="\n")
    print(f"Wrote {TARGET.relative_to(ROOT)}: {len(CLASS_TABLES) + 1} tables, levels {LEVELS.start}-{LEVELS.stop - 1}")


if __name__ == "__main__":
    main()
