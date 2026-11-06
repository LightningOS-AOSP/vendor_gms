#!/bin/bash
# vendorsetup.sh
#
# Recombines split .partNNN files back into their original large binaries
# before the ROM build starts. This keeps every tracked file under GitHub's
# 50 MB limit while still shipping the full prebuilts needed to compile.
#
# Safe to run multiple times: originals that already exist are skipped.

# Resolve the directory this script lives in (the vendor/gms repo root).
VENDOR_SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Maximum size per part file (must stay under GitHub's 50 MB file limit).
PART_SIZE="49M"

recombine_split_files() {
    local part base dir out part_count i
    local found=0 combined=0 skipped=0

    # Walk every .partNNN file in the repo.
    while IFS= read -r -d '' part; do
        # Strip the trailing .partNNN to recover the original filename.
        base="${part%.part[0-9]*}"
        # Guard: if the suffix wasn't stripped, skip.
        if [ "$base" = "$part" ]; then
            continue
        fi

        dir="$(dirname "$part")"
        out="$base"

        # If the original already exists, nothing to do (idempotent).
        if [ -e "$out" ]; then
            skipped=$((skipped + 1))
            continue
        fi

        # Count and sort the parts so they are concatenated in order.
        mapfile -t parts < <(ls -1 "$base".part* 2>/dev/null | sort)
        part_count="${#parts[@]}"

        if [ "$part_count" -eq 0 ]; then
            echo "[vendorsetup] WARNING: no parts found for $out, skipping" >&2
            continue
        fi

        echo "[vendorsetup] Recombining $out ($part_count parts) ..."
        : > "$out.tmp"
        for p in "${parts[@]}"; do
            cat "$p" >> "$out.tmp"
        done
        mv "$out.tmp" "$out"

        combined=$((combined + 1))
        found=$((found + 1))
    done < <(find "$VENDOR_SETUP_DIR" -type f -name '*.part[0-9]*' -print0 2>/dev/null)

    if [ "$combined" -gt 0 ]; then
        echo "[vendorsetup] Recombined $combined split file(s)."
    fi
    if [ "$skipped" -gt 0 ]; then
        echo "[vendorsetup] $skipped original(s) already present, skipped."
    fi
}

# Run the recombination now so prebuilts exist before any module is built.
recombine_split_files
