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
  <sub><a href="../../README.md">English</a> · <a href="README.zh-CN.md">中文</a> · 日本語 · <a href="README.ko.md">한국어</a></sub>
</p>

<p align="center">
  <strong>スクリーンショットをコピーして、小さいファイルを貼り付けます。</strong><br/>
  Mac はメニューバー、Windows はトレイ。画像はこのマシンの外に出ません。
</p>

<p align="center">
  <img src="../assets/hero.png" alt="PNG のスクリーンショットを WebP に縮小して tldraw / Excalidraw に貼る流れ" width="960" />
</p>

tldraw と Obsidian Excalidraw は、クリップボードにあるものをそのまま貼ります。PNG のスクリーンショットはサイズが大きいです。Chrome はクリップボードに WebP を書けないので (`NotAllowedError`)、clipslim は **ファイル** を載せます（WebP、Mac では AVIF も）。`⌘V` / `Ctrl+V` がそのファイルを貼ります。

フィクスチャ PNG（1600×900、63.3 KB）は Mac で **8.6 KB WebP（−86%）** になります。

メニュー項目（**변환** / **포맷** / **저장…**）はいま韓国語です。

## 機能

<table>
<tr>
<td width="50%" valign="top">

### メニューバー / トレイ

常駐します。画像をコピーすると、クリップボードが `.webp` ファイルになります。元の PNG が必要なら **변환** をオフにします。

</td>
<td width="50%" valign="top">

### ローカルのみ

アカウント、サーバ、フォルダ監視はありません。変換はプロセス内で終わります。一時ファイルは OS のキャッシュに置き、直近 12 個だけ残します。

</td>
</tr>
<tr>
<td width="50%" valign="top">

### Mac: WebP または AVIF

WebP は libwebp を静的リンクします（Homebrew はビルド時だけ）。AVIF は ImageIO。品質 82、長辺 2560。

</td>
<td width="50%" valign="top">

### Windows: WebP

品質と最大辺は同じです。クリップボードには DIB ではなくファイル一覧を載せるので、キャンバスがファイルを受け取ります。

</td>
</tr>
</table>

**そのほか:** メニューに直前の変換サイズ、コピーを残す **저장…**、GIF / PDF / 複数ファイルはスキップ、すでに WebP ならスキップ。

## インストール

- **[Releases から入手](https://github.com/Chokoty/clipslim/releases/latest)**
- 直接: [macOS Apple Silicon](https://github.com/Chokoty/clipslim/releases/latest/download/clipslim-macos-arm64.zip) · [Windows x64](https://github.com/Chokoty/clipslim/releases/latest/download/clipslim-windows-x64.exe)

### macOS

zip を解凍して `clipslim.app` を開きます。`Contents/MacOS/ClipSlim` はターミナルで起動し、ターミナルを閉じると clipslim も終了します。Developer ID 署名はありません。初回は **右クリック → 開く**。

**로그인 시 실행** はアプリを `/Applications` にコピーします。コピーできないときは `~/Applications` にコピーしてからログイン項目へ登録します。macOS が承認を待つときは、システム設定の一般、ログイン項目で clipslim を許可してください。GitHub から受け取ったビルドは、公証されるまでログイン時の起動を拒否することがあります。

またはビルド:

```bash
brew install webp          # ビルド時のみ。アプリは libwebp.a をリンクします
./mac/build.sh
open mac/dist/clipslim.app
```

メニューバーのアイコンがオン → スクリーンショットをコピー → キャンバスに貼る。元の PNG: **변환** のチェックを外す。形式: **포맷 → WebP / AVIF**。

一時ファイル: `~/Library/Caches/clipslim/`。

### Windows

`clipslim-windows-x64.exe` を実行します。未署名なので SmartScreen が警告することがあります。実行に .NET SDK は不要です。

または [.NET 8 SDK](https://dot.net) でビルド:

```powershell
./win/build.ps1
./win/dist/clipslim.exe
```

トレイアイコン → コピー → `Ctrl+V`。WebP のみ（AVIF なし）。一時ファイル: `%LOCALAPPDATA%\clipslim\`。

## Web フォールバック（ドラッグ / 保存）

Chrome はいまもクリップボードに `image/webp` を書けません。**保存またはドラッグ**するときはこのページを使います。

```bash
python3 -m http.server 8765
```

[http://127.0.0.1:8765](http://127.0.0.1:8765) を開きます。`⌘V` で変換し、プレビューをドラッグするか **WebP 저장** を使います。Chrome の右クリック「画像をコピー」は PNG になるので、ページはそのメニューを保存に差し替えます。

## 仕組み

```
クリップボードの画像  →  リサイズ（最大 2560）  →  WebP q=82  →  クリップボードにファイル
```

Mac は 0.4 秒ごとに `NSPasteboard.changeCount` を見ます。Windows は `WM_CLIPBOARDUPDATE` を受けます。ペイロードはファイル URL / `CF_HDROP` だけなので、キャンバスが PNG ビットマップに落ちません。

ImageIO は WebP を書けません。詳細: [`docs/decisions/001-encode-backends.md`](../decisions/001-encode-backends.md)、[`FINDINGS.md`](../../FINDINGS.md)。

## 開発

```bash
./scripts/check.sh     # macOS: 再ビルド + fixtures/screenshot.png をエンコード
git tag v1.0.3 && git push origin v1.0.3   # GitHub Release（macOS zip + Windows exe）
```

`scripts/check.sh` は、フィクスチャより小さい RIFF/WEBP を出し続けなければなりません。エージェント向けの規則: [`AGENTS.md`](../../AGENTS.md)。仕様: [`docs/superpowers/specs/`](../superpowers/specs/)。

## ライセンス

MIT。[LICENSE](../../LICENSE)。
