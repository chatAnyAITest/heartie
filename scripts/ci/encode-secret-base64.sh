#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <input-file> [output-file]" >&2
  exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-${INPUT_FILE}.base64.txt}"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Input file not found: $INPUT_FILE" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

# Use a single-line base64 payload so it can be pasted directly into GitHub Secrets.
base64 < "$INPUT_FILE" | tr -d '\n' > "$OUTPUT_FILE"

BYTE_COUNT="$(wc -c < "$OUTPUT_FILE" | tr -d '[:space:]')"
echo "Base64 file written to: $OUTPUT_FILE"
echo "Encoded bytes: $BYTE_COUNT"
