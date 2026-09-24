# Favorite Toggle for NextUI

Add the selected game to **Favorites** — or remove it — with a single button press, right from the
[NextUI](https://github.com/LoveRetro/NextUI) game list. No menus, no PC, no editing text files.

Supported: `tg5040` with FN buttons — TrimUI Brick (L3 / R3) and Brick Pro (L4 / R4 / HOME).
The Smart Pro has no assignable buttons.

## Install

- **Pak Store**: search for *Favorite Toggle* (once listed)
- **Manual**: download `Favorite.Toggle.pakz` from [Releases](../../releases), copy it to the root of your SD card
  and boot the device, NextUI installs it automatically

## Setup

1. Open **Settings → Assignments**
2. Pick a button (for example **L3 button**) and choose **Favorite Toggle**

## Use

Highlight a game anywhere in the main menu — a system folder or any collection, including Favorites
itself — and press the assigned button:

- not a favorite yet → *Added to Favorites*
- already a favorite → *Removed from Favorites*

NextUI comes back to the same spot in the list afterwards. Favorites show up under **Collections**.
Multi-disc games (a folder with a matching `.m3u` or `.cue`) are stored as their `.m3u` / `.cue`.
Recently Played, folders, and paks are skipped.

## Works with Favorites.pak

Favorites are stored in `/Collections/1) Favorites.txt`, the same file used by
[ben16w/minui-favorites](https://github.com/ben16w/minui-favorites) (*Favorites* in the Pak Store).
Use both together: that pak to browse and manage the list from the Tools menu, this one for
the one-button toggle. The `1) ` prefix sorts the collection first and is hidden by NextUI.

The file holds one path per line, relative to the SD card root with a leading slash:

```
/Roms/Game Boy Advance (GBA)/Kirby's Dream Land.gba
/Roms/Sony PlayStation (PS)/Final Fantasy VII/Final Fantasy VII.m3u
```

Entries are kept sorted by file name. Hand edits are fine — CRLF line endings, trailing spaces,
blank lines, and duplicates are cleaned up the next time you toggle a game.

## How it works

When a pak is launched from an FN button, NextUI writes the highlighted entry to `/tmp/last.txt`
before starting it. `launch.sh` reads that path, toggles it in the collection file (written atomically
with a temp file and `mv`), shows a one-second confirmation, and exits back to NextUI.

## Development

The pak is a single BusyBox-compatible shell script, there is nothing to compile.

```sh
sh tests/test.sh      # toggle logic against a throwaway SD card layout
sh scripts/build.sh   # tests, then dist/Favorite.Toggle.pak.zip (Pak Store) and dist/Favorite.Toggle.pakz
```

To test with the real device shell: `docker run --rm -v "$PWD:/repo" busybox sh /repo/tests/test.sh`

## Releasing

Bump `version` and `changelog` in `pak.json`, then push a matching tag (`v0.2.0`).
CI tests, packages, and publishes the release.
