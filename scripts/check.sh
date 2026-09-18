#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/mac/dist/clipslim.app/Contents/MacOS/WebPPaste"

"$ROOT/mac/build.sh"

tmp="$(mktemp -d /tmp/webp-paste.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
webp="$tmp/out.webp"
avif="$tmp/out.avif"
alpha_png="$tmp/alpha.png"
alpha_webp="$tmp/alpha.webp"
alpha_pam="$tmp/alpha.pam"

"$BIN" --convert "$ROOT/fixtures/screenshot.png" "$webp"
"$BIN" --convert "$ROOT/fixtures/screenshot.png" "$avif"

python3 - "$ROOT/fixtures/screenshot.png" "$webp" "$avif" <<'PY'
import pathlib, sys
png, webp, avif = (pathlib.Path(p) for p in sys.argv[1:])
src = png.stat().st_size
w = webp.read_bytes()
a = avif.read_bytes()
if w[:4] != b"RIFF" or w[8:12] != b"WEBP":
    raise SystemExit(f"not webp: {w[:12]!r}")
if b"ftyp" not in a[:32] or b"avif" not in a[:32]:
    raise SystemExit(f"not avif: {a[:16]!r}")
if len(w) >= src:
    raise SystemExit(f"webp not smaller: {len(w)} >= {src}")
if len(a) >= src:
    raise SystemExit(f"avif not smaller: {len(a)} >= {src}")
print(f"ok  png {src}  webp {len(w)}  avif {len(a)}")
PY

python3 - "$alpha_png" <<'PY'
import pathlib, struct, sys, zlib

def chunk(tag, data):
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

w = h = 2
raw = b""
for _ in range(h):
    raw += b"\x00" + bytes([255, 0, 0, 128] * w)
ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
pathlib.Path(sys.argv[1]).write_bytes(png)
PY

"$BIN" --convert "$alpha_png" "$alpha_webp"
dwebp -pam "$alpha_webp" -o "$alpha_pam" >/dev/null 2>&1

python3 - "$alpha_pam" <<'PY'
import pathlib, sys

data = pathlib.Path(sys.argv[1]).read_bytes()
header, raw = data.split(b"ENDHDR\n", 1)
r, g, b, a = raw[0], raw[1], raw[2], raw[3]
# Premultiplied RGBA fed to WebPEncodeRGBA yields ~128,0,0. Straight red stays near 255.
if a < 120 or a > 136:
    raise SystemExit(f"alpha not ~128: {(r, g, b, a)}")
if r < 200 or g > 40 or b > 40:
    raise SystemExit(f"straight red became premul-dark: {(r, g, b, a)}")
print(f"ok  alpha rgba {(r, g, b, a)}")
PY
