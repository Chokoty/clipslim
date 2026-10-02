<h1 align="center">
  <img src="docs/assets/icon.png" alt="clipslim" width="72" valign="middle" /> clipslim
</h1>

<p align="center">
  <a href="https://github.com/Chokoty/clipslim"><img src="https://img.shields.io/github/stars/Chokoty/clipslim?style=flat&label=%E2%98%85&color=c43c11" alt="GitHub stars" /></a>
  <img src="https://img.shields.io/badge/license-MIT-1a1612?style=flat" alt="License: MIT" />
  <img src="https://img.shields.io/badge/macOS%20%7C%20Windows-c43c11?style=flat" alt="Supported platforms: macOS and Windows" />
  <img src="https://img.shields.io/badge/local-no%20upload-2c6e49?style=flat" alt="Runs locally, no upload" />
</p>

<p align="center">
  <sub><a href="docs/readme/README.zh-CN.md">中文</a> · <a href="docs/readme/README.ja.md">日本語</a> · <a href="docs/readme/README.ko.md">한국어</a></sub>
</p>

<p align="center">
  <strong>Copy a screenshot. Paste a smaller file.</strong><br/>
  Menu bar on Mac, tray on Windows. The image never leaves the machine.
</p>

<p align="center">
  <img src="docs/assets/hero.png" alt="Copy a PNG screenshot, shrink it, paste into tldraw or Excalidraw" width="960" />
</p>

tldraw and Obsidian Excalidraw take whatever is on the clipboard. A PNG screenshot is large. Chrome will not put WebP on the clipboard (`NotAllowedError`), so clipslim writes a **file** instead (WebP, or AVIF on Mac). `⌘V` / `Ctrl+V` pastes that file.

On the fixture PNG (1600×900, 63.3 KB) the Mac encoder produces **8.6 KB WebP (−86%)**.

## Features

<table>
<tr>
<td width="50%" valign="top">

### Menu bar / tray

clipslim slims the clipboard. Copy an image, paste a small file. WebP by default, AVIF on Mac. Turn **변환** off when you need the original PNG.

</td>
<td width="50%" valign="top">

### Local only

No account, no server, no folder watcher. Encode runs in-process. Temp files stay in the OS cache directory (last 12 kept).

</td>
</tr>
<tr>
<td width="50%" valign="top">

### Mac: WebP or AVIF

WebP via statically linked libwebp (Homebrew is build-time only). AVIF via ImageIO. Quality 82, long edge 2560.

</td>
<td width="50%" valign="top">

### Windows: WebP

Same quality and max edge. Clipboard write is a file drop list, not a DIB, so canvases take the file.

</td>
</tr>
</table>

**Also:** last conversion size in the menu, **저장…** to keep a copy, GIF/PDF/multi-file skipped, already-WebP skipped.

## Install

- **[Download from Releases](https://github.com/Chokoty/clipslim/releases/latest)**
- Direct: [macOS Apple Silicon](https://github.com/Chokoty/clipslim/releases/latest/download/clipslim-macos-arm64.zip) · [Windows x64](https://github.com/Chokoty/clipslim/releases/latest/download/clipslim-windows-x64.exe)

### macOS

Unzip and open `clipslim.app`. `Contents/MacOS/ClipSlim` starts in Terminal, and closing Terminal quits clipslim. The build has no Developer ID signature. First launch is **right-click → Open**.

**로그인 시 실행** copies the app into `/Applications`, or into `~/Applications` when that copy fails, then registers a login item. If macOS asks for approval, allow clipslim in System Settings under General, Login Items. A download from GitHub can still refuse to open at login until the app is notarized.

Or build:

```bash
brew install webp          # build only; the app links libwebp.a
./mac/build.sh
open mac/dist/clipslim.app
```

Menu bar icon on → copy a screenshot → paste into the canvas. Original PNG: uncheck **변환**. Format: **포맷 → WebP / AVIF**.

Temps: `~/Library/Caches/clipslim/`.

### Windows

Run `clipslim-windows-x64.exe`. Unsigned: SmartScreen may warn. No .NET SDK needed to run.

Or build with [.NET 8 SDK](https://dot.net):

```powershell
./win/build.ps1
./win/dist/clipslim.exe
```

Tray icon → copy → `Ctrl+V`. WebP only (no AVIF). Temps: `%LOCALAPPDATA%\clipslim\`.

## Web fallback

Chrome still cannot write `image/webp` to the clipboard. Use the page to **download or drag** a file.

```bash
python3 -m http.server 8765
```

Open [http://127.0.0.1:8765](http://127.0.0.1:8765). `⌘V` converts; drag the preview or use **WebP 저장**. Right-click “copy image” in Chrome is PNG, so the page replaces that menu with save.

## How it works

```
clipboard image  →  resize (max 2560)  →  WebP q=82  →  file on clipboard
```

Mac polls `NSPasteboard.changeCount` every 0.4s. Windows listens for `WM_CLIPBOARDUPDATE`. Pasteboard payload is a file URL / `CF_HDROP` only, so the canvas does not fall back to a PNG bitmap.

ImageIO cannot write WebP. Details: [`docs/decisions/001-encode-backends.md`](docs/decisions/001-encode-backends.md), [`FINDINGS.md`](FINDINGS.md).

## Develop

```bash
./scripts/check.sh     # macOS: rebuild + encode fixtures/screenshot.png
git tag v1.0.3 && git push origin v1.0.3   # GitHub Release (macOS zip + Windows exe)
```

`scripts/check.sh` must keep producing a RIFF/WEBP smaller than the fixture. Agent rules: [`AGENTS.md`](AGENTS.md). Specs: [`docs/superpowers/specs/`](docs/superpowers/specs/).

## License

MIT. See [LICENSE](LICENSE).
