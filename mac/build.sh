#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ -z "${WEBP_PREFIX:-}" ]]; then
  if [[ -f /opt/homebrew/lib/libwebp.a ]]; then
    WEBP_PREFIX=/opt/homebrew
  elif [[ -f /usr/local/lib/libwebp.a ]]; then
    WEBP_PREFIX=/usr/local
  else
    echo "libwebp.a 없음. brew install webp" >&2
    exit 1
  fi
fi
LIBWEBP="$WEBP_PREFIX/lib/libwebp.a"
SHARP="$WEBP_PREFIX/lib/libsharpyuv.a"
if [[ ! -f "$LIBWEBP" ]]; then
  echo "libwebp.a 없음. brew install webp" >&2
  exit 1
fi

DIST="$ROOT/dist/clipslim.app"
MACOS="$DIST/Contents/MacOS"
mkdir -p "$MACOS"
cp "$ROOT/Info.plist" "$DIST/Contents/Info.plist"

OBJ="$ROOT/dist/encode_webp.o"
mkdir -p "$ROOT/dist"
cc -c -O2 -I "$WEBP_PREFIX/include" "$ROOT/encode_webp.c" -o "$OBJ"

swiftc -O \
  -import-objc-header "$ROOT/encode_webp.h" \
  "$ROOT/Convert.swift" \
  "$ROOT/Toast.swift" \
  "$ROOT/App.swift" \
  "$ROOT/main.swift" \
  "$OBJ" "$LIBWEBP" "$SHARP" \
  -framework AppKit -framework ImageIO \
  -o "$MACOS/ClipSlim"

echo "built $DIST"
