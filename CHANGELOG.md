# Changelog

本项目所有值得注意的改动都记录在此文件。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循
[语义化版本](https://semver.org/lang/zh-CN/)。发布 tag 形如 `vX.Y.Z`，与 `lyrics_backend/Cargo.toml`
和 `plugin.json` 的版本保持一致；推送该 tag 会由 GitHub Actions 自动构建并发布 Release，
Release 说明取自本文件对应版本段落。

## [Unreleased]

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
