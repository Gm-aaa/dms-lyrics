#!/usr/bin/env bash
#
# DMS Lyrics 安装脚本 / installer
#
# 默认从 GitHub 最新 Release 下载预编译二进制（用户无需 Rust）；加 --build 则本地用
# cargo 从源码编译（编译前检查工具链）。插件 QML 文件从当前克隆的仓库复制安装。
#
# 安装位置（可用环境变量覆盖）：
#   二进制 → $DMS_LYRICS_BIN_DIR      (默认 ~/.local/bin)，安装为 dms-lyrics
#   插件   → $DMS_LYRICS_PLUGIN_DIR   (默认 ~/.config/DankMaterialShell/plugins/lyrics)
#   仓库   → $DMS_LYRICS_REPO         (默认 Gm-aaa/dms-lyrics，用于下载 Release)
#
# 用法：
#   ./install.sh            # 下载 Release 预编译二进制并安装
#   ./install.sh --build    # 本地源码编译再安装（需 Rust + pkg-config + libdbus-1 开发库）
#
set -euo pipefail

REPO="${DMS_LYRICS_REPO:-Gm-aaa/dms-lyrics}"
BIN_DIR="${DMS_LYRICS_BIN_DIR:-$HOME/.local/bin}"
PLUGIN_DIR="${DMS_LYRICS_PLUGIN_DIR:-$HOME/.config/DankMaterialShell/plugins/lyrics}"
ASSET="dms-lyrics-x86_64-linux"
BIN_NAME="dms-lyrics"
CARGO_BIN="lyrics_backend"  # cargo 产物名

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

msg()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m警告:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m错误:\033[0m %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"; }

usage() { sed -n '2,/^set -euo/p' "$0" | sed 's/^#\{0,1\} \{0,1\}//; /^set -euo/d'; }

BUILD_FROM_SOURCE=0
for arg in "$@"; do
    case "$arg" in
        --build) BUILD_FROM_SOURCE=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "未知参数：$arg（--help 查看用法）" ;;
    esac
done

# 插件文件必须来自本地克隆的仓库
[ -f "$SCRIPT_DIR/plugin.json" ] \
    || die "请在克隆的仓库根目录运行本脚本（缺少 plugin.json）"

# --- 桌面系统环境兼容性检查 ---
# 硬性前置：仅支持 Linux（后端是 Linux D-Bus 程序，其它系统编译也无意义）。
# 架构不作硬性拦截：预编译二进制仅 x86_64，其它架构在取二进制时自动回退到源码编译。
check_compat() {
    local os
    os="$(uname -s)"
    [ "$os" = "Linux" ] || die "仅支持 Linux（当前：$os）。"
    msg "环境检查通过 / Environment OK: $os $(uname -m)"
}

SRC_BIN=""
TMP_BIN=""
cleanup() { [ -n "$TMP_BIN" ] && rm -f "$TMP_BIN"; }
trap cleanup EXIT

check_toolchain() {
    need cargo
    command -v pkg-config >/dev/null 2>&1 || die "缺少 pkg-config（编译 libdbus 绑定需要）。"
    pkg-config --exists dbus-1 2>/dev/null \
        || die "缺少 libdbus-1 开发库（Debian/Ubuntu: libdbus-1-dev；Arch: dbus；Fedora: dbus-devel）。"
}

build_binary() {
    check_toolchain
    msg "本地编译 / Building from source (cargo build --release)..."
    cargo build --release --manifest-path "$SCRIPT_DIR/lyrics_backend/Cargo.toml"
    # 尊重可能自定义的 target-dir
    local td
    td="$(cargo metadata --no-deps --format-version 1 \
        --manifest-path "$SCRIPT_DIR/lyrics_backend/Cargo.toml" 2>/dev/null \
        | sed -n 's/.*"target_directory":"\([^"]*\)".*/\1/p')"
    [ -n "$td" ] || td="$SCRIPT_DIR/lyrics_backend/target"
    SRC_BIN="$td/release/$CARGO_BIN"
    [ -f "$SRC_BIN" ] || die "未找到编译产物：$SRC_BIN"
}

download_binary() {
    # 用 GitHub 稳定的 latest 资产跳转地址，绕开限流严重的未认证 API 与 JSON 解析。
    local url="https://github.com/$REPO/releases/latest/download/$ASSET"
    msg "下载最新 Release / Downloading $url ..."
    TMP_BIN="$(mktemp)"
    curl -fSL --progress-bar "$url" -o "$TMP_BIN" || return 1
    [ -s "$TMP_BIN" ] || { warn "下载得到空文件 / empty download"; return 1; }
    SRC_BIN="$TMP_BIN"
}

check_compat

# 获取二进制：--build 直接源码编译；否则优先下载，遇到以下任一情况自动回退到源码编译：
#   非 x86_64 架构（无预编译二进制）/ 缺少 curl / 下载失败或得到空文件。
# 回退编译时 check_toolchain 若发现工具链缺失，会给出明确的安装提示后退出。
install_binary() {
    if [ "$BUILD_FROM_SOURCE" -eq 1 ]; then
        build_binary
        return
    fi
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64)
            if command -v curl >/dev/null 2>&1; then
                if download_binary; then
                    return
                fi
                warn "下载失败，自动回退到本地源码编译…/ download failed, falling back to build…"
            else
                warn "未找到 curl，无法下载预编译二进制，自动回退到本地源码编译…"
            fi
            ;;
        *)
            warn "本机架构 $arch 无预编译二进制，改为本地源码编译…/ no prebuilt binary for $arch, building…"
            ;;
    esac
    build_binary
}
install_binary

# 安装二进制（拷贝到 PATH 目录，非软链接）
msg "安装二进制 / Installing binary → $BIN_DIR/$BIN_NAME"
install -Dm755 "$SRC_BIN" "$BIN_DIR/$BIN_NAME"

# 安装插件：仅 plugin.json + *.qml，绝不含二进制。
# 若插件目录是符号链接（本机开发软链），保持不动、跳过拷贝，避免顺着软链把文件写进仓库。
if [ -L "$PLUGIN_DIR" ]; then
    warn "插件目录是符号链接（开发软链），保留不动、跳过拷贝：$PLUGIN_DIR"
    warn "插件 QML 将直接由软链指向的源码提供。"
else
    msg "安装插件 / Installing plugin → $PLUGIN_DIR"
    mkdir -p "$PLUGIN_DIR"
    install -m644 "$SCRIPT_DIR/plugin.json" "$PLUGIN_DIR/"
    install -m644 "$SCRIPT_DIR/"*.qml "$PLUGIN_DIR/"
fi

# PATH 检查：插件按名字 dms-lyrics 经 PATH 查找二进制
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) warn "$BIN_DIR 不在 PATH 中——插件将找不到二进制。请把它加入 PATH（如在 shell 配置里 export PATH=\"$BIN_DIR:\$PATH\"）。" ;;
esac

msg "安装完成 / Done."
echo "  二进制 / binary: $BIN_DIR/$BIN_NAME"
echo "  插件   / plugin: $PLUGIN_DIR"
echo "重启 DMS（dms restart），在 设置(Mod+,) → Plugins 启用 Lyrics，并把 widget 加到 DankBar。"
