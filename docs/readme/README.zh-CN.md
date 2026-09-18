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
  <sub><a href="../../README.md">English</a> · 中文 · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a></sub>
</p>

<p align="center">
  <strong>复制截图，粘贴体积更小的文件。</strong><br/>
  Mac 在菜单栏，Windows 在托盘。图片不会离开这台电脑。
</p>

<p align="center">
  <img src="../assets/hero.png" alt="把 PNG 截图压成 WebP，再贴进 tldraw / Excalidraw" width="960" />
</p>

tldraw 和 Obsidian Excalidraw 会原样粘贴剪贴板里的内容。PNG 截图体积大。Chrome 不能把 WebP 写入剪贴板（`NotAllowedError`），所以 clipslim 改放一个 **文件**（WebP，Mac 上也可以是 AVIF）。`⌘V` / `Ctrl+V` 贴的就是那个文件。

测试用 PNG（1600×900，63.3 KB）在 Mac 上会得到 **8.6 KB WebP（−86%）**。

菜单文案（**변환** / **포맷** / **저장…**）目前是韩语。

## 功能

<table>
<tr>
<td width="50%" valign="top">

### 菜单栏 / 托盘

常开。复制一张图，剪贴板就会变成 `.webp` 文件。需要原始 PNG 时，关掉 **변환**。

</td>
<td width="50%" valign="top">

### 只在本地

没有账号、没有服务器、不监视文件夹。编码在进程内完成。临时文件放在系统缓存目录，只保留最近 12 个。

</td>
</tr>
<tr>
<td width="50%" valign="top">

### Mac：WebP 或 AVIF

WebP 静态链接 libwebp（Homebrew 只在构建时需要）。AVIF 走 ImageIO。质量 82，长边 2560。

</td>
<td width="50%" valign="top">

### Windows：WebP

质量和最大边长相同。写入剪贴板的是文件列表，不是 DIB，画布才会拿到文件。

</td>
</tr>
</table>

**另外：** 菜单里显示上次转换体积，**저장…** 可另存一份，跳过 GIF / PDF / 多文件，已经是 WebP 则跳过。

## 安装

- **[从 Releases 下载](https://github.com/Chokoty/clipslim/releases/latest)**
- 直链：[macOS Apple Silicon](https://github.com/Chokoty/clipslim/releases/latest/download/clipslim-macos-arm64.zip) · [Windows x64](https://github.com/Chokoty/clipslim/releases/latest/download/clipslim-windows-x64.exe)

### macOS

解压后打开 `clipslim.app`。未签名：第一次请 **右键 → 打开**。

或自行构建：

```bash
brew install webp          # 仅构建时需要；应用链接 libwebp.a
./mac/build.sh
open mac/dist/clipslim.app
```

菜单栏图标打开 → 复制截图 → 粘贴到画布。原始 PNG：取消勾选 **변환**。格式：**포맷 → WebP / AVIF**。

临时文件：`~/Library/Caches/webp-paste/`。

### Windows

运行 `clipslim-windows-x64.exe`。未签名：SmartScreen 可能会警告。运行不需要 .NET SDK。

或用 [.NET 8 SDK](https://dot.net) 构建：

```powershell
./win/build.ps1
./win/dist/clipslim.exe
```

托盘图标 → 复制 → `Ctrl+V`。只有 WebP（没有 AVIF）。临时文件：`%LOCALAPPDATA%\webp-paste\`。

## 网页备用（拖拽 / 保存）

Chrome 仍然不能把 `image/webp` 写入剪贴板。需要 **下载或拖拽** 文件时用这个页面。

```bash
python3 -m http.server 8765
```

打开 [http://127.0.0.1:8765](http://127.0.0.1:8765)。`⌘V` 转换；拖预览，或点 **WebP 저장**。Chrome 右键「复制图像」仍是 PNG，所以页面把该菜单改成了保存。

## 工作方式

```
剪贴板图像  →  缩放（最长边 2560）  →  WebP q=82  →  剪贴板上的文件
```

Mac 每 0.4 秒看一次 `NSPasteboard.changeCount`。Windows 监听 `WM_CLIPBOARDUPDATE`。剪贴板载荷只有文件 URL / `CF_HDROP`，画布不会退回到 PNG 位图。

ImageIO 不能写 WebP。细节见 [`docs/decisions/001-encode-backends.md`](../decisions/001-encode-backends.md)、[`FINDINGS.md`](../../FINDINGS.md)。

## 开发

```bash
./scripts/check.sh     # macOS：重新构建并编码 fixtures/screenshot.png
git tag v1.0.1 && git push origin v1.0.1   # GitHub Release（macOS zip + Windows exe）
```

`scripts/check.sh` 必须继续产出比测试图更小的 RIFF/WEBP。代理规则：[`AGENTS.md`](../../AGENTS.md)。规格：[`docs/superpowers/specs/`](../superpowers/specs/)。

## 许可

MIT。见 [LICENSE](../../LICENSE)。
