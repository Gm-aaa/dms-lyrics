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
- **Rust toolchain** (only needed for compilation)
- *Note: No external runtime dependencies like `playerctl` or `python3` are required.*

### Compile & Install
1. Clone the repository to your DMS plugins directory:
   ```sh
   git clone <repo-url> ~/.config/DankMaterialShell/plugins/lyrics
   ```
2. Build the Rust backend binary:
   ```sh
   cd ~/.config/DankMaterialShell/plugins/lyrics
   cargo build --release --manifest-path lyrics_backend/Cargo.toml
   ```
3. Create the symlink to let DMS find the compiled binary:
   ```sh
   ln -sf lyrics_backend/target/release/lyrics_backend lyrics-backend
   ```
4. Restart DMS:
   ```sh
   dms restart
   ```

Then open DMS settings (`Mod + ,`) → **Plugins**, enable **Lyrics**, and add the widget to a DankBar section.

### Settings
- **Lyrics source** — provider priority: Netease first / lrclib first / Netease only / lrclib only.
- **Max width (px)** — maximum width of the lyric text before it starts scrolling horizontally.

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
- **Rust 开发工具链**（仅编译时需要）
- *注：运行时不再需要 `playerctl` 或 `python3`！*

### 编译与安装
1. 将本仓库克隆至您的 DMS 插件目录：
   ```sh
   git clone <repo-url> ~/.config/DankMaterialShell/plugins/lyrics
   ```
2. 编译 Rust 后端二进制文件：
   ```sh
   cd ~/.config/DankMaterialShell/plugins/lyrics
   cargo build --release --manifest-path lyrics_backend/Cargo.toml
   ```
3. 创建软链接以供 QML 加载：
   ```sh
   ln -sf lyrics_backend/target/release/lyrics_backend lyrics-backend
   ```
4. 重启 DMS：
   ```sh
   dms restart
   ```

随后打开 DMS 设置（`Mod + ,`）→ **Plugins**，启用 **Lyrics** 并将 widget 摆放到 DankBar 对应的位置。

### 选项设置
- **歌词源优先级**：网易云优先 / lrclib 优先 / 仅网易云 / 仅 lrclib。
- **组件最大宽度 (px)**：歌词文字的最大限制宽度，超出该宽度的歌词行会自动开启横向跑马灯滚动。

---

## License
MIT
