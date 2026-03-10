# Configurable File Renamer

A flexible bash script that renames files by splitting their names on a delimiter, then reassembling selected fields in a new order with a new separator.

## Quick Start

```bash
chmod +x rename_files.sh

# Preview changes first (no files are modified)
./rename_files.sh --dry-run

# Apply the renames
./rename_files.sh
```

## The Problem

You have files named with a consistent delimiter-separated structure, but the fields are in the wrong order or you want to drop some of them.

**Before:**

```
My Movie ~ John Doe ~ BigStudio ~ Jane Smith.mp4
Another Film ~ Alice ~ StudioX ~ Bob.mkv
```

**After** (default settings):

```
John Doe - My Movie - BigStudio.mp4
Alice - Another Film - StudioX.mkv
```

## How It Works

1. Each filename is split on a **delimiter** (default: `" ~ "`).
2. The resulting fields are numbered **1, 2, 3, …** from left to right.
3. A **pattern** (default: `"2,1,3"`) selects which fields to keep and in what order.
4. The selected fields are joined with a **separator** (default: `" - "`).
5. The original file extension is preserved.

```
Original:  "My Movie ~ John Doe ~ BigStudio ~ Jane Smith.mp4"
Fields:     1=My Movie   2=John Doe   3=BigStudio   4=Jane Smith
Pattern:    2, 1, 3
Result:    "John Doe - My Movie - BigStudio.mp4"
```

## Options

| Flag                | Description                                 | Default   |
| ------------------- | ------------------------------------------- | --------- |
| `-d`, `--delimiter` | String to split the filename on             | `" ~ "`   |
| `-s`, `--separator` | String used to join fields in the output    | `" - "`   |
| `-p`, `--pattern`   | Comma-separated, 1-based field indices      | `"2,1,3"` |
| `-n`, `--dry-run`   | Preview renames without modifying any files | _(off)_   |
| `-h`, `--help`      | Show the built-in help message              |           |

## Examples

### Default — swap actor and title, drop actor2

```bash
# "Title ~ Actor1 ~ Studio ~ Actor2.ext"  →  "Actor1 - Title - Studio.ext"
./rename_files.sh
```

### Custom delimiter and separator

```bash
# Split on " | ", join with " -- "
./rename_files.sh -d " | " -s " -- " -p "3,1"
```

### Reverse all four fields

```bash
./rename_files.sh -p "4,3,2,1"
```

### Keep only the first and last fields

```bash
./rename_files.sh -p "1,4"
```

### Dry run with a different delimiter

```bash
./rename_files.sh -d " - " -p "2,1" --dry-run
```

## Safety Features

- **Dry-run mode** — preview every rename before committing.
- **No overwrites** — if the target filename already exists, the file is skipped.
- **No-op detection** — files whose names would not change are skipped.
- **Field count validation** — files that don't have enough fields for the pattern are skipped.
- **Directory filtering** — directories are ignored, only files are processed.

## Output

The script logs every action it takes:

```
RENAME:  My Movie ~ John Doe ~ BigStudio ~ Jane Smith.mp4 -> John Doe - My Movie - BigStudio.mp4
SKIP (target exists): Another ~ File ~ Name ~ Here.mkv -> File - Another - Name.mkv
SKIP (not enough fields): no-delimiters.txt

Done. 1 file(s) renamed.
```

## Requirements

- **Bash** 4.0+
- **awk** (POSIX-compatible; available by default on macOS and Linux)
- **mv** (coreutils)

## License

This project is released into the public domain — use it however you like.
