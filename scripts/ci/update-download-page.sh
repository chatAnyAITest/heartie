#!/usr/bin/env bash
set -euo pipefail

: "${TAG_NAME:?TAG_NAME is required}"
: "${VERSION:?VERSION is required}"
: "${CHANNEL:?CHANNEL is required}"
: "${BUNDLE_ID:?BUNDLE_ID is required}"
: "${DISPLAY_NAME:?DISPLAY_NAME is required}"
: "${UPDATE_TARGET:=all}"
: "${IPA_URL:=}"
: "${APK_URL:=}"

DATE="$(date -u +%Y-%m-%d)"
export DATE

mkdir -p docs

python3 <<'PY'
import json
import os
from pathlib import Path

target = os.environ["UPDATE_TARGET"]
if target not in {"ios", "android", "all"}:
    raise SystemExit(f"Unsupported UPDATE_TARGET: {target}")

release_path = Path("docs/release.json")
existing = {}
if release_path.exists():
    try:
        existing = json.loads(release_path.read_text())
    except json.JSONDecodeError:
        existing = {}

def resolve_url(target_platform: str, payload_key: str, env_key: str) -> str:
    incoming = os.environ.get(env_key, "").strip()
    current = str(existing.get(payload_key, "")).strip()

    if target == target_platform:
        if not incoming:
            raise SystemExit(f"{env_key} is required when UPDATE_TARGET={target_platform}")
        return incoming

    if target == "all":
        return incoming or current

    return current

payload = {
    "tag_name": os.environ["TAG_NAME"],
    "version": os.environ["VERSION"],
    "channel": os.environ["CHANNEL"],
    "app_display_name": os.environ["DISPLAY_NAME"],
    "bundle_identifier": os.environ["BUNDLE_ID"],
    "ipa_url": resolve_url("ios", "ipa_url", "IPA_URL"),
    "apk_url": resolve_url("android", "apk_url", "APK_URL"),
    "date": os.environ["DATE"],
}

release_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
PY

if [[ "$UPDATE_TARGET" == "ios" || "$UPDATE_TARGET" == "all" ]]; then
  RESOLVED_IPA_URL="$IPA_URL"
  if [[ -z "$RESOLVED_IPA_URL" && -f docs/release.json ]]; then
    RESOLVED_IPA_URL="$(python3 - <<'PY'
import json
from pathlib import Path

data = json.loads(Path("docs/release.json").read_text())
print(data.get("ipa_url", ""))
PY
)"
  fi

  if [[ -z "$RESOLVED_IPA_URL" ]]; then
    echo "IPA_URL is required when updating iOS download metadata" >&2
    exit 1
  fi

cat > docs/manifest.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key>
          <string>software-package</string>
          <key>url</key>
          <string>${RESOLVED_IPA_URL}</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key>
        <string>${BUNDLE_ID}</string>
        <key>bundle-version</key>
        <string>${VERSION}</string>
        <key>kind</key>
        <string>software</string>
        <key>title</key>
        <string>${DISPLAY_NAME}</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
EOF
fi

echo "Updated download page metadata for ${TAG_NAME}"
