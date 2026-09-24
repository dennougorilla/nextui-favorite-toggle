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

LAST_FILE="${LAST_FILE:-/tmp/last.txt}"
COLLECTIONS_DIR="$SDCARD_PATH/Collections"
FAVORITES="$COLLECTIONS_DIR/1) Favorites.txt"

message() {
	if command -v show2.elf > /dev/null 2>&1; then
		show2.elf --mode=simple --image="$SDCARD_PATH/.system/res/logo.png" --text="$1" --timeout=1
	else
		echo "$1"
	fi
}

# Resolves the selection to the path a collection should store, or fails if it isn't a game
resolve_rom() {
	case "$1" in
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

SELECTED=""
[ -f "$LAST_FILE" ] && SELECTED="$(head -n 1 "$LAST_FILE" | tr -d '\r')"

if [ -z "$SELECTED" ] || ! ROM="$(resolve_rom "$SELECTED")"; then
	message "Select a game to favorite"
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
	message "Could not update Favorites"
	exit 1
fi

# Same order minui-favorites keeps: by file name, ignoring the system folder
awk -F'/' '{ print $NF "|" $0 }' "$TMP" | sort -t'|' -k1,1 | cut -d'|' -f2- > "$TMP.sorted" &&
	mv -f "$TMP.sorted" "$TMP"

# An empty file would still show up as an empty collection
if [ -s "$TMP" ]; then
	mv -f "$TMP" "$FAVORITES"
else
	rm -f "$TMP" "$FAVORITES"
fi
sync

if [ $STATUS -eq 10 ]; then
	message "Removed from Favorites"
else
	message "Added to Favorites"
fi
