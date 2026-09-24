#!/bin/sh
# Favorite Toggle.pak
#
# Adds the game selected in the main menu to the "Favorites" collection, or removes it if it's
# already there. Meant to be bound to an FN button (Settings > Assignments): NextUI writes the
# selected entry to /tmp/last.txt before launching the pak and returns to the same spot after.
#
# Collection format (shared with NextUI and ben16w/minui-favorites): "$SDCARD_PATH/Collections/1) Favorites.txt",
# one SD-root-relative path per line with a leading slash, LF line endings, sorted by file name.
# The "1) " prefix sorts it first and is hidden by NextUI.

PAK_DIR="$(cd "$(dirname "$0")" && pwd)"
LAST_FILE="${LAST_FILE:-/tmp/last.txt}"
COLLECTIONS_DIR="$SDCARD_PATH/Collections"
FAVORITES="$COLLECTIONS_DIR/1) Favorites.txt"
RUMBLE="/sys/class/gpio/gpio227/value"
RUMBLE_VOLTAGE="/sys/class/motor/voltage"

# Shows the message only briefly, NextUI relaunching afterwards already takes a moment
message() { # text, image
	if command -v show2.elf > /dev/null 2>&1; then
		show2.elf --mode=simple --image="$2" --text="$1" --timeout=1 &
		sleep 0.35
		# show2.elf ignores SIGTERM and would stay up until its 1s timeout
		kill -9 $! 2> /dev/null
	else
		echo "$1"
	fi
}

# Reads the setting file directly: nextval.elf rewrites minuisettings.txt while loading it, and running it
# while NextUI starts back up can leave NextUI reading a half written file (losing e.g. button assignments)
haptics_enabled() {
	[ "$(sed -n 's/^haptics=//p' "$SHARED_USERDATA_PATH/minuisettings.txt" 2> /dev/null | tr -d '\r')" != "0" ]
}

rumble() { # pulses
	[ -w "$RUMBLE" ] && haptics_enabled || return 0
	# Same full strength NextUI uses, the Brick Pro motor is limited to 2.5V
	[ -w "$RUMBLE_VOLTAGE" ] && { [ "$DEVICE" = "brickpro" ] && echo 2500000 || echo 3300000; } > "$RUMBLE_VOLTAGE"
	for _ in $(seq "$1"); do
		echo 1 > "$RUMBLE"; sleep 0.06
		echo 0 > "$RUMBLE"; sleep 0.08
	done
}

# Resolves the selection to the path a collection should store, or fails if it isn't a game
resolve_rom() {
	case "$1" in
		"$COLLECTIONS_DIR/"*.txt/*)
			# Selected inside a collection: <collection>.txt/<file name>, look the game up in that list
			LINE="$(NAME="${1##*/}" awk -F'/' '{ sub(/[ \t\r]+$/, "") } $NF == ENVIRON["NAME"] { print; exit }' "${1%/*}" 2> /dev/null)"
			[ -n "$LINE" ] || return 1
			set -- "$SDCARD_PATH$LINE"
			;;
		"$SDCARD_PATH/Roms/"*) ;;
		*) return 1 ;;
	esac

	if [ -f "$1" ]; then
		echo "$1"
		return 0
	fi

	# Multi-disc games show up as a folder that launches its own <folder>.m3u (or .cue)
	if [ -d "$1" ]; then
		NAME="$(basename "$1")"
		for EXT in m3u cue; do
			if [ -f "$1/$NAME.$EXT" ]; then
				echo "$1/$NAME.$EXT"
				return 0
			fi
		done
	fi
	return 1
}

# Same order minui-favorites keeps: by file name, ignoring the system folder
sort_by_name() {
	awk -F'/' '{ print $NF "|" $0 }' | sort -t'|' -k1,1 | cut -d'|' -f2-
}

SELECTED=""
[ -f "$LAST_FILE" ] && SELECTED="$(head -n 1 "$LAST_FILE" | tr -d '\r')"

if [ -z "$SELECTED" ] || ! ROM="$(resolve_rom "$SELECTED")"; then
	message "Select a game to favorite" "$SDCARD_PATH/.system/res/logo.png"
	exit 0
fi

ENTRY="${ROM#"$SDCARD_PATH"}"
mkdir -p "$COLLECTIONS_DIR"
TMP="$FAVORITES.tmp"
[ -f "$FAVORITES" ] && SOURCE="$FAVORITES" || SOURCE=/dev/null

# Rewrites the list normalized (no CR, no trailing whitespace, no blank lines) without the
# entry, appending it if it wasn't there. Exits 10 when it was removed. ENVIRON rather than
# -v so backslashes in file names aren't interpreted.
FAV_ENTRY="$ENTRY" awk '
	{ sub(/[ \t\r]+$/, "") }
	$0 == "" { next }
	$0 == ENVIRON["FAV_ENTRY"] { found = 1; next }
	{ print }
	END {
		if (found) exit 10
		print ENVIRON["FAV_ENTRY"]
	}
' "$SOURCE" > "$TMP"
STATUS=$?

if [ $STATUS -ne 0 ] && [ $STATUS -ne 10 ]; then
	rm -f "$TMP"
	message "Could not update Favorites" "$SDCARD_PATH/.system/res/logo.png"
	exit 1
fi

sort_by_name < "$TMP" > "$TMP.sorted" && mv -f "$TMP.sorted" "$TMP"

# Removed while browsing Favorites itself: NextUI would return to a row that no longer exists,
# so point it at the game that took its place (or the one before, if it was the last)
if [ $STATUS -eq 10 ] && [ "${SELECTED%/*}" = "$FAVORITES" ]; then
	if [ -s "$TMP" ]; then
		ROW="$({ cat "$TMP"; echo "$ENTRY"; } | sort_by_name | grep -nxF -- "$ENTRY" | head -n 1 | cut -d: -f1)"
		NEXT="$(sed -n "${ROW}p" "$TMP")"
		[ -n "$NEXT" ] || NEXT="$(tail -n 1 "$TMP")"
		printf '%s\n' "$FAVORITES/${NEXT##*/}" > "$LAST_FILE"
	else
		printf '%s\n' "$COLLECTIONS_DIR" > "$LAST_FILE"
	fi
fi

# An empty file would still show up as an empty collection
if [ -s "$TMP" ]; then
	mv -f "$TMP" "$FAVORITES"
else
	rm -f "$TMP" "$FAVORITES"
fi
sync

if [ $STATUS -eq 10 ]; then
	rumble 2 &
	message "Removed from Favorites" "$PAK_DIR/res/heart_empty.png"
else
	rumble 1 &
	message "Added to Favorites" "$PAK_DIR/res/heart_full.png"
fi
