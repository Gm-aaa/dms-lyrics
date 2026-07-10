// dms-lyrics 歌词抓取 / 解析(纯逻辑,与 UI 无关)。
//
// 取代原先的 Rust 后端:用异步 XMLHttpRequest 直接从网易云 / lrclib 拉取,
// 在 QML 里解析 LRC,并用内存 Map 做缓存(shell 生命周期内有效,零磁盘写入)。
//
// 对外接口:
//   fetchLyrics(source, title, artist, album, duration, onResult)
//       source: "netease" | "lrclib" | "netease_only" | "lrclib_only"
//       onResult(lyrics): lyrics = [{ time: <秒,Number>, text: <String> }, ...]
//                         空数组表示"查过但没有同步歌词"。
//   clearCache(): 清空缓存(切换歌词源时调用,强制重新抓取)。
//
// 所有网络请求都是异步的,绝不阻塞 UI 线程。为避免歌曲快速切换时旧请求的回调
// 覆盖新歌词,用一个自增的 generation token 作废过期请求的结果。

// key: "artist|title" -> lyrics 数组(含"无词"的空数组负结果)
var _cache = ({});

// 每次新的抓取自增;回调返回时若不再等于当前值,说明已切歌,丢弃结果。
var _gen = 0;

function _key(artist, title) {
    return artist + "|" + title;
}

function clearCache() {
    _cache = ({});
    _gen++; // 作废所有在途请求的回调
}

// 解析 LRC:逐行消费行首连续的 [mm:ss.xx] 标签(可多个),其余为歌词文本。
// 元信息标签(如 [ti:...] [ar:...])因分钟段解析为 NaN 被跳过,但仍会吃掉该标签。
function parseLrc(text) {
    var out = [];
    var lines = text.split(/\r?\n/);
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        var pos = 0;
        var times = [];
        while (line.charAt(pos) === "[") {
            var end = line.indexOf("]", pos);
            if (end === -1)
                break;
            var tag = line.substring(pos + 1, end); // mm:ss.xx
            var colon = tag.indexOf(":");
            if (colon !== -1) {
                var min = parseFloat(tag.substring(0, colon));
                var sec = parseFloat(tag.substring(colon + 1));
                if (!isNaN(min) && !isNaN(sec))
                    times.push(min * 60 + sec);
            }
            pos = end + 1;
        }
        if (times.length === 0)
            continue;
        var words = line.substring(pos).trim();
        for (var t = 0; t < times.length; t++)
            out.push({ time: times[t], text: words });
    }
    out.sort(function (a, b) { return a.time - b.time; });
    return out;
}

// 异步 GET + JSON 解析。onJson(obj) 成功;onFail() 失败(网络/状态码/解析)。
function _getJson(url, headers, onJson, onFail) {
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE)
            return;
        if (xhr.status >= 200 && xhr.status < 300) {
            try {
                onJson(JSON.parse(xhr.responseText));
            } catch (e) {
                onFail();
            }
        } else {
            onFail();
        }
    };
    xhr.onerror = function () { onFail(); };
    xhr.open("GET", url);
    if (headers) {
        for (var h in headers)
            xhr.setRequestHeader(h, headers[h]);
    }
    xhr.send();
}

// 网易云:先搜歌拿 id,再取歌词。ok(lrcText) / fail()。
function _fetchNetease(title, artist, ok, fail) {
    var query = encodeURIComponent((title + " " + artist).trim());
    var headers = { "Referer": "https://music.163.com", "User-Agent": "Mozilla/5.0" };
    var searchUrl = "https://music.163.com/api/search/get?type=1&limit=1&s=" + query;
    _getJson(searchUrl, headers, function (res) {
        var songs = res && res.result && res.result.songs;
        if (!songs || songs.length === 0 || songs[0].id === undefined) {
            fail();
            return;
        }
        var lyricUrl = "https://music.163.com/api/song/lyric?id=" + songs[0].id + "&lv=1&kv=1&tv=-1";
        _getJson(lyricUrl, headers, function (lres) {
            var lyric = lres && lres.lrc && lres.lrc.lyric;
            if (lyric && lyric.indexOf("[") !== -1)
                ok(lyric);
            else
                fail();
        }, fail);
    }, fail);
}

// lrclib:一次请求拿 syncedLyrics。ok(lrcText) / fail()。
function _fetchLrclib(title, artist, album, duration, ok, fail) {
    var url = "https://lrclib.net/api/get?track_name=" + encodeURIComponent(title)
            + "&artist_name=" + encodeURIComponent(artist);
    if (album)
        url += "&album_name=" + encodeURIComponent(album);
    if (duration > 0)
        url += "&duration=" + duration;
    _getJson(url, { "User-Agent": "dms-lyrics (https://github.com/Gm-aaa/dms-lyrics)" }, function (res) {
        var synced = res && res.syncedLyrics;
        if (synced)
            ok(synced);
        else
            fail();
    }, fail);
}

// 按优先级顺序依次尝试各歌词源,任一命中(解析出带时间戳的行)即返回。
function _tryChain(order, i, ctx) {
    if (i >= order.length || ctx.gen !== _gen) {
        ctx.done([]);
        return;
    }
    var next = function () { _tryChain(order, i + 1, ctx); };
    var ok = function (lrcText) {
        var parsed = parseLrc(lrcText);
        if (parsed.length > 0)
            ctx.done(parsed);
        else
            next();
    };
    if (order[i] === "netease")
        _fetchNetease(ctx.title, ctx.artist, ok, next);
    else
        _fetchLrclib(ctx.title, ctx.artist, ctx.album, ctx.duration, ok, next);
}

function fetchLyrics(source, title, artist, album, duration, onResult) {
    var key = _key(artist, title);
    if (_cache.hasOwnProperty(key)) {
        onResult(_cache[key]);
        return;
    }
    // 无艺术家信息时命中率极低且易误配,直接判定无词(与 Rust 后端一致)。
    if (!artist) {
        _cache[key] = [];
        onResult([]);
        return;
    }

    _gen++;
    var myGen = _gen;
    var ctx = {
        title: title,
        artist: artist,
        album: album,
        duration: duration,
        gen: myGen,
        done: function (lyrics) {
            _cache[key] = lyrics;          // 负结果也缓存,避免反复空查
            if (myGen === _gen)
                onResult(lyrics);
        }
    };

    var order;
    switch (source) {
    case "lrclib":       order = ["lrclib", "netease"]; break;
    case "netease_only": order = ["netease"]; break;
    case "lrclib_only":  order = ["lrclib"]; break;
    case "netease":
    default:             order = ["netease", "lrclib"]; break;
    }
    _tryChain(order, 0, ctx);
}
