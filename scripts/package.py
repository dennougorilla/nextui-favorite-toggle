#!/usr/bin/env python3
"""Packages the pak into dist/.

dist/<release_filename>   Pak Store archive: the pak directory contents at the zip root
dist/<name>.pakz          manual install: extract to the SD card root (or drop on it, NextUI extracts on boot)
"""

import json
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAK_SRC = ROOT / "pak"
DIST = ROOT / "dist"


def add(zf: zipfile.ZipFile, src: Path, arcname: str) -> None:
    # Explicit unix mode so the script stays executable no matter which OS packaged it
    info = zipfile.ZipInfo(arcname)
    info.external_attr = 0o100755 << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    zf.writestr(info, src.read_bytes())


def main() -> None:
    meta = json.loads((ROOT / "pak.json").read_text())
    files = [(p, p.relative_to(PAK_SRC).as_posix()) for p in sorted(PAK_SRC.rglob("*")) if p.is_file()]
    files.append((ROOT / "pak.json", "pak.json"))
    files.append((ROOT / "LICENSE", "LICENSE"))

    DIST.mkdir(exist_ok=True)

    store_zip = DIST / meta["release_filename"]
    with zipfile.ZipFile(store_zip, "w") as zf:
        for src, arc in files:
            add(zf, src, arc)

    pakz = DIST / (meta["name"].replace(" ", ".") + ".pakz")
    with zipfile.ZipFile(pakz, "w") as zf:
        for platform in meta["platforms"]:
            for src, arc in files:
                add(zf, src, f"Tools/{platform}/{meta['name']}.pak/{arc}")

    for out in (store_zip, pakz):
        print(f"{out.relative_to(ROOT).as_posix()} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
