import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "lyrics"

    StyledText {
        text: "歌词 / Lyrics"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "在状态栏显示当前播放歌曲的同步歌词。\nShow synced lyrics of the currently playing song in the bar."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    SelectionSetting {
        settingKey: "lyricsSource"
        label: "歌词源优先级 / Lyrics source"
        description: "选择优先使用的歌词接口。中文歌建议网易云优先。\nWhich provider to try first. Netease is best for Chinese songs."
        defaultValue: "netease"
        options: [
            { label: "网易云优先 / Netease first", value: "netease" },
            { label: "lrclib 优先 / lrclib first", value: "lrclib" },
            { label: "仅网易云 / Netease only", value: "netease_only" },
            { label: "仅 lrclib / lrclib only", value: "lrclib_only" }
        ]
    }

    SliderSetting {
        settingKey: "maxWidth"
        label: "组件最大宽度 / Max width (px)"
        description: "歌词文字的最大宽度，超出会省略。\nMaximum width of the lyric text; longer lines are elided."
        minimum: 80
        maximum: 600
        defaultValue: 280
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        width: parent.width
        text: "依赖 / Requires: playerctl, python3。仅显示有同步歌词的曲目；视频/纯音乐会自动隐藏。\nNeeds playerctl & python3. Only songs with synced lyrics are shown; videos/instrumentals are hidden."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }
}
