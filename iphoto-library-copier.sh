#!/bin/bash

pushd () { command pushd "$@" > /dev/null; }
popd () { command popd "$@" > /dev/null; }

handle_duplicate () {
	src=$(dirname "$1")
	file=$(basename "$1")
	dest=$2

	# Check if the duplicate file names are actually different
	if ! $(cmp -s "$src/$file" "$dest/$file"); then

		# If they are, rename the source file to file_n.ext
		filename=$(echo $file | cut -f1 -d '.')
		extension=$(echo $file | cut -f2 -d '.')

		n=1
		file_n="${filename}_${n}.${extension}"

		# Make sure the file doesn't exist under the new name
		while test -e "$dest/$file_n"; do

			# And if it does, make sure it's not the same file that's already been renamed and copied
			if $(cmp -s "$src/$file" "$dest/$file_n"); then
				((NUM_TRUE_DUPES++))
				return
			fi

			((n++))
			file_n="${filename}_${n}.${extension}"
		done

		((NUM_NAME_DUPES++))

		cp "$src/$file" "$dest/$file_n"
	else
		((NUM_TRUE_DUPES++))
	fi
}

NUM_TOTAL=0
NUM_TRUE_DUPES=0
NUM_NAME_DUPES=0

pushd "${1:-/Volumes/iPhoto Disc/iPhoto Library}"

DEST_ROOT="/Users/bkintz/Desktop/Family Photos"

# Newer iPhoto library
if test -d Originals; then
	pushd Originals

	for year in $(ls -d 20*); do
		pushd "$year"

		echo Copying $year...

		while IFS= read -r -d $'\0' file; do
			month=$(date -j -f "%s" $(stat -f "%B" "$file") "+%m")

			DEST="$DEST_ROOT/$year/$month"

			mkdir -p "$DEST"

			cp -n "$file" "$DEST" || handle_duplicate "$file" "$DEST"
			((NUM_TOTAL++))
		done < <(find . -type f -print0)

		popd
	done

	popd

# Old iPhoto archive
else
	for year in $(ls -d 20*); do
		pushd "$year"

		for month in $(ls); do
			echo Copying $(date -j -f "%m/%Y" "$month/$year" "+%B %Y")...

			pushd "$month"

			DEST="$DEST_ROOT/$year/$month"

			mkdir -p "$DEST"

			while IFS= read -r -d $'\0' file; do
				cp -n "$file" "$DEST" || handle_duplicate "$file" "$DEST"
				((NUM_TOTAL++))
			done < <(find . \
				-type f \
				-not -path "*/Data/*" \
				-not -path "*/Originals/*" \
				-not -path "*/Thumbs/*" \
				-print0 \
			)

			popd
		done

		popd
	done
fi

popd

echo Done

echo && echo "Copied $((NUM_TOTAL - NUM_NAME_DUPES - NUM_TRUE_DUPES)) files"

echo && echo "Duplicates handled: $NUM_NAME_DUPES Filename, $NUM_TRUE_DUPES True, $((NUM_NAME_DUPES + NUM_TRUE_DUPES)) Total"

STATUS_COUNT=$(find "$DEST_ROOT" -type f -not -path '*/\.*' | wc -l | tr -d '[:space:]')
STATUS_SIZE=$(du -hs "$DEST_ROOT" | cut -f1)

echo && echo "Total of $STATUS_COUNT files copied ($STATUS_SIZE)"

echo && echo Ejecting disc...

drutil eject

echo "Bye!"
