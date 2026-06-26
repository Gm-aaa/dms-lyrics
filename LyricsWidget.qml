import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string pluginId: "lyrics"
    property string scriptPath: PluginService.pluginDirectory + "/lyrics/lyrics-backend.py"
    property string currentLine: ""

    // 设置项 (响应式读取) / settings, read reactively
    readonly property string settingsJson: JSON.stringify(SettingsData.pluginSettings[pluginId] ?? {})
    readonly property var pd: SettingsData.getPluginSettingsForPlugin(pluginId)
    readonly property string lyricsSource: pd.lyricsSource ?? "netease"
    readonly property int maxWidth: pd.maxWidth ?? 280

    // 无歌词时让整个组件宽度收成 0(由 BasePill 处理), 不留空框
    _visibilityOverride: true
    _visibilityOverrideValue: currentLine !== ""

    // 后端进程: 常驻输出当前歌词行
    Process {
        id: proc
        command: ["python3", root.scriptPath, "--source", root.lyricsSource]
        running: false
        stdout: SplitParser {
            onRead: data => root.currentLine = data
        }
    }

    Component.onCompleted: proc.running = true

    // 切换歌词源时重启后端以应用新优先级
    onLyricsSourceChanged: restart()
    Connections {
        target: root.pluginService
        enabled: root.pluginService !== null
        function onPluginDataChanged(changedId) {
            if (changedId === root.pluginId)
                root.restart()
        }
    }
    function restart() {
        proc.running = false
        restartTimer.restart()
    }
    Timer {
        id: restartTimer
        interval: 250
        onTriggered: proc.running = true
    }

    // 进程意外退出时自动拉起
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: if (!proc.running) proc.running = true
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: "lyrics"
                size: 16
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.currentLine
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                color: Theme.widgetTextColor
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: Math.min(implicitWidth, root.maxWidth)
            }
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: "lyrics"
            size: 16
            color: root.currentLine !== "" ? Theme.primary : Theme.widgetTextColor
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
