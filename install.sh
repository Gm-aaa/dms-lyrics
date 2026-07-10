#!/usr/bin/env bash
#
# DMS Lyrics 安装脚本 / installer
#
# 纯 QML 插件:把 plugin.json + *.qml + *.js 拷到 DMS 用户插件目录即可,
# 无需二进制、无需 Rust、无需 PATH 配置。
#
# 安装位置（可用环境变量覆盖）：
#   插件 → $DMS_LYRICS_PLUGIN_DIR   (默认 ~/.config/DankMaterialShell/plugins/lyrics)
#
# 用法：
#   ./install.sh
#
set -euo pipefail

PLUGIN_DIR="${DMS_LYRICS_PLUGIN_DIR:-$HOME/.config/DankMaterialShell/plugins/lyrics}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

msg()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m警告:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m错误:\033[0m %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,/^set -euo/p' "$0" | sed 's/^#\{0,1\} \{0,1\}//; /^set -euo/d'; }

for arg in "$@"; do
    case "$arg" in
        -h|--help) usage; exit 0 ;;
        *) die "未知参数：$arg（--help 查看用法）" ;;
    esac
done

# 插件文件必须来自本地克隆的仓库
[ -f "$SCRIPT_DIR/plugin.json" ] \
    || die "请在克隆的仓库根目录运行本脚本（缺少 plugin.json）"

# 插件目录若为符号链接（本机开发软链），保持不动、跳过拷贝,
# 避免顺着软链把文件写回仓库。
if [ -L "$PLUGIN_DIR" ]; then
    warn "插件目录是符号链接（开发软链），保留不动、跳过拷贝：$PLUGIN_DIR"
    warn "插件文件将直接由软链指向的源码提供。"
else
    msg "安装插件 / Installing plugin → $PLUGIN_DIR"
    mkdir -p "$PLUGIN_DIR"
    install -m644 "$SCRIPT_DIR/plugin.json" "$PLUGIN_DIR/"
    install -m644 "$SCRIPT_DIR/"*.qml "$PLUGIN_DIR/"
    install -m644 "$SCRIPT_DIR/"*.js "$PLUGIN_DIR/"
fi

msg "安装完成 / Done."
echo "  插件 / plugin: $PLUGIN_DIR"
echo "重启 DMS（dms restart），在 设置(Mod+,) → Plugins 启用 Lyrics，并把 widget 加到 DankBar。"
