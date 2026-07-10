#!/usr/bin/env bash
#
# DMS Lyrics 卸载脚本 / uninstaller
#
# 移除已安装的纯 QML 插件目录。
# 默认顺带清理旧 Rust 版残留的运行缓存；加 --purge 强制清理(即使已不存在也无妨)。
#
# 位置（与 install.sh 相同，可用环境变量覆盖）：
#   插件 → $DMS_LYRICS_PLUGIN_DIR   (默认 ~/.config/DankMaterialShell/plugins/lyrics)
#
# 用法：
#   ./uninstall.sh            # 移除插件
#   ./uninstall.sh --purge    # 另外删除旧版运行缓存 ($XDG_RUNTIME_DIR/dms-lyrics)
#
set -euo pipefail

PLUGIN_DIR="${DMS_LYRICS_PLUGIN_DIR:-$HOME/.config/DankMaterialShell/plugins/lyrics}"

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

# 插件目录：符号链接（开发软链）保持不动、跳过删除；真实目录才移除。
if [ -L "$PLUGIN_DIR" ]; then
    warn "插件目录是符号链接（开发软链），保留不动、跳过删除：$PLUGIN_DIR"
elif [ -d "$PLUGIN_DIR" ]; then
    msg "移除插件 / Removing plugin $PLUGIN_DIR"
    rm -rf "$PLUGIN_DIR"
else
    warn "未发现插件目录 $PLUGIN_DIR"
fi

# 旧 Rust 版把 .lrc 缓存写在 $XDG_RUNTIME_DIR/dms-lyrics;纯 QML 版已不再落盘,
# 这里顺手清掉可能的历史残留(--purge 时无论存在与否都尝试)。
CACHE_DIR="${XDG_RUNTIME_DIR:-/tmp}/dms-lyrics"
if [ "$PURGE" -eq 1 ] || [ -e "$CACHE_DIR" ]; then
    if [ -e "$CACHE_DIR" ]; then
        msg "清除旧版运行缓存 / Purging legacy cache $CACHE_DIR"
        rm -rf "$CACHE_DIR"
    fi
fi

msg "卸载完成 / Done."
echo "记得在 DankMaterialShell 中停用/移除 Lyrics 插件。"
