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
    property real currentProgress: 0.0
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

    // Animation to drive currentProgress smoothly locally to eliminate D-Bus position stuttering
    NumberAnimation {
        id: progressAnim
        target: root
        property: "currentProgress"
        easing.type: Easing.Linear
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
                        root.currentProgress = 0.0;
                        progressAnim.running = false;
                    } else if (msg.type === "sync") {
                        var changed = (root.currentIndex !== msg.index);
                        if (changed) {
                            root.currentIndex = msg.index;
                            if (msg.index >= 0 && msg.index < lyricsModel.count) {
                                root.currentLine = lyricsModel.get(msg.index).text;
                            } else {
                                root.currentLine = "";
                            }
                        }

                        // Calculate progress at the queried position
                        var progress = 0.0;
                        if (msg.index >= 0 && msg.index < lyricsModel.count) {
                            var lineStartTime = lyricsModel.get(msg.index).time;
                            if (msg.duration > 0) {
                                progress = Math.max(0.0, Math.min(1.0, (msg.position - lineStartTime) / msg.duration));
                            }
                        }

                        // Sync progress animation
                        progressAnim.running = false;
                        root.currentProgress = progress;
                        
                        if (msg.playing && msg.index >= 0 && progress < 1.0) {
                            progressAnim.from = progress;
                            progressAnim.to = 1.0;
                            progressAnim.duration = (msg.duration * (1.0 - progress)) * 1000;
                            progressAnim.running = true;
                        }
                    } else if (msg.type === "clear") {
                        lyricsModel.clear();
                        root.currentLine = "";
                        root.currentIndex = -1;
                        root.currentProgress = 0.0;
                        root.currentSongTitle = "";
                        root.currentSongArtist = "";
                        progressAnim.running = false;
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
                    text: ""
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : undefined)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.NoWrap

                    readonly property real maxScroll: implicitWidth - marqueeContainer.width
                    x: maxScroll > 0 ? -root.currentProgress * maxScroll : 0

                    // Fade transition on change of text
                    opacity: 1.0
                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                    }

                    Component.onCompleted: {
                        lyricText.text = root.currentLine;
                    }

                    Connections {
                        target: root
                        function onCurrentLineChanged() {
                            fadeTransition.restart();
                        }
                    }

                    SequentialAnimation {
                        id: fadeTransition
                        NumberAnimation { target: lyricText; property: "opacity"; to: 0.0; duration: 150; easing.type: Easing.InOutQuad }
                        ScriptAction { script: lyricText.text = root.currentLine }
                        NumberAnimation { target: lyricText; property: "opacity"; to: 1.0; duration: 150; easing.type: Easing.InOutQuad }
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

                        highlightMoveDuration: 300
                        highlightMoveVelocity: -1

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

                                Behavior on color { ColorAnimation { duration: 250 } }
                                Behavior on opacity { NumberAnimation { duration: 250 } }
                                Behavior on font.pixelSize { NumberAnimation { duration: 250 } }
                            }
                        }
                    }
                }
            }
        }
    }
}
