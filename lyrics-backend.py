#!/usr/bin/env python3
"""DMS 歌词插件后端 / Lyrics backend for the DankMaterialShell plugin.

依赖 / Requires: playerctl
歌词源 / Sources: 网易云音乐 (Netease) + lrclib.net

行为 / Behaviour:
- 常驻轮询当前 MPRIS 播放器, 按播放进度输出「当前这一句歌词」(纯文本一行),
  仅在内容变化时输出。无歌词/暂停/无播放器/疑似视频时输出空行(清空)。
  Continuously polls the active MPRIS player and prints the current lyric line
  (plain text) whenever it changes; prints an empty line to clear.
- QML 端用 SplitParser 逐行读取, 空行 -> 隐藏组件。

性能要点 / Performance:
- 每 tick 只调用一次 playerctl(合并 format)拿全部字段。
- 自适应轮询: 有同步歌词 0.4s, 其余慢轮询。
- artist 为空(多为浏览器视频/无元数据)时不发起任何网络请求。
- 结果(含「无歌词」)缓存到 tmpfs($XDG_RUNTIME_DIR), 不写盘, 注销即清空。

用法 / Usage:
    lyrics-backend.py [--source netease|lrclib|netease_only|lrclib_only]
"""

import json
import os
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request

# 缓存放 tmpfs(运行时目录), 避免对 U盘/btrfs 写盘; 注销即清空
CACHE_DIR = os.path.join(
    os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "dms-lyrics")
SEP = "|||"
FMT = SEP.join("{{%s}}" % k for k in (
    "status", "xesam:title", "xesam:artist", "xesam:album",
    "mpris:length", "position"))

FAST = 0.4    # 有同步歌词: 跟随进度
SLOW = 2.0    # 播放但无歌词: 只需察觉换歌
IDLE = 1.5    # 暂停/无播放器

# 歌词源优先级, 由 --source 覆盖
SOURCE = "netease"

os.makedirs(CACHE_DIR, exist_ok=True)


def get_meta():
    """一次 playerctl 调用取全部字段。非播放/无播放器返回 None。"""
    try:
        out = subprocess.run(
            ["playerctl", "metadata", "--format", FMT],
            capture_output=True, text=True, timeout=2)
    except Exception:
        return None
    if out.returncode != 0:
        return None
    parts = out.stdout.rstrip("\n").split(SEP)
    if len(parts) != 6:
        return None
    status, title, artist, album, length, pos = parts
    if status != "Playing" or not title:
        return None
    try:
        pos = int(pos) / 1_000_000
    except ValueError:
        pos = 0.0
    try:
        dur = int(length) / 1_000_000 if length else 0
    except ValueError:
        dur = 0
    return {"title": title, "artist": artist, "album": album,
            "dur": dur, "pos": pos}


def cache_path(meta):
    key = re.sub(r"[^\w]+", "_", f"{SOURCE}-{meta['artist']}-{meta['title']}")
    return os.path.join(CACHE_DIR, key[:120] + ".lrc")


def parse_lrc(text):
    out = []
    for line in text.splitlines():
        tags = re.findall(r"\[(\d+):(\d+(?:\.\d+)?)\]", line)
        words = re.sub(r"\[\d+:\d+(?:\.\d+)?\]", "", line).strip()
        for m, s in tags:
            out.append((int(m) * 60 + float(s), words))
    out.sort(key=lambda x: x[0])
    return out


def _http_json(url, headers=None, timeout=5):
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)


NE_HEADERS = {"Referer": "https://music.163.com", "User-Agent": "Mozilla/5.0"}


def from_netease(meta):
    q = f"{meta['title']} {meta['artist']}".strip()
    surl = ("https://music.163.com/api/search/get?type=1&limit=1&s="
            + urllib.parse.quote(q))
    try:
        sid = _http_json(surl, NE_HEADERS)["result"]["songs"][0]["id"]
    except Exception:
        return None
    lurl = f"https://music.163.com/api/song/lyric?id={sid}&lv=1&kv=1&tv=-1"
    try:
        lrc = _http_json(lurl, NE_HEADERS).get("lrc", {}).get("lyric", "")
    except Exception:
        return None
    return lrc if "[" in lrc else None


def from_lrclib(meta):
    params = {"track_name": meta["title"], "artist_name": meta["artist"]}
    if meta["album"]:
        params["album_name"] = meta["album"]
    if meta["dur"]:
        params["duration"] = int(meta["dur"])
    url = "https://lrclib.net/api/get?" + urllib.parse.urlencode(params)
    try:
        j = _http_json(url, {"User-Agent": "dms-lyrics"})
    except Exception:
        return None
    return j.get("syncedLyrics")


def providers():
    """按设置返回要依次尝试的歌词源。"""
    return {
        "netease": (from_netease, from_lrclib),
        "lrclib": (from_lrclib, from_netease),
        "netease_only": (from_netease,),
        "lrclib_only": (from_lrclib,),
    }.get(SOURCE, (from_netease, from_lrclib))


def fetch_synced(meta):
    """返回排序后的同步歌词 [(秒, 词)]，无则 []。带 tmpfs 缓存。"""
    # 无 artist 多为视频/无元数据: 不联网、不缓存, 直接判定无歌词
    if not meta["artist"]:
        return []

    cp = cache_path(meta)
    if os.path.exists(cp):
        with open(cp, encoding="utf-8") as f:
            data = f.read()
        return [] if data == "__NONE__" else parse_lrc(data)

    lrc = None
    for fn in providers():
        lrc = fn(meta)
        if lrc:
            break
    with open(cp, "w", encoding="utf-8") as f:
        f.write(lrc if lrc else "__NONE__")
    return parse_lrc(lrc) if lrc else []


def current_index(synced, pos):
    idx = -1
    for i, (t, _) in enumerate(synced):
        if t <= pos + 0.2:
            idx = i
        else:
            break
    return idx


def emit(text, _last=[None]):
    if text != _last[0]:
        print(text, flush=True)
        _last[0] = text


def main():
    last_key = None
    synced = []
    while True:
        meta = get_meta()
        if not meta:
            emit("")
            last_key = None
            time.sleep(IDLE)
            continue

        key = f"{meta['artist']}|{meta['title']}"
        if key != last_key:
            synced = fetch_synced(meta)
            last_key = key

        if synced:
            i = current_index(synced, meta["pos"])
            emit(synced[i][1] if i >= 0 else "")
            time.sleep(FAST)
        else:
            emit("")
            time.sleep(SLOW)


def parse_args(argv):
    global SOURCE
    if "--source" in argv:
        i = argv.index("--source")
        if i + 1 < len(argv):
            SOURCE = argv[i + 1]


if __name__ == "__main__":
    parse_args(sys.argv[1:])
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
