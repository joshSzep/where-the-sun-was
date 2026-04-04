#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
manuscript_dir="$repo_root/manuscript"
output_file="$repo_root/Where The Sun Was.md"

{
  printf '# Where The Sun Was\n\n'
  printf 'A Novel by Joshua Szepietowski\n'

  while IFS= read -r -d '' part_dir; do
    part_name=$(basename "$part_dir")
    printf '\n## %s\n' "$part_name"

    while IFS= read -r -d '' chapter_file; do
      chapter_name=${chapter_file##*/}
      chapter_name=${chapter_name%.md}

      printf '\n### %s\n\n' "$chapter_name"

      awk 'NR == 1 && /^# / { next } NR == 2 && /^$/ { next } { print }' "$chapter_file"
    done < <(find "$part_dir" -maxdepth 1 -type f -name '*.md' -print0 | sort -z)
  done < <(find "$manuscript_dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

  printf '\n'
} > "$output_file"

printf 'Wrote %s\n' "$output_file"