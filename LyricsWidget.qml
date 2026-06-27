import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string scriptPath: PluginService.pluginDirectory + "/lyrics/lyrics-backend"
    property string currentLine: ""
    property int currentIndex: -1
    property string currentSongTitle: ""
    property string currentSongArtist: ""

    // settings, read reactively to solve reactivity bug
    readonly property string settingsJson: JSON.stringify(SettingsData.pluginSettings[pluginId] ?? {})
    readonly property var pd: JSON.parse(settingsJson)
    readonly property string lyricsSource: pd.lyricsSource ?? "netease"
    readonly property int maxWidth: pd.maxWidth ?? 280

    // Set popout dimensions
    popoutWidth: 320
    popoutHeight: 400

    // Hide component when no lyrics are playing
    _visibilityOverride: true
    _visibilityOverrideValue: currentLine !== ""

    ListModel {
        id: lyricsModel
    }

    // Backend process
    Process {
        id: proc
        command: [root.scriptPath, "--source", root.lyricsSource]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line === "") return;
                try {
                    var msg = JSON.parse(line);
                    if (msg.type === "song") {
                        lyricsModel.clear();
                        for (var i = 0; i < msg.lyrics.length; i++) {
                            lyricsModel.append({
                                time: msg.lyrics[i].time,
                                text: msg.lyrics[i].text
                            });
                        }
                        root.currentSongTitle = msg.title;
                        root.currentSongArtist = msg.artist;
                        root.currentIndex = -1;
                    } else if (msg.type === "index") {
                        root.currentIndex = msg.index;
                        if (msg.index >= 0 && msg.index < lyricsModel.count) {
                            root.currentLine = lyricsModel.get(msg.index).text;
                        } else {
                            root.currentLine = "";
                        }
                    } else if (msg.type === "clear") {
                        lyricsModel.clear();
                        root.currentLine = "";
                        root.currentIndex = -1;
                        root.currentSongTitle = "";
                        root.currentSongArtist = "";
                    }
                } catch (e) {
                    console.log("[Lyrics Backend Error] " + e + " for line: " + line);
                }
            }
        }
    }

    Component.onCompleted: proc.running = true

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

    // Auto-restart if process unexpectedly dies
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

            Item {
                id: marqueeContainer
                width: Math.min(lyricText.implicitWidth, root.maxWidth)
                height: lyricText.implicitHeight
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                StyledText {
                    id: lyricText
                    text: root.currentLine
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : undefined)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.NoWrap

                    SequentialAnimation on x {
                        id: scrollAnim
                        running: lyricText.implicitWidth > marqueeContainer.width
                        loops: Animation.Infinite

                        PauseAnimation { duration: 2000 }

                        NumberAnimation {
                            from: 0
                            to: -(lyricText.implicitWidth - marqueeContainer.width)
                            duration: Math.max(1000, (lyricText.implicitWidth - marqueeContainer.width) * 30)
                            easing.type: Easing.Linear
                        }

                        PauseAnimation { duration: 2000 }

                        NumberAnimation {
                            from: -(lyricText.implicitWidth - marqueeContainer.width)
                            to: 0
                            duration: Math.max(1000, (lyricText.implicitWidth - marqueeContainer.width) * 30)
                            easing.type: Easing.Linear
                        }
                    }

                    onTextChanged: {
                        x = 0;
                        if (lyricText.implicitWidth > marqueeContainer.width) {
                            scrollAnim.restart();
                        } else {
                            scrollAnim.stop();
                        }
                    }
                }
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

    // Popout content containing the Apple Music style scrolling lyrics
    popoutContent: Component {
        PopoutComponent {
            id: popoutRoot
            headerText: root.currentSongTitle !== "" ? root.currentSongTitle : "歌词 / Lyrics"
            showCloseButton: true

            Item {
                width: parent.width
                height: 340

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS

                StyledText {
                    text: root.currentSongArtist
                    font.pixelSize: Theme.fontSizeSmall
                    font.italic: true
                    color: Theme.surfaceVariantText
                    Layout.fillWidth: true
                    visible: root.currentSongArtist !== ""
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    color: Theme.surfaceVariant
                    height: 1
                    Layout.fillWidth: true
                    visible: root.currentSongArtist !== ""
                }

                StyledText {
                    text: "当前无歌词播放\nNo lyrics playing"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    verticalAlignment: Text.AlignVCenter
                    visible: lyricsModel.count === 0
                }

                ListView {
                    id: lyricsListView
                    model: lyricsModel
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    visible: lyricsModel.count > 0

                    currentIndex: root.currentIndex
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: height / 2 - 20
                    preferredHighlightEnd: height / 2 + 20

                    delegate: Item {
                        width: lyricsListView.width
                        height: lyricText.implicitHeight + 16

                        readonly property bool isActive: index === root.currentIndex

                        StyledText {
                            id: lyricText
                            text: model.text
                            width: parent.width
                            font.pixelSize: isActive ? Theme.fontSizeMedium + 2 : Theme.fontSizeMedium
                            font.weight: isActive ? Font.Bold : Font.Normal
                            color: isActive ? Theme.primary : Theme.surfaceText
                            opacity: isActive ? 1.0 : 0.4
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap

                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Behavior on font.pixelSize { NumberAnimation { duration: 200 } }
                        }
                    }
                }
            }
        }
        }
    }
}
