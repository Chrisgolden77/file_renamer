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
    cat <<EOF
Configurable File Renamer

Splits filenames on a delimiter and reassembles them in a new order/format.

Usage:
  ${0##*/} [options]

Options:
  -d, --delimiter DELIM    Delimiter to split on             (default: " ~ ")
  -s, --separator SEP      Separator in the output name      (default: " - ")
  -p, --pattern   PATTERN  Output pattern using field indices (default: "2,1,3")
  -n, --dry-run            Show what would happen without renaming
  -h, --help               Show this help message and exit

Field indices are 1-based, matching the position in the original filename.

Example:
  Given:  "My Movie ~ John Doe ~ BigStudio ~ Jane Smith.mp4"
  Fields:  1=My Movie  2=John Doe  3=BigStudio  4=Jane Smith

  Default pattern "2,1,3" produces:
    "John Doe - My Movie - BigStudio.mp4"

  Custom usage:
    ${0##*/} -d " - " -s ", " -p "3,1" -n
EOF
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

# ── Validate and parse the pattern ───────────────────────────────────────────
IFS=',' read -ra indices <<< "$PATTERN"
if (( ${#indices[@]} == 0 )); then
    echo "Error: pattern is empty." >&2
    exit 1
fi

max_index=0
for idx in "${indices[@]}"; do
    if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 1 )); then
        echo "Error: pattern index '$idx' is not a positive integer." >&2
        exit 1
    fi
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
affected_files=()
unaffected_files=()

# Count total candidate files first
all_files=()
for file in $glob; do
    [[ -d "$file" ]] && continue
    all_files+=("$file")
done
total=${#all_files[@]}
current=0

for file in "${all_files[@]}"; do
    (( current++ )) || true
    printf "\rEvaluating %d of %d files..." "$current" "$total" >&2

    should_skip=false
    skip_reason=""

    # Separate the extension from the base name
    extension=""
    base="$file"
    if [[ "$file" == *.* ]]; then
        extension=".${file##*.}"
        base="${file%.*}"
    fi

    # Split the base name on the delimiter into an array
    mapfile -t parts < <(awk -v d="$DELIMITER" '{
        n = split($0, a, d)
        for (i = 1; i <= n; i++) {
            # trim whitespace
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", a[i])
            printf "%s\n", a[i]
        }
    }' <<< "$base")

    # ── Skip checks ──────────────────────────────────────────────────────
    if (( ${#parts[@]} < max_index )); then
        should_skip=true
        skip_reason="not enough fields (found ${#parts[@]}, need $max_index)"
    fi

    # Assemble the new name from the pattern
    new_name=""
    if ! $should_skip; then
        new_base=""
        for idx in "${indices[@]}"; do
            if [[ -n "$new_base" ]]; then
                new_base+="${SEPARATOR}"
            fi
            new_base+="${parts[$((idx - 1))]}"
        done
        new_name="${new_base}${extension}"

        if [[ "$file" == "$new_name" ]]; then
            should_skip=true
            skip_reason="name unchanged"
        elif ! $DRY_RUN && [[ -e "$new_name" ]]; then
            should_skip=true
            skip_reason="target already exists"
        fi
    fi

    # ── Classify ─────────────────────────────────────────────────────────
    if $should_skip; then
        unaffected_files+=("SKIP ($skip_reason): $file")
    else
        affected_files+=("$file -> $new_name")
    fi
done

# Clear the progress line
printf "\r\033[K" >&2

# ── Execute or preview ───────────────────────────────────────────────────────
if $DRY_RUN; then
    for entry in "${affected_files[@]}"; do
        echo "DRY-RUN: $entry"
    done
else
    for entry in "${affected_files[@]}"; do
        file="${entry%% -> *}"
        new_name="${entry#* -> }"
        echo "RENAME:  $entry"
        mv -- "$file" "$new_name"
    done
fi

# ── Summary ──────────────────────────────────────────────────────────────────
if (( ${#unaffected_files[@]} > 0 )); then
    echo ""
    for entry in "${unaffected_files[@]}"; do
        echo "$entry"
    done
fi

echo ""
if $DRY_RUN; then
    echo "Done. ${#affected_files[@]} file(s) would be renamed, ${#unaffected_files[@]} skipped."
else
    echo "Done. ${#affected_files[@]} file(s) renamed, ${#unaffected_files[@]} skipped."
fi