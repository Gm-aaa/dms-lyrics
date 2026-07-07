# DMS Lyrics

A [DankMaterialShell](https://danklinux.com/) (DMS) DankBar plugin that shows
**synced lyrics** of the currently playing song in your status bar, fully rewritten in Rust for extreme efficiency and features.

为 [DankMaterialShell](https://danklinux.com/) 编写的 DankBar 插件，在状态栏中**逐行显示当前播放歌曲的同步歌词**。已使用 Rust 完全重构，带来极高效率与强大的歌词弹窗。

![screenshot](docs/screenshot.png)

---

## English

### Features & Enhancements
- **Rust Backend**: Rebuilt in Rust (`lyrics_backend`) using direct D-Bus integration via the `mpris` crate. **No subprocess forks** (like `playerctl`), resulting in 0.0% CPU overhead.
- **Apple Music-Style Popout**: Click the status bar widget to toggle a beautiful scrolling lyrics popout (`320x400`). Highlights the current line with full opacity & scale, fades out inactive lines (spotlight effect), and **smoothly auto-centers** the active line.
- **Horizontal Marquee (跑马灯)**: When the lyric line exceeds the configured **Max width**, it automatically wraps into a single line and scrolls back and forth smoothly with natural reading pauses, rather than wrapping vertically.
- **Micro-Memory Footprint**: Consumes only **~3.4 MB** of RAM (compared to ~20+ MB for the Python version).
- **Reactive Settings**: Changing the maximum width slider or provider priority updates the widget layout in real time.
- **Multi-Source Priority**: Fetches lyrics from **Netease Cloud Music** (Chinese songs) and **lrclib.net** (Western/synced focus); priority is fully configurable.
- **Zero Disk Write Cache**: Keeps transient lyrics cache in **tmpfs** (`$XDG_RUNTIME_DIR`) - automatically cleared on logout.
- **Adaptive Visibility**: Hides the status bar pill completely when no media is playing or when the track has no synced lyrics.

### Dependencies
- **DankMaterialShell** `>= 1.4.0`
- An **MPRIS-capable player** (connected directly over D-Bus).
- *Runtime: no `playerctl` or `python3` needed.* Building from source additionally needs a **Rust toolchain**, `pkg-config` and the **libdbus-1 dev library** (`libdbus-1-dev` / `dbus` / `dbus-devel`).

### Install
1. Clone the repository anywhere you like:
   ```sh
   git clone https://github.com/Gm-aaa/dms-lyrics.git
   cd dms-lyrics
   ```
2. Run the installer. By default it **downloads the prebuilt binary** from the latest GitHub Release (no Rust needed) and installs it:
   ```sh
   ./install.sh
   ```
   - The binary is copied to `~/.local/bin/dms-lyrics` (make sure `~/.local/bin` is on your `PATH`).
   - The plugin (`plugin.json` + `*.qml`) is copied to `~/.config/DankMaterialShell/plugins/lyrics`.
   - No prebuilt binary, or you prefer building yourself? Use `./install.sh --build` to compile from source (checks the toolchain first).
   - Override locations with `DMS_LYRICS_BIN_DIR` / `DMS_LYRICS_PLUGIN_DIR`.
3. Restart DMS:
   ```sh
   dms restart
   ```

Then open DMS settings (`Mod + ,`) → **Plugins**, enable **Lyrics**, and add the widget to a DankBar section.

To remove everything (binary + plugin), run `./uninstall.sh` (`--purge` also clears the runtime cache).

### Release process
Pushing a `vX.Y.Z` tag triggers a GitHub Actions workflow that builds the binary and publishes a Release with the asset `dms-lyrics-x86_64-linux`; the release notes are taken from the matching section in [`CHANGELOG.md`](CHANGELOG.md). Keep the tag in sync with the versions in `lyrics_backend/Cargo.toml` and `plugin.json`.

### Settings
- **Lyrics source** — provider priority: Netease first / lrclib first / Netease only / lrclib only.
- **Max width (px)** — maximum width of the lyric text before it starts scrolling horizontally.
- **Instrumental display** — how the bar behaves during instrumental gaps: pulsing dots / keep last line (dimmed) / icon only.

---

## 中文

### 功能与优化
- **Rust 后端**：使用 Rust 完全重构后端（`lyrics_backend`），基于 `mpris` 库直连 D-Bus 获取播放状态，**零子进程创建（摒弃了 `playerctl` 外部命令）**，CPU 消耗为 0.0%。
- **Apple Music 级歌词弹窗**：点击状态栏歌词可弹出精美的下拉框 (`320x400`)。当前句高亮放大显示，其他行呈现半透明 spotlight 聚光灯效果，歌词会根据播放进度**自动平滑滚动并居中**。
- **单行横向跑马灯 (Marquee)**：当歌词长度超出设定的**组件最大宽度**时，会自动保持单行并以优雅的读数停顿（句首停留 2 秒、匀速滚动、句尾停留 2 秒）进行左右循环滚动，绝不发生上下换行重叠。
- **极致的内存占用**：常驻运行内存仅有约 **3.4 MB**（原 Python 版本需要 20+ MB）。
- **即时响应式设置**：在设置面板拉动最大宽度滑块，顶栏组件会即时缩放，无需重启插件。
- **多歌词源优先级**：支持**网易云音乐**和 **lrclib.net** 双接口，优先级可随心调整。
- **内存无感缓存**：歌词缓存写在 **tmpfs**（`$XDG_RUNTIME_DIR`）中，不磨损硬盘，注销后即清。
- **智能自适应隐藏**：暂停、无播放器或当前曲目无同步歌词时自动隐藏，不占用状态栏空间。

### 依赖项
- **DankMaterialShell** `>= 1.4.0`
- 一个**支持 MPRIS 的播放器**（通过 D-Bus 直连）。
- *运行时无需 `playerctl` 或 `python3`。* 从源码编译还需 **Rust 工具链**、`pkg-config` 与 **libdbus-1 开发库**（`libdbus-1-dev` / `dbus` / `dbus-devel`）。

### 安装
1. 将本仓库克隆到任意位置：
   ```sh
   git clone https://github.com/Gm-aaa/dms-lyrics.git
   cd dms-lyrics
   ```
2. 运行安装脚本。默认从最新 GitHub Release **下载预编译二进制**（无需 Rust）并安装：
   ```sh
   ./install.sh
   ```
   - 二进制拷贝到 `~/.local/bin/dms-lyrics`（请确保 `~/.local/bin` 在 `PATH` 中）。
   - 插件（`plugin.json` + `*.qml`）拷贝到 `~/.config/DankMaterialShell/plugins/lyrics`。
   - 没有预编译二进制、或想自己编译？用 `./install.sh --build` 从源码编译（会先检查工具链）。
   - 可用 `DMS_LYRICS_BIN_DIR` / `DMS_LYRICS_PLUGIN_DIR` 覆盖安装位置。
3. 重启 DMS：
   ```sh
   dms restart
   ```

随后打开 DMS 设置（`Mod + ,`）→ **Plugins**，启用 **Lyrics** 并将 widget 摆放到 DankBar 对应的位置。

卸载（二进制 + 插件）：运行 `./uninstall.sh`（加 `--purge` 一并清除运行缓存）。

### 发布流程
推送形如 `vX.Y.Z` 的 tag 会触发 GitHub Actions：自动编译并发布 Release，附带产物 `dms-lyrics-x86_64-linux`，Release 说明取自 [`CHANGELOG.md`](CHANGELOG.md) 中对应版本段落。请保持该 tag 与 `lyrics_backend/Cargo.toml`、`plugin.json` 的版本一致。

### 选项设置
- **歌词源优先级**：网易云优先 / lrclib 优先 / 仅网易云 / 仅 lrclib。
- **组件最大宽度 (px)**：歌词文字的最大限制宽度，超出该宽度的歌词行会自动开启横向跑马灯滚动。
- **间奏显示方式**：歌曲间奏/停顿时状态栏的表现 —— 跳动圆点 / 保留上一句(变暗) / 仅图标占位。

---

## License
MIT
