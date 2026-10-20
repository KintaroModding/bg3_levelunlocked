"""Increases the build number (the last version digit) of the mod in meta.lsx by 1.

BG3 stores a version as one int64: major << 55 | minor << 47 | revision << 31 | build.
Both Version64 attributes of the ModuleInfo node (its own and the one of PublishVersion) get the new value. The
Version64 values in Dependencies are the versions of other mods; they stay.

Usage:
    python scripts/bump_version.py           # 1.0.0.5 -> 1.0.0.6
    python scripts/bump_version.py --show    # print the current version
"""

import re
import sys
from pathlib import Path

META = Path(__file__).resolve().parent.parent / "src" / "Mods" / "bg3_levelunlocked" / "meta.lsx"
VERSION64 = re.compile(r'(<attribute id="Version64" type="int64" value=")(\d+)("\s*/>)')
NODE_TAG = re.compile(r"<node\b[^>]*?(/?)>|</node>")


def decode(value: int) -> tuple:
    return value >> 55, (value >> 47) & 0xFF, (value >> 31) & 0xFFFF, value & 0x7FFFFFFF


def encode(major: int, minor: int, revision: int, build: int) -> int:
    return (major << 55) | (minor << 47) | (revision << 31) | build


def text(version: tuple) -> str:
    return ".".join(str(part) for part in version)


def module_info_span(content: str) -> tuple:
    """Returns the start and end of the ModuleInfo node, with its child nodes."""
    start = content.find('<node id="ModuleInfo">')
    if start < 0:
        sys.exit(f"No ModuleInfo node in {META}")
    depth = 0
    for match in NODE_TAG.finditer(content, start):
        if match.group(0) == "</node>":
            depth -= 1
            if depth == 0:
                return start, match.end()
        elif not match.group(1):
            depth += 1
    sys.exit(f"The ModuleInfo node in {META} is not closed")


def main() -> None:
    assert decode(encode(1, 2, 3, 4)) == (1, 2, 3, 4) and encode(1, 0, 0, 0) == 36028797018963968

    content = META.read_bytes().decode("utf-8")
    start, end = module_info_span(content)
    info = content[start:end]
    values = [int(match.group(2)) for match in VERSION64.finditer(info)]
    if not values:
        sys.exit(f"No Version64 attribute in the ModuleInfo node of {META}")
    current = decode(values[0])

    if "--show" in sys.argv:
        print(text(current))
        return

    major, minor, revision, build = current
    new = (major, minor, revision, build + 1)
    info = VERSION64.sub(lambda match: f"{match.group(1)}{encode(*new)}{match.group(3)}", info)
    content = content[:start] + info + content[end:]
    META.write_bytes(content.encode("utf-8"))
    print(f"Version {text(current)} -> {text(new)}")


if __name__ == "__main__":
    main()
