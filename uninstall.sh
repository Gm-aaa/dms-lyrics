#!/usr/bin/env bash
#
# DMS Lyrics 卸载脚本 / uninstaller
#
# 移除已安装的二进制与插件，并尽力停掉仍在运行的后端进程。
# 默认保留运行缓存；加 --purge 一并删除。
#
# 位置（与 install.sh 相同，可用环境变量覆盖）：
#   二进制 → $DMS_LYRICS_BIN_DIR      (默认 ~/.local/bin)
#   插件   → $DMS_LYRICS_PLUGIN_DIR   (默认 ~/.config/DankMaterialShell/plugins/lyrics)
#
# 用法：
#   ./uninstall.sh            # 移除二进制 + 插件
#   ./uninstall.sh --purge    # 另外删除运行缓存 ($XDG_RUNTIME_DIR/dms-lyrics)
#
set -euo pipefail

BIN_DIR="${DMS_LYRICS_BIN_DIR:-$HOME/.local/bin}"
PLUGIN_DIR="${DMS_LYRICS_PLUGIN_DIR:-$HOME/.config/DankMaterialShell/plugins/lyrics}"
BIN_NAME="dms-lyrics"

msg()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m警告:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m错误:\033[0m %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,/^set -euo/p' "$0" | sed 's/^#\{0,1\} \{0,1\}//; /^set -euo/d'; }

PURGE=0
for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "未知参数：$arg（--help 查看用法）" ;;
    esac
done

# 尽力停掉仍在运行的后端（插件被禁用时 DMS 也会终止它；这里作双保险）。
# 用 -x 精确匹配进程名，避免误杀本脚本或其它含 dms-lyrics 的命令行。
if pkill -x "$BIN_NAME" 2>/dev/null; then
    msg "已停止运行中的后端 / Stopped running backend"
fi

if [ -e "$BIN_DIR/$BIN_NAME" ]; then
    msg "移除二进制 / Removing binary $BIN_DIR/$BIN_NAME"
    rm -f "$BIN_DIR/$BIN_NAME"
else
    warn "未发现二进制 $BIN_DIR/$BIN_NAME（可能已删除或安装到别处）"
fi

# 插件目录：符号链接（开发软链）保持不动、跳过删除；真实目录才移除。
if [ -L "$PLUGIN_DIR" ]; then
    warn "插件目录是符号链接（开发软链），保留不动、跳过删除：$PLUGIN_DIR"
elif [ -d "$PLUGIN_DIR" ]; then
    msg "移除插件 / Removing plugin $PLUGIN_DIR"
    rm -rf "$PLUGIN_DIR"
else
    warn "未发现插件目录 $PLUGIN_DIR"
fi

if [ "$PURGE" -eq 1 ]; then
    CACHE_DIR="${XDG_RUNTIME_DIR:-/tmp}/dms-lyrics"
    if [ -e "$CACHE_DIR" ]; then
        msg "清除运行缓存（--purge）/ Purging cache $CACHE_DIR"
        rm -rf "$CACHE_DIR"
    fi
fi

msg "卸载完成 / Done."
echo "记得在 DankMaterialShell 中停用/移除 Lyrics 插件。"
echo "提示：源码编译产物仍在 lyrics_backend/target，可用 'cargo clean' 一并清除。"
