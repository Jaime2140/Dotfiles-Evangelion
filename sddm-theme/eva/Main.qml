import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "components"

Rectangle {
    id: container
    width: 1920
    height: 1080
    color: config.backgroundColor
    focus: !loginState.visible

    // User & Session Logic (Root Level)
    property int userIndex: 0
    property int sessionIndex: 0
    property bool isLoggingIn: false

    Component.onCompleted: {
        if (typeof userModel !== "undefined" && userModel.lastIndex >= 0) userIndex = userModel.lastIndex;
        if (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) sessionIndex = sessionModel.lastIndex;
    }

    function cleanName(name) {
        if (!name) return "";
        var s = name.toString();
        if (s.endsWith("/")) s = s.substring(0, s.length - 1);
        if (s.indexOf("/") !== -1) s = s.substring(s.lastIndexOf("/") + 1);
        if (s.indexOf(".desktop") !== -1) s = s.substring(0, s.indexOf(".desktop"));
        s = s.replace(/[-_]/g, ' ');
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    function doLogin() {
        if (!loginState.visible || isLoggingIn) return;

        var user = "";
        if (typeof userModel !== "undefined" && userModel.count > 0) {
            var idx = container.userIndex;
            if (idx < 0 || idx >= userModel.count) idx = 0;

            var edit = userModel.data(userModel.index(idx, 0), Qt.EditRole);
            var nameRole = userModel.data(userModel.index(idx, 0), Qt.UserRole + 1);
            var display = userModel.data(userModel.index(idx, 0), Qt.DisplayRole);

            user = edit ? edit.toString() : (nameRole ? nameRole.toString() : (display ? display.toString() : ""));
        }

        if (!user || user === "" || user === "User") {
            user = sddm.lastUser;
        }

        if (!user && typeof userModel !== "undefined" && userModel.count > 0) {
            var firstEdit = userModel.data(userModel.index(0, 0), Qt.EditRole);
            user = firstEdit ? firstEdit.toString() : "";
        }

        if (!user) return;

        container.isLoggingIn = true;
        var pass = passwordField.text;
        var sess = container.sessionIndex;

        if (typeof sessionModel !== "undefined") {
            if (sess < 0 || sess >= sessionModel.count) sess = 0;
        } else {
            sess = 0;
        }

        console.log("Pixie SDDM: Attempting login for user [" + user + "] session index [" + sess + "]");
        sddm.login(user.trim(), pass, sess);
        loginTimeout.start();
    }

    Timer {
        id: loginTimeout
        interval: 5000
        onTriggered: container.isLoggingIn = false
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            container.isLoggingIn = false
            loginTimeout.stop()
            loginState.isError = true
            shakeAnimation.start()
            passwordField.text = ""
            passwordField.forceActiveFocus()
        }
        function onLoginSucceeded() {
            loginTimeout.stop()
        }
    }

    // Dynamic Color Configuration
    property color extractedAccent: config.accentColor
    property color baseColor: config.backgroundColor
    property color surfaceColor: Qt.lighter(baseColor, 1.3)
    property color surfaceVariantColor: Qt.lighter(baseColor, 1.6)
    property bool uiReady: config.autoColor !== "true" || colorExtractor.processed

    Timer {
        id: colorDelay
        interval: 1000 // Give it a full second
        repeat: true   // Keep trying until we succeed
        running: backgroundImage.status === Image.Ready && !colorExtractor.processed && config.autoColor === "true"
        onTriggered: colorExtractor.requestPaint()
    }

    Canvas {
        id: colorExtractor
        width: 60; height: 60
        x: -100; y: -100 // Off-screen but "visible" for reliable rendering
        z: -1
        renderTarget: Canvas.Image
        property bool processed: false
        property int retries: 0 // Add this to track GPU sync delays

        onPaint: {
            var ctx = getContext("2d");
            var res = 60;
            ctx.clearRect(0, 0, res, res);
            ctx.drawImage(backgroundImage, 0, 0, res, res);
            var imgData = ctx.getImageData(0, 0, res, res).data;

            if (!imgData || imgData.length === 0) return;

            // 36 Buckets (10 degrees each) for high resolution hue detection
            var histogram = new Array(36).fill(0);
            var sampleColors = new Array(36).fill(null);
            var vibrantFound = false;

            // FIX: Check if canvas read pure black (GPU sync delay bug)
            var pixelSum = 0;
            for (var p = 0; p < imgData.length; p++) pixelSum += imgData[p];

            if (pixelSum === 0) {
                retries++;
                if (retries > 3) {
                    // If it's still pure black after 3 tries, it's a true black wallpaper
                    container.extractedAccent = "#D0D0D0";
                    console.log("Pixie SDDM: Pure black wallpaper detected. Using neutral contrast.");
                    processed = true;
                }
                return; // Keep trying if it's just a GPU delay
            }

            // Reset retries if we got pixels
            retries = 0;

            for (var i = 0; i < imgData.length; i += 4) {
                var r = imgData[i] / 255;
                var g = imgData[i+1] / 255;
                var b = imgData[i+2] / 255;
                var pCol = Qt.rgba(r, g, b, 1.0);

                // Filter: Must be colorful and not too dark
                if (pCol.hsvSaturation > 0.3 && pCol.hsvValue > 0.15) {
                    var h = pCol.hsvHue * 360;
                    if (h < 0) continue;

                    var bIdx = Math.floor(h / 10) % 36;
                    var weight = pCol.hsvSaturation * pCol.hsvValue;
                    histogram[bIdx] += weight;

                    if (!sampleColors[bIdx] || weight > (sampleColors[bIdx].hsvSaturation * sampleColors[bIdx].hsvValue)) {
                        sampleColors[bIdx] = pCol;
                    }
                    vibrantFound = true;
                }
            }

            if (!vibrantFound) {
                // Calculate average brightness for monochrome wallpapers (greys/whites)
                var totalBrightness = 0;
                var pixelCount = imgData.length / 4;
                for (var k = 0; k < imgData.length; k += 4) {
                    var r_l = imgData[k] / 255;
                    var g_l = imgData[k+1] / 255;
                    var b_l = imgData[k+2] / 255;
                    totalBrightness += (0.299 * r_l + 0.587 * g_l + 0.114 * b_l);
                }
                var avgBrightness = totalBrightness / pixelCount;

                container.extractedAccent = avgBrightness < 0.5 ? "#D0D0D0" : "#404040";
                console.log("Pixie SDDM: No vibrant colors. Avg brightness: " + avgBrightness.toFixed(2) + ". Using neutral contrast.");
                processed = true;
                return;
            }

            // Merge Red wrap (350-360 and 0-10)
            histogram[0] += histogram[35];

            // Find the most frequent vibrant hue (The Mode)
            var maxCount = -1;
            var winnerIdx = -1;
            for (var j = 0; j < 35; j++) {
                if (histogram[j] > maxCount) {
                    maxCount = histogram[j];
                    winnerIdx = j;
                }
            }

            if (winnerIdx !== -1 && sampleColors[winnerIdx]) {
                var finalColor = sampleColors[winnerIdx];
                var h = finalColor.hsvHue;
                var s = Math.max(0.35, Math.min(0.55, finalColor.hsvSaturation * 0.9));
                container.extractedAccent = Qt.hsva(h, s, 0.95, 1.0);
                console.log("Pixie SDDM: SUCCESS! Extracted Hue: " + (h * 360).toFixed(0) + "°");
                processed = true;
            }
        }
    }

    Connections {
        target: backgroundImage
        function onStatusChanged() {
            if (backgroundImage.status === Image.Ready) {
                colorExtractor.processed = false;
                colorDelay.start();
            }
        }
    }

    Item { id: fontRegular; property string name: "JetBrainsMono Nerd Font" }
    Item { id: fontMedium;  property string name: "JetBrainsMono Nerd Font" }
    Item { id: fontBold;    property string name: "JetBrainsMono Nerd Font" }

    Image {
        id: backgroundImage
        source: config.background
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
    }

    // High-Quality Standalone Blur (Qt6 Native)
    MultiEffect {
        id: backgroundBlur
        anchors.fill: parent
        source: backgroundImage
        blurEnabled: true
        blur: loginState.visible ? 1.0 : 0.0
        opacity: loginState.visible ? 1.0 : 0.0
        autoPaddingEnabled: false

        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
        Behavior on blur { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
    }
    
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: loginState.visible ? 0.6 : 0.4
        Behavior on opacity { NumberAnimation { duration: 400 } }
    }

    PowerBar {
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 30
            rightMargin: 40
        }
        textColor: container.extractedAccent
        z: 100
        opacity: container.uiReady ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    Shortcut {
        sequence: "Escape"
        enabled: loginState.visible
        onActivated: {
            loginState.visible = false;
            loginState.isError = false;
            passwordField.text = "";
            container.focus = true;
        }
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: loginState.visible
        onActivated: container.doLogin()
    }

    Text {
        id: dateText
        text: Qt.formatDateTime(new Date(), "dddd, MMMM d")
        color: container.extractedAccent
        font.pixelSize: 22
        font.family: fontBold.name
        anchors {
            top: parent.top
            left: parent.left
            topMargin: 50
            leftMargin: 60
        }
        opacity: container.uiReady ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    Item {
        id: lockState
        anchors.fill: parent
        visible: !loginState.visible
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 400 } }

        Clock {
            id: mainClock
            anchors.centerIn: parent
            backgroundSource: config.background
            baseAccent: container.extractedAccent
            fontFamily: fontBold.name
            opacity: container.uiReady ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        Text {
            text: "Press any key to unlock"
            color: config.textColor
            font.pixelSize: 16
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: 100
            }
            opacity: 0.5
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                loginState.visible = true;
                passwordField.forceActiveFocus();
            }
        }
    }

    Item {
        id: loginState
        anchors.fill: parent
        visible: false
        opacity: visible ? 1 : 0
        z: 10
        Behavior on opacity { NumberAnimation { duration: 400 } }

        onVisibleChanged: {
            if (visible) passwordField.forceActiveFocus();
        }

        property bool isError: false
        SequentialAnimation {
            id: shakeAnimation
            loops: 2
            PropertyAnimation { target: loginCard; property: "x"; from: (container.width - loginCard.width)/2; to: (container.width - loginCard.width)/2 - 10; duration: 50; easing.type: Easing.InOutQuad }
            PropertyAnimation { target: loginCard; property: "x"; from: (container.width - loginCard.width)/2 - 10; to: (container.width - loginCard.width)/2 + 10; duration: 50; easing.type: Easing.InOutQuad }
            PropertyAnimation { target: loginCard; property: "x"; from: (container.width - loginCard.width)/2 + 10; to: (container.width - loginCard.width)/2; duration: 50; easing.type: Easing.InOutQuad }
            onStopped: isError = false
        }

        Rectangle {
            id: loginCard
            width: 380
            height: 580 + (numLockIndicator.visible ? 40 : 0)
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2
            
            color: "transparent"
            border.color: container.extractedAccent
            border.width: 1
            radius: 0
            opacity: 1.0

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 40
                spacing: 12

                Item {
                    Layout.preferredWidth: 160
                    Layout.preferredHeight: 160
                    Layout.alignment: Qt.AlignHCenter

                    Rectangle {
                        id: avatarFallback
                        anchors.fill: parent
                        color: "transparent"
                        border.color: container.extractedAccent
                        border.width: 0
                        visible: avatar.status !== Image.Ready
                        Text {
                            anchors.centerIn: parent
                            text: "U"
                            color: container.extractedAccent
                            font.pixelSize: 48
                        }
                    }

                    Canvas {
                        id: avatarCanvas
                        anchors.fill: parent
                        visible: avatar.status === Image.Ready
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            
                            var cx = width / 2;
                            var cy = height / 2;
                            var r = width / 2; 
                            
                            ctx.beginPath();
                            for (var i = 0; i < 6; i++) {
                                var angle = i * (Math.PI / 3);
                                var pX = cx + r * Math.cos(angle);
                                var pY = cy + r * Math.sin(angle);
                                
                                if (i === 0) {
                                    ctx.moveTo(pX, pY);
                                } else {
                                    ctx.lineTo(pX, pY);
                                }
                            }
                            ctx.closePath();
                            
                            ctx.clip();
                            ctx.drawImage(avatar, 0, 0, width, height);
                            
                            ctx.lineWidth = 4;
                            ctx.strokeStyle = container.extractedAccent;
                            ctx.stroke();
                        }
                        
                        Timer {
                            id: repaintTimer
                            interval: 500
                            onTriggered: avatarCanvas.requestPaint()
                        }
                        
                        Image {
                            id: avatar
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            visible: false
                            Component.onCompleted: source = Qt.resolvedUrl("assets/avatar.jpg");
                            onStatusChanged: if (status === Image.Ready) repaintTimer.start();
                        }
                    }
                }

                Item { Layout.preferredHeight: 10 }

                Text {
                    text: "> SESSION"
                    color: container.extractedAccent
                    font.pixelSize: 12
                    font.family: fontBold.name
                    Layout.alignment: Qt.AlignLeft
                    Layout.topMargin: 5
                }

                Rectangle {
                    id: sessionPill
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: parent.width
                    Layout.preferredHeight: 36
                    color: sessionClickArea.pressed ? Qt.rgba(1,1,1,0.1) : "transparent"
                    border.width: 1
                    border.color: container.extractedAccent
                    radius: 0

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: "󰟀"; color: container.extractedAccent; font.pixelSize: 16 }
                        Text {
                            text: "Hyprland"
                            color: "white"
                            font.pixelSize: 13
                        }
                    }
                    MouseArea {
                        id: sessionClickArea
                        anchors.fill: parent
                        onClicked: sessionPopup.open()
                    }
                }

                Text {
                    text: "> USERNAME"
                    color: container.extractedAccent
                    font.pixelSize: 12
                    font.family: fontBold.name
                    Layout.alignment: Qt.AlignLeft
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: parent.width
                    Layout.preferredHeight: 36
                    color: "transparent"
                    border.width: 1
                    border.color: container.extractedAccent
                    radius: 0

                    Text {
                        id: userNameLabel
                        text: cleanName(sddm.lastUser ? sddm.lastUser : "Jaime")
                        color: "white"
                        font.pixelSize: 16
                        font.family: fontBold.name

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 15
                    }
                }

                Text {
                    text: "> PASSWORD"
                    color: container.extractedAccent
                    font.pixelSize: 12
                    font.family: fontBold.name
                    Layout.alignment: Qt.AlignLeft
                    horizontalAlignment: Text.AlignLeft
                    Layout.topMargin: 5
                }

                TextField {
                    id: passwordField
                    echoMode: TextInput.Password
                    Layout.preferredWidth: parent.width
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignHCenter

                    horizontalAlignment: Text.AlignLeft
                    leftPadding: 15
                    
                    font.pixelSize: 18
                    color: "white"
                    focus: loginState.visible
                    enabled: !container.isLoggingIn

                    background: Rectangle {
                        color: "transparent"
                        radius: 0
                        border.width: parent.activeFocus ? 2 : 1
                        border.color: container.extractedAccent
                    }
                    onAccepted: container.doLogin()
                }

                Text {
                    id: numLockIndicator
                    text: "[ NUM LOCK IS ON ]"
                    color: container.extractedAccent
                    font.pixelSize: 12
                    font.family: fontBold.name
                    Layout.alignment: Qt.AlignHCenter
                    visible: (typeof keyboard !== "undefined" && typeof keyboard.numLock !== "undefined") ? keyboard.numLock : false
                }

                Button {
                    id: loginButton
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: parent.width
                    Layout.preferredHeight: 40
                    Layout.topMargin: 15
                    focusPolicy: Qt.NoFocus
                    enabled: !container.isLoggingIn

                    contentItem: Text {
                        text: container.isLoggingIn ? "[ CONNECTING... ]" : "[ ENTER ]"
                        color: loginButton.pressed ? "black" : container.extractedAccent
                        font.pixelSize: 14
                        font.family: fontBold.name
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: loginButton.pressed ? container.extractedAccent : "transparent"
                        radius: 0
                        border.width: 1
                        border.color: container.extractedAccent
                    }

                    onClicked: container.doLogin()
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    Keys.onPressed: function(event) {
        if (!loginState.visible) {
            loginState.visible = true;
            passwordField.forceActiveFocus();
            event.accepted = true;
        }
    }

    Popup {
        id: userPopup
        width: 260
        height: (typeof userModel !== "undefined") ? Math.min(300, userModel.count * 50 + 20) : 100
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2 - 50
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: userList.forceActiveFocus()
        background: Rectangle {
            color: baseColor
            radius: 24
            opacity: 0.95
            border.color: surfaceVariantColor
            border.width: 1
        }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 200 } }
        ListView {
            id: userList
            anchors.fill: parent
            anchors.margins: 10
            model: (typeof userModel !== "undefined") ? userModel : null
            spacing: 5
            clip: true
            focus: true
            currentIndex: container.userIndex
            highlightFollowsCurrentItem: true
            delegate: ItemDelegate {
                width: parent.width
                height: 40
                property bool isCurrent: index === userList.currentIndex
                background: Rectangle {
                    color: isCurrent ? surfaceVariantColor : (hovered ? surfaceColor : "transparent")
                    radius: 12
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8
                        width: 4
                        height: isCurrent ? 16 : 0
                        color: container.extractedAccent
                        radius: 2
                        Behavior on height { NumberAnimation { duration: 150 } }
                    }
                }
                contentItem: RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    Item { Layout.preferredWidth: 20 }
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignVCenter
                        color: isCurrent ? container.extractedAccent : surfaceVariantColor
                        radius: 14
                        Text {
                            anchors.centerIn: parent
                            text: {
                                var mIdx = userModel.index(index, 0);
                                var d = userModel.data(mIdx, Qt.DisplayRole);
                                var n_r = userModel.data(mIdx, Qt.UserRole + 1);
                                var finalVal = d ? d.toString() : (n_r ? n_r.toString() : "U");
                                return finalVal.charAt(0).toUpperCase();
                            }
                            color: isCurrent ? baseColor : "white"
                            font.pixelSize: 12
                            font.family: fontBold.name
                            font.weight: Font.Bold
                        }
                    }
                    Item { Layout.preferredWidth: 12 }
                    Text {
                        Layout.fillWidth: true
                        text: {
                            var mIdx = userModel.index(index, 0);
                            var d = userModel.data(mIdx, Qt.DisplayRole);
                            var n_r = userModel.data(mIdx, Qt.UserRole + 1);
                            var r = userModel.data(mIdx, Qt.UserRole + 2);
                            var e = userModel.data(mIdx, Qt.EditRole);
                            return cleanName(d ? d : (r ? r : (n_r ? n_r : e)));
                        }
                        color: isCurrent ? "white" : (hovered ? "#DDDDDD" : "#AAAAAA")
                        font.pixelSize: 15
                        font.family: fontBold.name
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        rightPadding: 60
                        elide: Text.ElideRight
                    }
                }
                onClicked: {
                    container.userIndex = index;
                    userPopup.close();
                }
            }
            Keys.onDownPressed: incrementCurrentIndex()
            Keys.onUpPressed: decrementCurrentIndex()
            Keys.onReturnPressed: { container.userIndex = currentIndex; userPopup.close(); }
            Keys.onEnterPressed: { container.userIndex = currentIndex; userPopup.close(); }
        }
    }

    Popup {
        id: sessionPopup
        width: 260
        height: (typeof sessionModel !== "undefined") ? Math.min(250, sessionModel.count * 50 + 20) : 100
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2 + 80
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: sessionList.forceActiveFocus()
        background: Rectangle {
            color: baseColor
            radius: 0
            opacity: 0.95
            border.color: container.extractedAccent
            border.width: 1
        }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 200 } }
        ListView {
            id: sessionList
            anchors.fill: parent
            anchors.margins: 10
            model: (typeof sessionModel !== "undefined") ? sessionModel : null
            spacing: 5
            clip: true
            focus: true
            currentIndex: container.sessionIndex
            highlightFollowsCurrentItem: true
            delegate: ItemDelegate {
                width: parent.width
                height: 40
                property bool isCurrent: index === sessionList.currentIndex
                background: Rectangle {
                    color: isCurrent ? surfaceVariantColor : (hovered ? surfaceColor : "transparent")
                    radius: 0
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8
                        width: 4
                        height: isCurrent ? 16 : 0
                        color: container.extractedAccent
                        radius: 0
                        Behavior on height { NumberAnimation { duration: 150 } }
                    }
                }
                contentItem: RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    Item { Layout.preferredWidth: 20 }
                    Text {
                        Layout.preferredWidth: 40
                        text: "󰟀"
                        color: isCurrent ? container.extractedAccent : "gray"
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        Layout.fillWidth: true
                        text: {
                            var n_val = sessionModel.data(sessionModel.index(index, 0), Qt.UserRole + 4);
                            var f_val = sessionModel.data(sessionModel.index(index, 0), Qt.UserRole + 2);
                            return cleanName(n_val ? n_val : f_val);
                        }
                        color: isCurrent ? "white" : "#AAAAAA"
                        font.pixelSize: 14
                        font.family: fontBold.name
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        rightPadding: 60
                        elide: Text.ElideRight
                    }
                }
                onClicked: {
                    container.sessionIndex = index;
                    sessionPopup.close();
                }
            }
            Keys.onDownPressed: incrementCurrentIndex()
            Keys.onUpPressed: decrementCurrentIndex()
            Keys.onReturnPressed: { container.sessionIndex = currentIndex; sessionPopup.close(); }
            Keys.onEnterPressed: { container.sessionIndex = currentIndex; sessionPopup.close(); }
        }
    }
}
