// cyberdream — SDDM greeter styled after config/hypr/hyprlock.conf:
// bokeh backdrop, big mauve clock, sky date, avatar ring, pill input.
// Plain QtQuick only (no QtQuick.Controls) so the greeter needs no extra
// QML modules. Palette hexes come from rice/palette.json.
//
// Preview without rebooting:
//   sddm-greeter-qt6 --test-mode --theme nixos/modules/sddm-theme/cyberdream

import QtQuick

Item {
    id: root
    width: Screen.width
    height: Screen.height

    // palette (rice/palette.json)
    readonly property color crust: "#0d0d16"
    readonly property color mauve: "#cba6f7"
    readonly property color mauveHalf: "#80cba6f7"
    readonly property color inputInner: "#c01e1e2e"
    readonly property color sky: "#89dceb"
    readonly property color text: "#cdd6f4"
    readonly property color red: "#f38ba8"
    readonly property color overlay0: "#6c7086"
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    // first user (uid >= MinimumUid) as fallback when there is no lastUser
    property string firstUser: ""
    Repeater {
        model: userModel
        delegate: Item { Component.onCompleted: if (index === 0) root.firstUser = model.name }
    }
    readonly property string loginUser: userModel.lastUser !== "" ? userModel.lastUser : firstUser

    Rectangle { anchors.fill: parent; color: crust }
    Image {
        anchors.fill: parent
        source: "background.png"
        fillMode: Image.PreserveAspectCrop
    }

    // big clock
    Text {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -260
        font { family: fontFamily; pixelSize: 118; weight: 800 }
        color: mauve
        style: Text.Outline
        styleColor: "#40cba6f7"
        text: Qt.formatTime(new Date(), "hh:mm")
        Timer {
            interval: 1000; running: true; repeat: true
            onTriggered: clock.text = Qt.formatTime(new Date(), "hh:mm")
        }
    }

    // date line
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -170
        font { family: fontFamily; pixelSize: 17 }
        color: sky
        text: Qt.formatDate(new Date(), "ddd · dd MMM yyyy").toLowerCase()
    }

    // avatar ring (no ~/.face on these hosts — ring + initial instead)
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -20
        width: 84; height: 84; radius: 42
        color: "transparent"
        border { color: mauve; width: 3 }
        Text {
            anchors.centerIn: parent
            font { family: fontFamily; pixelSize: 34; weight: 800 }
            color: mauve
            text: loginUser.charAt(0).toUpperCase()
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 60
        font { family: fontFamily; pixelSize: 14 }
        color: text
        text: loginUser
    }

    // pill password field
    Rectangle {
        id: inputPill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 130
        width: 320; height: 56; radius: 28
        color: inputInner
        border { color: password.failed ? red : mauveHalf; width: 2 }

        TextInput {
            id: password
            property bool failed: false
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            font { family: fontFamily; pixelSize: 15; letterSpacing: 3 }
            color: root.text
            echoMode: TextInput.Password
            passwordCharacter: "•"
            focus: true
            onTextChanged: failed = false
            onAccepted: if (text !== "") sddm.login(loginUser, text, sessionModel.lastIndex)
        }

        Text {
            anchors.centerIn: parent
            visible: password.text === ""
            font { family: fontFamily; pixelSize: 15 }
            color: overlay0
            text: "   enter password"
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 175
        visible: keyboard.capsLock
        font { family: fontFamily; pixelSize: 12 }
        color: red
        text: "caps lock is on"
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            password.failed = true
            password.text = ""
        }
    }
}
