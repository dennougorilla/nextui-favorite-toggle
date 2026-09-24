#!/bin/sh
# Exercises the toggle logic of pak/launch.sh against a throwaway SD card layout.
# Runs anywhere with a POSIX sh (BusyBox, Git Bash): sh tests/test.sh

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCH="$ROOT/pak/launch.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export SDCARD_PATH="$WORK/sd"
export LAST_FILE="$WORK/last.txt"
FAV="$SDCARD_PATH/Collections/1) Favorites.txt"
FAILED=0

GBA="$SDCARD_PATH/Roms/Game Boy Advance (GBA)"
PS="$SDCARD_PATH/Roms/Sony PlayStation (PS)"
mkdir -p "$GBA" "$PS/Final Fantasy VII"
touch "$GBA/Zelda - Minish Cap.gba" "$GBA/Mario & Luigi [!] (USA).gba" "$GBA/Kirby's Dream Land.gba" \
	"$PS/Final Fantasy VII/Final Fantasy VII.m3u"

select_path() { printf '%s\n' "$1" > "$LAST_FILE"; }
toggle() { sh "$LAUNCH"; }

check() { # description, expected file content ("" = file must not exist)
	if [ -z "$2" ]; then
		if [ -e "$FAV" ]; then
			echo "FAIL: $1 (file should not exist)"; FAILED=1; return
		fi
	elif [ ! -f "$FAV" ] || [ "$(cat "$FAV")" != "$2" ] || [ "$(tail -c 1 "$FAV" | od -An -c | tr -d ' ')" != '\n' ]; then
		echo "FAIL: $1"; echo "--- expected"; printf '%s\n' "$2"; echo "--- got"; cat "$FAV" 2>/dev/null; FAILED=1; return
	fi
	echo "ok: $1"
}

select_path "$GBA/Zelda - Minish Cap.gba"
OUT="$(toggle)"
check "add first entry" "/Roms/Game Boy Advance (GBA)/Zelda - Minish Cap.gba"
[ "$OUT" = "Added to Favorites" ] || { echo "FAIL: add message: $OUT"; FAILED=1; }

select_path "$GBA/Mario & Luigi [!] (USA).gba"; toggle > /dev/null
select_path "$GBA/Kirby's Dream Land.gba"; toggle > /dev/null
check "special characters, sorted by file name" "/Roms/Game Boy Advance (GBA)/Kirby's Dream Land.gba
/Roms/Game Boy Advance (GBA)/Mario & Luigi [!] (USA).gba
/Roms/Game Boy Advance (GBA)/Zelda - Minish Cap.gba"

select_path "$GBA/Mario & Luigi [!] (USA).gba"
OUT="$(toggle)"
check "remove entry" "/Roms/Game Boy Advance (GBA)/Kirby's Dream Land.gba
/Roms/Game Boy Advance (GBA)/Zelda - Minish Cap.gba"
[ "$OUT" = "Removed from Favorites" ] || { echo "FAIL: remove message: $OUT"; FAILED=1; }

# Hand edited on Windows: CRLF, trailing spaces, blank lines, duplicates, no final newline
printf '/Roms/Game Boy Advance (GBA)/Zelda - Minish Cap.gba\r\n\r\n/Roms/Game Boy Advance (GBA)/Kirby'"'"'s Dream Land.gba  \r\n/Roms/Game Boy Advance (GBA)/Zelda - Minish Cap.gba' > "$FAV"
select_path "$GBA/Zelda - Minish Cap.gba"; toggle > /dev/null
check "CRLF file, removes every duplicate" "/Roms/Game Boy Advance (GBA)/Kirby's Dream Land.gba"

select_path "$PS/Final Fantasy VII"; toggle > /dev/null
check "multi-disc folder stores its m3u" "/Roms/Sony PlayStation (PS)/Final Fantasy VII/Final Fantasy VII.m3u
/Roms/Game Boy Advance (GBA)/Kirby's Dream Land.gba"

select_path "$PS/Final Fantasy VII"; toggle > /dev/null
select_path "$GBA/Kirby's Dream Land.gba"; toggle > /dev/null
check "empty collection file is deleted" ""

for BAD in "" "$SDCARD_PATH/Recently Played" "$SDCARD_PATH/Collections" "$GBA" \
	"$SDCARD_PATH/Tools/tg5040/Clock.pak" "$GBA/missing.gba"; do
	select_path "$BAD"
	OUT="$(toggle)"
	if [ "$OUT" != "Select a game to favorite" ] || [ -e "$FAV" ]; then
		echo "FAIL: rejects '$BAD' (got: $OUT)"; FAILED=1
	else
		echo "ok: rejects '${BAD#"$SDCARD_PATH"}'"
	fi
done

rm -f "$LAST_FILE"
[ "$(toggle)" = "Select a game to favorite" ] && echo "ok: no last.txt" || { echo "FAIL: no last.txt"; FAILED=1; }

[ $FAILED -eq 0 ] && echo "all tests passed"
exit $FAILED
