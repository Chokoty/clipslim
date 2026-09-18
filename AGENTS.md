# Agent notes

clipslim is a local clipboard compressor. Copy an image and the clipboard becomes a small WebP (or AVIF on Mac) file. Images never leave the machine. No server, no accounts, no extra UI.

## Skills

Use **ponytail** (simplest thing that works) and **superpowers** (TDD, verify before claiming done). Both Claude Code and Grok should follow this file.

## Build

```bash
./scripts/check.sh          # macOS: build + encode fixtures/screenshot.png
./mac/build.sh              # macOS app only
# Windows (PowerShell):
./win/build.ps1
./win/dist/clipslim.exe --convert fixtures/screenshot.png out.webp
```

Needs Homebrew `webp` on macOS (`libwebp.a` + `libsharpyuv.a`, statically linked). Windows encode is ImageSharp (pure managed). Runtime brew is not required on Mac.

## Behavior that must stay

- Copy image → clipboard becomes a **file** (WebP, or AVIF on Mac), not a PNG payload. Canvases (tldraw / Excalidraw) take the file on paste.
- Quality 82, long edge 2560, keep 12 temp files.
- Skip: GIF, PDF, multiple files, already the selected format, our own write, convert-off.
- Do not delete user files. Temps: `~/Library/Caches/clipslim/` (Mac), `%LOCALAPPDATA%\clipslim\` (Windows).
- Windows is WebP only. AVIF is Mac ImageIO.

## Layout

- `mac/` AppKit menu bar. `encode_webp.c` wraps libwebp. ImageIO cannot write WebP.
- `win/` WinForms tray. `WM_CLIPBOARDUPDATE`, `Clipboard.SetFileDropList`.
- `index.html` fallback for drag/save. Chrome cannot `clipboard.write(image/webp)`.
- `scripts/check.sh` is the regression gate. Do not weaken it.

## Release

Push a version tag. Actions builds Mac + Windows and publishes GitHub Releases.

```bash
git tag v1.0.3
git push origin v1.0.3
```

Do not attach binaries by hand unless the workflow is down. Asset names must stay `clipslim-macos-arm64.zip` and `clipslim-windows-x64.exe`.
