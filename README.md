# DMS Lyrics

A [DankMaterialShell](https://danklinux.com/) (DMS) DankBar plugin that shows
**synced lyrics** of the currently playing song, scrolling line‑by‑line in your
status bar.

为 [DankMaterialShell](https://danklinux.com/) 编写的 DankBar 插件，在状态栏中
**逐行滚动显示当前播放歌曲的同步歌词**。

![screenshot](docs/screenshot.png)

---

## English

### What it does
- Reads the active MPRIS player (browser, Spotify, mpv, …) via `playerctl`.
- Fetches **synced (timed) lyrics** and displays the current line, advancing
  with playback position.
- Lyrics come from **Netease Cloud Music** (great Chinese coverage) and
  **lrclib.net** (great Western coverage); priority is configurable.
- Hides itself completely when nothing is playing or the track has no lyrics —
  no empty pill in the bar.
- Skips videos / media without an artist tag, so it never wastes API calls on
  YouTube/Bilibili clips.
- Caches results in **tmpfs** (`$XDG_RUNTIME_DIR`) — no disk writes, cleared on
  logout.

### Dependencies
- `playerctl` — read MPRIS metadata / playback position
- `python3` (standard library only — no extra packages)
- DankMaterialShell `>= 1.4.0`

### Install
```sh
git clone <repo-url> ~/.config/DankMaterialShell/plugins/lyrics
dms restart
```
Then open DMS settings (`Mod + ,`) → **Plugins**, enable **Lyrics**, and add the
widget to a DankBar section.

### Settings
- **Lyrics source** — provider priority: Netease first / lrclib first /
  Netease only / lrclib only.
- **Max width (px)** — maximum width of the lyric text before it is elided.

### How it works
`lyrics-backend.py` runs as a long‑lived process started by the widget. It polls
`playerctl` (a single combined call per tick), fetches the LRC for the current
track, and prints the current lyric line to stdout whenever it changes. The QML
widget (`LyricsWidget.qml`) reads those lines via a `SplitParser` and renders
them, collapsing to zero width when the line is empty.

### Notes
- Only tracks that have **synced** lyrics in the providers are shown; DJ remixes,
  instrumentals and videos stay hidden.
- Polling is adaptive: ~0.4 s while lyrics are showing, slower otherwise.

---

## 中文

### 功能
- 通过 `playerctl` 读取当前 MPRIS 播放器（浏览器、Spotify、mpv 等）。
- 抓取**同步（带时间轴）歌词**，按播放进度显示当前这一句。
- 歌词来自**网易云音乐**（中文覆盖好）和 **lrclib.net**（欧美覆盖好），
  优先级可在设置中选择。
- 没在放歌、或当前曲目无歌词时**完全隐藏**，状态栏不留空框。
- 自动跳过没有歌手标签的视频/媒体，**不会对 B 站/油管视频浪费 API 请求**。
- 结果缓存在 **tmpfs**（`$XDG_RUNTIME_DIR`），**不写磁盘**，注销后自动清空
  （适合 U 盘 / 只读化系统）。

### 依赖
- `playerctl` —— 读取 MPRIS 元数据 / 播放进度
- `python3` —— 仅用标准库，无需额外包
- DankMaterialShell `>= 1.4.0`

### 安装
```sh
git clone <repo-url> ~/.config/DankMaterialShell/plugins/lyrics
dms restart
```
然后打开 DMS 设置（`Mod + ,`）→ **Plugins**，启用 **Lyrics**，再把该 widget
添加到 DankBar 的某个区段。

### 设置项
- **歌词源优先级** —— 网易云优先 / lrclib 优先 / 仅网易云 / 仅 lrclib。
- **组件最大宽度 (px)** —— 歌词文字超出该宽度后省略。

### 原理
`lyrics-backend.py` 由 widget 拉起常驻运行：每个 tick 用一次合并的
`playerctl` 调用取数，抓取当前曲目的 LRC，并在歌词行变化时把当前句打印到
stdout。QML 组件（`LyricsWidget.qml`）通过 `SplitParser` 逐行读取并渲染，
空行时宽度收为 0 自动隐藏。

### 说明
- 只显示在歌词库中**有同步歌词**的曲目；DJ remix、纯音乐、视频不显示。
- 自适应轮询：显示歌词时约 0.4s，其余更慢，降低开销。

---

## License
MIT
