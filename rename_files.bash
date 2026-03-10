#!/usr/bin/env bash

# =============================================================================
# Configurable File Renamer
#
# Splits filenames on a delimiter and reassembles them in a new order/format.
#
# Usage:
#   ./rename_files.sh [options]
#
# Options:
#   -d, --delimiter   DELIM   Delimiter to split on            (default: " ~ ")
#   -s, --separator   SEP     Separator in the output name     (default: " - ")
#   -p, --pattern     PATTERN Output pattern using field indices (default: "2,1,3")
#   -n, --dry-run             Show what would happen without renaming
#   -h, --help                Show this help message
#
# Field indices are 1-based, matching the position in the original filename.
#
# Example:
#   Given:  "My Movie ~ John Doe ~ BigStudio ~ Jane Smith.mp4"
#   Fields:  1=My Movie  2=John Doe  3=BigStudio  4=Jane Smith
#
#   Default pattern "2,1,3" produces:
#     "John Doe - My Movie - BigStudio.mp4"
# =============================================================================

set -euo pipefail
shopt -s nullglob

# ── Defaults ──────────────────────────────────────────────────────────────────
DELIMITER=" ~ "
SEPARATOR=" - "
PATTERN="2,1,3"
DRY_RUN=false

# ── Argument parsing ─────────────────────────────────────────────────────────
usage() {
    sed -n '/^# Usage:/,/^# ====/p' "$0" | sed 's/^# \?//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--delimiter) DELIMITER="$2"; shift 2 ;;
        -s|--separator) SEPARATOR="$2"; shift 2 ;;
        -p|--pattern)   PATTERN="$2";   shift 2 ;;
        -n|--dry-run)   DRY_RUN=true;   shift   ;;
        -h|--help)      usage                    ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# ── Build the glob ──────────────────────────────���────────────────────────────
# Determine the minimum number of delimiters required from the pattern.
IFS=',' read -ra indices <<< "$PATTERN"
max_index=0
for idx in "${indices[@]}"; do
    (( idx > max_index )) && max_index=$idx
done

# The glob needs (max_index - 1) delimiters so there are at least max_index fields.
# We use the first character of the delimiter for globbing (good enough to pre-filter).
glob_char="${DELIMITER:0:1}"
glob="*"
for (( i = 1; i < max_index; i++ )); do
    glob+="${glob_char}*"
done

# ── Process files ────────────────────────────────────────────────────────────
count=0

for file in $glob; do
    # Skip directories
    [[ -d "$file" ]] && continue

    # Separate the extension from the base name
    extension=""
    base="$file"
    if [[ "$file" == *.* ]]; then
        extension=".${file##*.}"
        base="${file%.*}"
    fi

    # Split the base name on the delimiter into an array
    IFS= read -ra parts <<< "$(awk -v d="$DELIMITER" '{
        n = split($0, a, d)
        for (i = 1; i <= n; i++) {
            # trim whitespace
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", a[i])
            printf "%s\n", a[i]
        }
    }' <<< "$base")"

    # Verify we have enough fields
    if (( ${#parts[@]} < max_index )); then
        echo "SKIP (not enough fields): $file"
        continue
    fi

    # Assemble the new name from the pattern
    new_base=""
    for idx in "${indices[@]}"; do
        if [[ -n "$new_base" ]]; then
            new_base+="${SEPARATOR}"
        fi
        new_base+="${parts[$((idx - 1))]}"
    done
    new_name="${new_base}${extension}"

    # Skip if the name wouldn't change
    if [[ "$file" == "$new_name" ]]; then
        echo "SKIP (unchanged): $file"
        continue
    fi

    # Avoid overwriting an existing file
    if [[ -e "$new_name" ]]; then
        echo "SKIP (target exists): $file -> $new_name"
        continue
    fi

    if $DRY_RUN; then
        echo "DRY-RUN: $file -> $new_name"
    else
        echo "RENAME:  $file -> $new_name"
        mv -- "$file" "$new_name"
    fi
    (( count++ ))
done

echo ""
if $DRY_RUN; then
    echo "Done. $count file(s) would be renamed."
else
    echo "Done. $count file(s) renamed."
fi