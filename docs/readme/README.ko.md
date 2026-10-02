<h1 align="center">
  <img src="../assets/icon.png" alt="clipslim" width="72" valign="middle" /> clipslim
</h1>

<p align="center">
  <a href="https://github.com/Chokoty/clipslim"><img src="https://img.shields.io/github/stars/Chokoty/clipslim?style=flat&label=%E2%98%85&color=c43c11" alt="GitHub stars" /></a>
  <img src="https://img.shields.io/badge/license-MIT-1a1612?style=flat" alt="License: MIT" />
  <img src="https://img.shields.io/badge/macOS%20%7C%20Windows-c43c11?style=flat" alt="Supported platforms: macOS and Windows" />
  <img src="https://img.shields.io/badge/local-no%20upload-2c6e49?style=flat" alt="Runs locally, no upload" />
</p>

<p align="center">
  <sub><a href="../../README.md">English</a> · <a href="README.zh-CN.md">中文</a> · <a href="README.ja.md">日本語</a> · 한국어</sub>
</p>

<p align="center">
  <strong>스크린샷을 복사하면, 작은 파일을 붙입니다.</strong><br/>
  맥은 메뉴 막대, 윈도우는 트레이. 이미지는 이 컴퓨터 밖으로 나가지 않습니다.
</p>

<p align="center">
  <img src="../assets/hero.png" alt="PNG 스크린샷을 WebP로 줄여 tldraw / Excalidraw에 붙이는 흐름" width="960" />
</p>

tldraw와 Obsidian Excalidraw는 클립보드에 있는 것을 그대로 붙입니다. PNG 스크린샷은 용량이 큽니다. Chrome은 클립보드에 WebP를 쓰지 못하므로 (`NotAllowedError`), clipslim은 **파일**을 올려 둡니다 (WebP, 맥에서는 AVIF도). `⌘V` / `Ctrl+V`가 그 파일을 붙입니다.

픽스처 PNG(1600×900, 63.3 KB)는 맥에서 **8.6 KB WebP (−86%)**.

## 기능

<table>
<tr>
<td width="50%" valign="top">

### 메뉴 막대 / 트레이

켜 두면 이미지를 복사하는 순간 클립보드가 `.webp` 파일이 됩니다. 원본 PNG가 필요하면 **변환**을 끕니다.

</td>
<td width="50%" valign="top">

### 로컬만

계정, 서버, 폴더 감시 없음. 변환은 프로세스 안에서 끝납니다. 임시 파일은 OS 캐시 폴더에 두고 최근 12개만 남깁니다.

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 맥: WebP 또는 AVIF

WebP는 libwebp를 정적 링크합니다 (Homebrew는 빌드할 때만). AVIF는 ImageIO. 품질 82, 긴 변 2560.

</td>
<td width="50%" valign="top">

### 윈도우: WebP

품질과 최대 변은 같습니다. 클립보드에는 DIB가 아니라 파일 목록을 올려서, 캔버스가 파일을 받게 합니다.

</td>
</tr>
</table>

**그 외:** 메뉴에 마지막 변환 용량, 사본을 남기는 **저장…**, GIF/PDF/여러 파일은 건너뜀, 이미 WebP면 건너뜀.

## 설치

- **[Releases에서 받기](https://github.com/Chokoty/clipslim/releases/latest)**
- 직접: [macOS Apple Silicon](https://github.com/Chokoty/clipslim/releases/latest/download/clipslim-macos-arm64.zip) · [Windows x64](https://github.com/Chokoty/clipslim/releases/latest/download/clipslim-windows-x64.exe)

### macOS

zip을 풀고 `clipslim.app`을 엽니다. `Contents/MacOS/ClipSlim`은 터미널에서 켜지고, 터미널을 닫으면 clipslim도 종료됩니다. Developer ID 서명은 없습니다. 처음엔 **우클릭 → 열기**.

**로그인 시 실행**은 앱을 `/Applications`에 복사합니다. 그 복사가 실패하면 `~/Applications`에 복사한 뒤 로그인 항목으로 등록합니다. macOS가 승인을 기다리면 시스템 설정의 일반, 로그인 항목에서 clipslim을 허용하세요. GitHub에서 받은 빌드는 공증 전까지 로그인 때 실행이 거절될 수 있습니다.

또는 빌드:

```bash
brew install webp          # 빌드할 때만. 앱은 libwebp.a를 링크합니다
./mac/build.sh
open mac/dist/clipslim.app
```

메뉴 막대 아이콘 켜짐 → 스크린샷 복사 → 캔버스에 붙이기. 원본 PNG: **변환** 체크 해제. 포맷: **포맷 → WebP / AVIF**.

임시 파일: `~/Library/Caches/clipslim/`.

### Windows

`clipslim-windows-x64.exe`를 실행합니다. 서명 없음: SmartScreen 경고가 날 수 있습니다. 실행에 .NET SDK는 필요 없습니다.

또는 [.NET 8 SDK](https://dot.net)로 빌드:

```powershell
./win/build.ps1
./win/dist/clipslim.exe
```

트레이 아이콘 → 복사 → `Ctrl+V`. WebP만 (AVIF 없음). 임시 파일: `%LOCALAPPDATA%\clipslim\`.

## 웹 페이지 (드래그/저장)

Chrome은 여전히 클립보드에 `image/webp`를 쓰지 못합니다. **저장하거나 드래그**할 때 이 페이지를 씁니다.

```bash
python3 -m http.server 8765
```

[http://127.0.0.1:8765](http://127.0.0.1:8765) 를 엽니다. `⌘V`로 변환하고, 미리보기를 드래그하거나 **WebP 저장**을 씁니다. Chrome 우클릭 “이미지 복사”는 PNG라서, 페이지는 그 메뉴를 저장으로 바꿉니다.

## 동작

```
클립보드 이미지  →  리사이즈 (최대 2560)  →  WebP q=82  →  클립보드에 파일
```

맥은 0.4초마다 `NSPasteboard.changeCount`를 봅니다. 윈도우는 `WM_CLIPBOARDUPDATE`를 듣습니다. 페이로드는 파일 URL / `CF_HDROP`만 넣어서, 캔버스가 PNG 비트맵으로 떨어지지 않게 합니다.

ImageIO는 WebP를 쓰지 못합니다. 자세한 내용: [`docs/decisions/001-encode-backends.md`](../decisions/001-encode-backends.md), [`FINDINGS.md`](../../FINDINGS.md).

## 개발

```bash
./scripts/check.sh     # macOS: 다시 빌드 + fixtures/screenshot.png 인코드
git tag v1.0.3 && git push origin v1.0.3   # GitHub Release (맥 zip + 윈도우 exe)
```

`scripts/check.sh`는 픽스처보다 작은 RIFF/WEBP를 계속 만들어야 합니다. 에이전트 규칙: [`AGENTS.md`](../../AGENTS.md). 스펙: [`docs/superpowers/specs/`](../superpowers/specs/).

## 라이선스

MIT. [LICENSE](../../LICENSE).
