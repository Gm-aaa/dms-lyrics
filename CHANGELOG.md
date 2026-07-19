# Changelog

本项目所有值得注意的改动都记录在此文件。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循
[语义化版本](https://semver.org/lang/zh-CN/)，与 `plugin.json` 的版本保持一致。

## [Unreleased]

### 修复
- 播放停止后歌词残留在状态栏不消失:DMS 的 `MprisController` 仅在「Stopped 且元数据
  已清空」时才移除 `activePlayer`,播放器停止后保留曲目信息(很多播放器如此)时
  `player` 引用与标题都不变化,widget 收不到任何信号。新增 `stopped` 状态
  (`playbackState === Stopped`)监听:停止时清空并隐藏,从停止恢复播放时自动重新
  抓词;暂停仍保留歌词不受影响。
- 单曲循环时歌词卡在最后一行、不再推进:Quickshell 的 `position` 为客户端插值,循环重播
  同一轨(不发 `Seeked`)时会越过曲长且永不归零;`updateSync` 现在在位置越过曲长时按曲长
  取模还原当前循环内的真实位置(与 DMS 媒体面板 `position % length` 同款思路)。
- 拖动播放进度时歌词不跟随(尤其**暂停时拖动**):此前只在 `posTimer`(250ms、仅播放时
  运行)读取位置,暂停拖动时无人触发同步。新增 `onPositionChanged` 响应式处理,seek 时
  (播放 / 暂停)立即重算当前行。

## [0.3.0] - 2026-07-10

### 变更
- **架构重构：Rust 后端彻底移除，改为纯 QML 插件。** 播放状态改为通过 DMS 内置的
  `MprisController`（D-Bus 上的 MPRIS）读取；歌词抓取改为在 QML 内用异步
  `XMLHttpRequest` 完成。不再有独立二进制、子进程、`Process`/`SplitParser` 往返，
  也不再需要 PATH 配置或 D-Bus 连接自愈逻辑（连接由 Quickshell 管理）。
- 歌词抓取与 LRC 解析拆分到独立的纯逻辑文件 `LyricsFetcher.js`，与 UI 解耦。
- 缓存由「tmpfs 磁盘文件」改为「内存 `Map`」：shell 生命周期内有效，**零磁盘写入**；
  快速切歌时用 generation token 作废过期请求的回调，避免旧歌词覆盖新歌词。
- `install.sh` / `uninstall.sh` 大幅简化为纯拷贝：只把 `plugin.json` + `*.qml` + `*.js`
  安装到插件目录，删除了下载预编译二进制、源码编译、PATH 检查、进程清理等逻辑。
- `plugin.json` 移除 `process` 权限（不再创建子进程），版本 0.2.0 → 0.3.0。

### 移除
- 整套 Rust 后端 `lyrics_backend/`（`mpris` + `ureq` 直连 D-Bus / HTTP）及预编译二进制。
- GitHub Actions 发布流程 `.github/workflows/release.yml`（不再需要构建/发布二进制）。

## [0.2.0] - 2026-07-07

### 新增
- 安装 / 卸载脚本 `install.sh` / `uninstall.sh`：默认从 GitHub Release 下载预编译二进制
  （加 `--build` 则本地源码编译，编译前检查 `cargo` / `pkg-config` / `libdbus-1` 工具链），
  二进制安装到 `~/.local/bin/dms-lyrics`（拷贝而非软链接），插件 `plugin.json` + `*.qml`
  拷贝到 DMS 用户插件目录；插件目录若为符号链接（开发软链）则跳过、不覆盖。安装前检查
  桌面系统环境兼容性（Linux + x86_64）。卸载支持 `--purge` 一并清除运行缓存。安装位置
  可用环境变量覆盖。
- GitHub Actions 发布流程：推送 `v*` tag 自动编译并创建 Release，附预编译二进制
  `dms-lyrics-x86_64-linux`，Release 说明取自本 CHANGELOG 对应版本段落。
- `plugin.json` 补全 `gapMode`（间奏显示方式）的 settings_schema 声明（类型 string，默认 `dots`），
  与设置面板已暴露的选项对齐。

### 变更
- 后端不再随插件目录分发：QML 改为按名字 `dms-lyrics` 经 PATH 调用二进制（`~/.local/bin`），
  取代原先 `pluginDirectory + "/lyrics/lyrics-backend"` 的目录内查找。
- `lyrics_backend` 版本 0.1.0 → 0.2.0，与 `plugin.json` 对齐。

### 修复
- 缓存文件名截断按 UTF-8 字符边界进行（新增 `truncate_bytes_on_char_boundary`），
  修复中文等多字节歌名在字节中间切开导致后端 panic 的问题。
- 设置面板依赖文案纠错：由「需要 playerctl / python3」改为「需要一个支持 MPRIS 的播放器
  （D-Bus 直连，无需 playerctl / python3）」，与 Rust 后端实际行为及 README 一致。

## [0.1.0]

- 初始版本：Rust 后端（`mpris` 直连 D-Bus 获取播放状态，零子进程），网易云 + lrclib 双源可配置，
  Apple Music 风格滚动歌词弹窗，单行横向跑马灯，tmpfs 缓存，自适应隐藏。
