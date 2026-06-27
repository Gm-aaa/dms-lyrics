use mpris::{PlayerFinder, PlaybackStatus};
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::thread;
use std::time::Duration;
use serde::Serialize;

#[derive(Debug)]
enum Source {
    Netease,
    Lrclib,
    NeteaseOnly,
    LrclibOnly,
}

struct TrackMeta {
    title: String,
    artist: String,
    album: String,
    duration: u32,
    position: f64,
}

#[derive(Serialize, Clone)]
struct LyricLine {
    time: f64,
    text: String,
}

#[derive(Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum BackendMessage {
    Song {
        title: String,
        artist: String,
        lyrics: Vec<LyricLine>,
    },
    Index {
        index: i32,
        progress: f64,
    },
    Clear,
}

fn parse_source_arg() -> Source {
    let args: Vec<String> = std::env::args().collect();
    let mut source = Source::Netease;
    if let Some(i) = args.iter().position(|r| r == "--source") {
        if i + 1 < args.len() {
            source = match args[i + 1].as_str() {
                "netease" => Source::Netease,
                "lrclib" => Source::Lrclib,
                "netease_only" => Source::NeteaseOnly,
                "lrclib_only" => Source::LrclibOnly,
                _ => Source::Netease,
            };
        }
    }
    source
}

fn get_meta(finder: &PlayerFinder) -> Option<TrackMeta> {
    let player = finder.find_active().ok()?;
    let playback_status = player.get_playback_status().ok()?;
    if playback_status != PlaybackStatus::Playing {
        return None;
    }
    let metadata = player.get_metadata().ok()?;
    let title = metadata.title()?.to_string();
    let artist = metadata.artists()
        .map(|v| v.join(", "))
        .unwrap_or_default();
    let album = metadata.album_name().unwrap_or("").to_string();
    let duration = metadata.length().map(|d| d.as_secs() as u32).unwrap_or(0);
    let position = player.get_position().ok().map(|d| d.as_secs_f64()).unwrap_or(0.0);

    Some(TrackMeta {
        title,
        artist,
        album,
        duration,
        position,
    })
}

fn parse_lrc(text: &str) -> Vec<(f64, String)> {
    let mut out = Vec::new();
    for line in text.lines() {
        let mut content_start = 0;
        let mut timestamps = Vec::new();
        
        while let Some('[') = line[content_start..].chars().next() {
            let remaining = &line[content_start..];
            if let Some(end_idx) = remaining.find(']') {
                let tag = &remaining[1..end_idx]; // mm:ss.xx
                if let Some(colon_idx) = tag.find(':') {
                    let min_str = &tag[..colon_idx];
                    let sec_str = &tag[colon_idx + 1..];
                    if let (Ok(min), Ok(sec)) = (min_str.parse::<f64>(), sec_str.parse::<f64>()) {
                        timestamps.push(min * 60.0 + sec);
                    }
                }
                content_start += end_idx + 1;
            } else {
                break;
            }
        }
        
        let words = line[content_start..].trim().to_string();
        for t in timestamps {
            out.push((t, words.clone()));
        }
    }
    out.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap_or(std::cmp::Ordering::Equal));
    out
}

fn from_netease(title: &str, artist: &str) -> Option<String> {
    let query = format!("{} {}", title, artist).trim().to_string();
    let agent = ureq::agent();

    // 1. Search song
    let search_res: serde_json::Value = agent.get("https://music.163.com/api/search/get")
        .set("Referer", "https://music.163.com")
        .set("User-Agent", "Mozilla/5.0")
        .query("type", "1")
        .query("limit", "1")
        .query("s", &query)
        .call().ok()?
        .into_json().ok()?;

    let song_id = search_res.get("result")?
        .get("songs")?
        .get(0)?
        .get("id")?
        .as_i64()?;

    // 2. Fetch lyrics
    let lyric_res: serde_json::Value = agent.get("https://music.163.com/api/song/lyric")
        .set("Referer", "https://music.163.com")
        .set("User-Agent", "Mozilla/5.0")
        .query("id", &song_id.to_string())
        .query("lv", "1")
        .query("kv", "1")
        .query("tv", "-1")
        .call().ok()?
        .into_json().ok()?;

    let lyric = lyric_res.get("lrc")?
        .get("lyric")?
        .as_str()?;

    if lyric.contains('[') {
        Some(lyric.to_string())
    } else {
        None
    }
}

fn from_lrclib(title: &str, artist: &str, album: &str, duration: u32) -> Option<String> {
    let agent = ureq::agent();
    let mut request = agent.get("https://lrclib.net/api/get")
        .set("User-Agent", "dms-lyrics")
        .query("track_name", title)
        .query("artist_name", artist);

    if !album.is_empty() {
        request = request.query("album_name", album);
    }
    if duration > 0 {
        request = request.query("duration", &duration.to_string());
    }

    let res: serde_json::Value = request.call().ok()?.into_json().ok()?;
    let synced_lyrics = res.get("syncedLyrics")?.as_str()?;
    Some(synced_lyrics.to_string())
}

