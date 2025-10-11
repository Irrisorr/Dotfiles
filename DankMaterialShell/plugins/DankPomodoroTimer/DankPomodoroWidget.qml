import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property int workDuration: pluginData.workDuration || 25
    property int shortBreakDuration: pluginData.shortBreakDuration || 5
    property int longBreakDuration: pluginData.longBreakDuration || 15
    property bool autoStartBreaks: pluginData.autoStartBreaks ?? false
    property bool autoStartPomodoros: pluginData.autoStartPomodoros ?? false

    property int remainingSeconds: 0
    property int totalSeconds: workDuration * 60
    property bool isRunning: false
    property string timerState: "work"
    property int completedPomodoros: 0

    Timer {
        id: pomodoroTimer
        interval: 1000
        repeat: true
        running: root.isRunning
        onTriggered: {
            if (root.remainingSeconds > 0) {
                root.remainingSeconds--
            } else {
                root.timerComplete()
            }
        }
    }

    function timerComplete() {
        root.isRunning = false

        if (root.timerState === "work") {
            root.completedPomodoros++
            const isLongBreak = root.completedPomodoros % 4 === 0

            Quickshell.execDetached(["sh", "-c", "notify-send 'Pomodoro Complete' 'Time for a " + (isLongBreak ? "long" : "short") + " break!' -u normal"])

            if (isLongBreak) {
                root.startLongBreak(root.autoStartBreaks)
            } else {
                root.startShortBreak(root.autoStartBreaks)
            }
        } else {
            Quickshell.execDetached(["sh", "-c", "notify-send 'Break Complete' 'Ready for another pomodoro?' -u normal"])
            root.startWork(root.autoStartPomodoros)
        }
    }

    function startWork(autoStart) {
        root.timerState = "work"
        root.totalSeconds = root.workDuration * 60
        root.remainingSeconds = root.totalSeconds
        root.isRunning = autoStart ?? false
    }

    function startShortBreak(autoStart) {
        root.timerState = "shortBreak"
        root.totalSeconds = root.shortBreakDuration * 60
        root.remainingSeconds = root.totalSeconds
        root.isRunning = autoStart ?? false
    }

    function startLongBreak(autoStart) {
        root.timerState = "longBreak"
        root.totalSeconds = root.longBreakDuration * 60
        root.remainingSeconds = root.totalSeconds
        root.isRunning = autoStart ?? false
    }

    function toggleTimer() {
        root.isRunning = !root.isRunning
    }

    function resetTimer() {
        root.isRunning = false
        root.remainingSeconds = root.totalSeconds
    }

    function formatTime(seconds) {
        const mins = Math.floor(seconds / 60)
        const secs = seconds % 60
        return mins + "\n" + (secs < 10 ? "0" : "") + secs
    }

    function getStateColor() {
        if (root.timerState === "work") return Theme.primary
        if (root.timerState === "shortBreak") return Theme.success
        return Theme.warning
    }

    function getStateIcon() {
        if (root.timerState === "work") return "work"
        return "coffee"
    }

    Component.onCompleted: {
        startWork(false)
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: root.getStateIcon()
                size: Theme.iconSize - 6
                color: root.getStateColor()
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.formatTime(root.remainingSeconds)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: root.getStateColor()
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: root.getStateIcon()
                size: Theme.iconSize - 6
                color: root.getStateColor()
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.formatTime(root.remainingSeconds)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: root.getStateColor()
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "Pomodoro Timer"
            detailsText: {
                if (root.timerState === "work") return "Focus session • " + root.completedPomodoros + " completed"
                if (root.timerState === "shortBreak") return "Short break"
                return "Long break"
            }
            showCloseButton: true

            Column {
                id: popoutContentColumn
                width: parent.width
                spacing: Theme.spacingM

                Item {
                    width: parent.width
                    height: 180

                    Rectangle {
                        width: 180
                        height: 180
                        radius: 90
                        anchors.centerIn: parent
                        color: "transparent"
                        border.width: 8
                        border.color: Qt.rgba(root.getStateColor().r, root.getStateColor().g, root.getStateColor().b, 0.2)

                        Canvas {
                            id: progressCanvas
                            width: parent.width - 16
                            height: parent.height - 16
                            anchors.centerIn: parent

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.lineWidth = 8
                                ctx.strokeStyle = root.getStateColor()
                                ctx.beginPath()
                                const centerX = width / 2
                                const centerY = height / 2
                                const radius = (width - 8) / 2
                                const progress = root.remainingSeconds / root.totalSeconds
                                const startAngle = -Math.PI / 2
                                const endAngle = startAngle + (2 * Math.PI * progress)
                                ctx.arc(centerX, centerY, radius, startAngle, endAngle, false)
                                ctx.stroke()
                            }

                            Connections {
                                target: root
                                function onRemainingSecondsChanged() {
                                    progressCanvas.requestPaint()
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            StyledText {
                                text: root.formatTime(root.remainingSeconds)
                                font.pixelSize: 36
                                font.weight: Font.Bold
                                color: root.getStateColor()
                                anchors.horizontalCenter: parent.horizontalCenter
                                horizontalAlignment: Text.AlignHCenter
                                width: 120
                            }

                            StyledText {
                                text: {
                                    if (root.timerState === "work") return "Work"
                                    if (root.timerState === "shortBreak") return "Short Break"
                                    return "Long Break"
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingM

                    Rectangle {
                        width: 64
                        height: 64
                        radius: 32
                        color: playArea.containsMouse ? Qt.rgba(root.getStateColor().r, root.getStateColor().g, root.getStateColor().b, 0.2) : "transparent"

                        DankIcon {
                            anchors.centerIn: parent
                            name: root.isRunning ? "pause" : "play_arrow"
                            size: 32
                            color: root.getStateColor()
                        }

                        MouseArea {
                            id: playArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleTimer()
                        }
                    }

                    Rectangle {
                        width: 64
                        height: 64
                        radius: 32
                        color: resetArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                        DankIcon {
                            anchors.centerIn: parent
                            name: "refresh"
                            size: 24
                            color: Theme.surfaceText
                        }

                        MouseArea {
                            id: resetArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetTimer()
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: "Quick Actions"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        DankButton {
                            text: "Work"
                            iconName: "work"
                            onClicked: root.startWork(false)
                        }

                        DankButton {
                            text: "Short Break"
                            iconName: "coffee"
                            onClicked: root.startShortBreak(false)
                        }

                        DankButton {
                            text: "Long Break"
                            iconName: "weekend"
                            onClicked: root.startLongBreak(false)
                        }
                    }
                }

                StyledRect {
                    width: parent.width
                    height: statsColumn.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Column {
                        id: statsColumn
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingXS

                        Row {
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "check_circle"
                                size: Theme.iconSize
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: root.completedPomodoros + " pomodoros completed"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        StyledText {
                            text: "Next long break after " + (4 - (root.completedPomodoros % 4)) + " more"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            leftPadding: Theme.iconSize + Theme.spacingM
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 400
}
