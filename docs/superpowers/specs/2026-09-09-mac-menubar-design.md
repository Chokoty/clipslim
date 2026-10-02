# webp-paste Mac menu bar

Personal always-on converter: copy an image, clipboard becomes a small WebP file, paste into tldraw / Obsidian Excalidraw with ⌘V.

## Flow
- Menu bar icon. Default on.
- On: new image on the clipboard is resized (long edge 2560) and written as WebP or AVIF quality 82, then the clipboard is replaced with that file.
- Off: clipboard is not touched. Turning on or changing format does not convert whatever is already there.
- Menu: 변환 (checkbox), 알림, 로그인 시 실행, 포맷 (WebP / AVIF), last size `원본 → N format (−N%)`, 저장… (last file copy via save panel), 종료.
- 로그인 시 실행 copies `clipslim.app` to `/Applications`, or `~/Applications` if that copy fails, then registers it with `SMAppService`. Default off. `requiresApproval` opens System Settings.
- No settings window, sliders, or network.

## Convert / skip
Convert: PNG, JPEG, TIFF, HEIC, BMP, or a single image file, while on. The other format (WebP↔AVIF) is converted if the user copies that file.
Skip: off; text; our own write; already the selected format; GIF; PDF; multiple files; encode failure (leave clipboard).
Do not delete user files. Temp files live in `~/Library/Caches/webp-paste/` (keep 12).

## Architecture
One LSUIElement AppKit process. Poll `NSPasteboard.changeCount` ~0.4s. WebP: libwebp (`WebPEncodeRGBA`); ImageIO cannot write WebP. AVIF: ImageIO `public.avif`. Pasteboard write is file URL + `NSFilenamesPboardType` only (no PNG payload, so canvases take the file).

## Verify
- `WebPPaste --convert fixtures/screenshot.png /tmp/out.webp` → RIFF/WEBP, smaller than input.
- `WebPPaste --convert fixtures/screenshot.png /tmp/out.avif` → `ftypavif`, smaller than input.
- `--once` after a PNG is on the clipboard → pasteboard file matches the selected format.
- On/off: off leaves clipboard; on converts the next copy.