fn fetch_synced(
    source: &Source,
    title: &str,
    artist: &str,
    album: &str,
    duration: u32,
    cache_dir: &Path,
) -> Vec<(f64, String)> {
    if artist.is_empty() {
        return Vec::new();
    }

    let sanitized_artist = artist.replace(|c: char| !c.is_alphanumeric(), "_");
    let sanitized_title = title.replace(|c: char| !c.is_alphanumeric(), "_");
    let source_str = match source {
        Source::Netease | Source::NeteaseOnly => "netease",
        Source::Lrclib | Source::LrclibOnly => "lrclib",
    };
    let cache_filename = format!("{}-{}-{}.lrc", source_str, sanitized_artist, sanitized_title);
    let cache_filename = if cache_filename.len() > 120 {
        format!("{}.lrc", &cache_filename[..116])
    } else {
        cache_filename
    };
    let cache_path = cache_dir.join(cache_filename);

    if cache_path.exists() {
        if let Ok(data) = std::fs::read_to_string(&cache_path) {
            if data == "__NONE__" {
                return Vec::new();
            } else {
                return parse_lrc(&data);
            }
        }
    }

    let mut lrc = None;
    match source {
        Source::Netease => {
            lrc = from_netease(title, artist);
            if lrc.is_none() {
                lrc = from_lrclib(title, artist, album, duration);
            }
        }
        Source::Lrclib => {
            lrc = from_lrclib(title, artist, album, duration);
            if lrc.is_none() {
                lrc = from_netease(title, artist);
            }
        }
        Source::NeteaseOnly => {
            lrc = from_netease(title, artist);
        }
        Source::LrclibOnly => {
            lrc = from_lrclib(title, artist, album, duration);
        }
    }

    let cache_content = lrc.as_deref().unwrap_or("__NONE__");
    let _ = std::fs::write(&cache_path, cache_content);

    if let Some(ref lrc_text) = lrc {
        parse_lrc(lrc_text)
    } else {
        Vec::new()
    }
}

fn current_index_lyrics(synced: &[LyricLine], pos: f64) -> i32 {
    let mut idx = -1;
    for (i, line) in synced.iter().enumerate() {
        if line.time <= pos + 0.2 {
            idx = i as i32;
        } else {
            break;
        }
    }
    idx
}

fn emit_msg(msg: &BackendMessage) {
    if let Ok(json_str) = serde_json::to_string(msg) {
        println!("{}", json_str);
        let _ = io::stdout().flush();
    }
}

fn main() {
    let source = parse_source_arg();
    let cache_dir = match std::env::var("XDG_RUNTIME_DIR") {
        Ok(dir) => PathBuf::from(dir).join("dms-lyrics"),
        Err(_) => PathBuf::from("/tmp").join("dms-lyrics"),
    };
    let _ = std::fs::create_dir_all(&cache_dir);

    let finder = match PlayerFinder::new() {
        Ok(f) => f,
        Err(e) => {
            eprintln!("Failed to connect to D-Bus: {:?}", e);
            std::process::exit(1);
        }
    };

    let mut last_key = None;
    let mut synced: Vec<LyricLine> = Vec::new();

    loop {
        let meta = get_meta(&finder);
        if meta.is_none() {
            if last_key.is_some() {
                emit_msg(&BackendMessage::Clear);
                last_key = None;
                synced.clear();
            }
            thread::sleep(Duration::from_millis(1500)); // IDLE
            continue;
        }

        let m = meta.unwrap();
        let key = format!("{}|{}", m.artist, m.title);
        if Some(&key) != last_key.as_ref() {
            let raw_synced = fetch_synced(&source, &m.title, &m.artist, &m.album, m.duration, &cache_dir);
            synced = raw_synced.into_iter()
                .map(|(time, text)| LyricLine { time, text })
                .collect();
            
            if !synced.is_empty() {
                emit_msg(&BackendMessage::Song {
                    title: m.title.clone(),
                    artist: m.artist.clone(),
                    lyrics: synced.clone(),
                });
            } else {
                emit_msg(&BackendMessage::Clear);
            }
            last_key = Some(key);
        }

        if !synced.is_empty() {
            let i = current_index_lyrics(&synced, m.position);
            if i >= 0 {
                let current_time = synced[i as usize].time;
                let next_time = if (i as usize) + 1 < synced.len() {
                    synced[(i as usize) + 1].time
                } else if m.duration > 0 {
                    m.duration as f64
                } else {
                    current_time + 8.0
                };
                
                let duration = next_time - current_time;
                let progress = if duration > 0.0 {
                    ((m.position - current_time) / duration).clamp(0.0, 1.0)
                } else {
                    0.0
                };
                
                emit_msg(&BackendMessage::Index {
                    index: i,
                    progress,
                });
            } else {
                emit_msg(&BackendMessage::Index {
                    index: -1,
                    progress: 0.0,
                });
            }
            thread::sleep(Duration::from_millis(400)); // FAST
        } else {
            thread::sleep(Duration::from_millis(2000)); // SLOW
        }
    }
}
