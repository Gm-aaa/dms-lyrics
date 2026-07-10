# DMS Lyrics

A [DankMaterialShell](https://danklinux.com/) (DMS) DankBar plugin that shows
**synced lyrics** of the currently playing song in your status bar — implemented as a
**pure QML plugin**, with no external binary or background process.

为 [DankMaterialShell](https://danklinux.com/) 编写的 DankBar 插件，在状态栏中**逐行显示当前播放歌曲的同步歌词**。已重构为**纯 QML 插件**，不再依赖任何外部二进制或后台进程。

![screenshot](docs/screenshot.png)

---

## English

### Features & Enhancements
- **Pure QML, zero processes**: Reads playback state through DMS's built-in
  `MprisController` (MPRIS over D-Bus) and fetches lyrics with asynchronous
  `XMLHttpRequest` — no forked subprocess, no `playerctl`, no compiled backend to install.
- **Apple Music-Style Popout**: Click the status bar widget to toggle a beautiful scrolling
  lyrics popout (`320x400`). Highlights the current line with full opacity & scale, fades out
  inactive lines (spotlight effect), and **smoothly auto-centers** the active line.
- **Horizontal Marquee (跑马灯)**: When the lyric line exceeds the configured **Max width**,
  it stays on a single line and scrolls smoothly instead of wrapping vertically.
- **Reactive Settings**: Changing the maximum width slider or provider priority updates the
  widget in real time.
- **Multi-Source Priority**: Fetches lyrics from **Netease Cloud Music** (Chinese songs) and
  **lrclib.net** (Western/synced focus); priority is fully configurable.
- **In-memory cache, zero disk writes**: Fetched lyrics are cached in memory for the shell's
  lifetime — nothing is ever written to disk.
- **Adaptive Visibility**: Hides the status bar pill completely when no media is playing or
  when the track has no synced lyrics.

### Dependencies
- **DankMaterialShell** `>= 1.4.0`
- An **MPRIS-capable player** (read via DMS's `MprisController`).
- *No `playerctl`, no `python3`, no Rust toolchain, nothing to compile.*

### Install
1. Clone the repository anywhere you like:
   ```sh
   git clone https://github.com/Gm-aaa/dms-lyrics.git
   cd dms-lyrics
   ```
2. Run the installer. It copies `plugin.json`, the `*.qml` files and `*.js` files to the DMS
   user plugin directory:
   ```sh
   ./install.sh
   ```
   - The plugin is copied to `~/.config/DankMaterialShell/plugins/lyrics`.
   - Override the location with `DMS_LYRICS_PLUGIN_DIR`.
   - Prefer to do it by hand? Just copy `plugin.json`, `*.qml` and `*.js` into that folder.
3. Restart DMS:
   ```sh
   dms restart
   ```

Then open DMS settings (`Mod + ,`) → **Plugins**, enable **Lyrics**, and add the widget to a DankBar section.

To remove it, run `./uninstall.sh` (`--purge` also clears any leftover cache from the old Rust version).

### Settings
- **Lyrics source** — provider priority: Netease first / lrclib first / Netease only / lrclib only.
- **Max width (px)** — maximum width of the lyric text before it starts scrolling horizontally.
- **Instrumental display** — how the bar behaves during instrumental gaps: pulsing dots / keep last line (dimmed) / icon only.

---

## 中文

### 功能与优化
- **纯 QML、零进程**：通过 DMS 内置的 `MprisController`（D-Bus 上的 MPRIS）读取播放状态，
  用异步 `XMLHttpRequest` 抓取歌词 —— **不创建任何子进程**，无需 `playerctl`，也没有需要安装的编译产物。
- **Apple Music 级歌词弹窗**：点击状态栏歌词可弹出精美的下拉框 (`320x400`)。当前句高亮放大，
  其他行呈现半透明 spotlight 聚光灯效果，歌词会随播放进度**自动平滑滚动并居中**。
- **单行横向跑马灯 (Marquee)**：当歌词长度超出设定的**组件最大宽度**时，会保持单行并优雅地
  横向滚动，绝不发生上下换行重叠。
- **即时响应式设置**：在设置面板拉动最大宽度滑块或切换歌词源，顶栏组件会即时更新，无需重启。
- **多歌词源优先级**：支持**网易云音乐**和 **lrclib.net** 双接口，优先级可随心调整。
- **内存缓存、零磁盘写入**：抓取到的歌词在 shell 生命周期内缓存于内存，**从不写入磁盘**。
- **智能自适应隐藏**：暂停、无播放器或当前曲目无同步歌词时自动隐藏，不占用状态栏空间。

### 依赖项
- **DankMaterialShell** `>= 1.4.0`
- 一个**支持 MPRIS 的播放器**（经 DMS 的 `MprisController` 读取）。
- *无需 `playerctl`、无需 `python3`、无需 Rust 工具链，没有任何需要编译的东西。*

### 安装
1. 将本仓库克隆到任意位置：
   ```sh
   git clone https://github.com/Gm-aaa/dms-lyrics.git
   cd dms-lyrics
   ```
2. 运行安装脚本。它会把 `plugin.json`、`*.qml` 与 `*.js` 拷贝到 DMS 用户插件目录：
   ```sh
   ./install.sh
   ```
   - 插件拷贝到 `~/.config/DankMaterialShell/plugins/lyrics`。
   - 可用 `DMS_LYRICS_PLUGIN_DIR` 覆盖安装位置。
   - 想手动装？直接把 `plugin.json`、`*.qml`、`*.js` 复制进该目录即可。
3. 重启 DMS：
   ```sh
   dms restart
   ```

随后打开 DMS 设置（`Mod + ,`）→ **Plugins**，启用 **Lyrics** 并将 widget 摆放到 DankBar 对应的位置。

卸载：运行 `./uninstall.sh`（加 `--purge` 一并清除旧 Rust 版可能残留的缓存）。

### 选项设置
- **歌词源优先级**：网易云优先 / lrclib 优先 / 仅网易云 / 仅 lrclib。
- **组件最大宽度 (px)**：歌词文字的最大限制宽度，超出后自动开启横向跑马灯滚动。
- **间奏显示方式**：歌曲间奏/停顿时状态栏的表现 —— 跳动圆点 / 保留上一句(变暗) / 仅图标占位。

---

## License
MIT
