// mpris-pill — cápsula de música estilo iOS para Hyprland (Quickshell)
//
// Qué hace:
//   - Aparece abajo al centro SOLO mientras Spotify está reproduciendo.
//   - Compacta: carátula a la izquierda, ecualizador a la derecha.
//   - Con el ratón encima: se agranda y muestra título, artista y controles.
//   - Clic derecho sobre la cápsula: cambia su color (paleta de 5).
//   - Barras y textos siguen siempre al tema activo de Omarchy.
//
// Archivos que usa (misma carpeta): cava.conf

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    // ═════════════════════ AJUSTES ═════════════════════

    // Paleta de colores de la cápsula (clic derecho para pasar al siguiente).
    // La palabra "theme" significa: usar el color del tema activo de Omarchy.
    readonly property var pillPalette: [
        "theme",    // 0 → TEMA ACTUAL (principal, es el que arranca)
        "#000000",  // 1 → Negro puro (iOS)
        "#1e1e2e",  // 2 → Catppuccin Mocha
        "#12121b",  // 3 → Azul-negro profundo
        "#2e3440"   // 4 → Nord
    ]
    property int currentPaletteIndex: 0

    // Qué color del tema usa la entrada "theme". Claves útiles de colors.toml:
    //   "darker_background" → el más oscuro (se distingue del fondo de pantalla)
    //   "background"        → el fondo exacto del tema (puede camuflarse con el wallpaper)
    readonly property string themePillKey: "darker_background"

    readonly property int barCount: 16  // debe coincidir con `bars` de cava.conf
    readonly property string home: Quickshell.env("HOME")
    readonly property string cavaConfig: home + "/.config/quickshell/mpris-pill/cava.conf"

    // ═════════════════════════════════════════════════

    // ───────────── Tema de Omarchy ─────────────
    // Leemos colors.toml del tema activo. No lo "observamos" directamente porque
    // omarchy-theme-set borra y reemplaza esa carpeta entera al cambiar de tema;
    // en su lugar vigilamos current/theme.name, que se reescribe en el mismo
    // archivo justo después de que los colores nuevos ya están en su sitio.
    FileView {
        id: colorsFile
        path: root.home + "/.config/omarchy/current/theme/colors.toml"
    }

    FileView {
        id: themeNameFile
        path: root.home + "/.config/omarchy/current/theme.name"
        watchChanges: true
        onFileChanged: reloadDelay.restart()
    }

    Timer {
        id: reloadDelay
        interval: 250  // margen para que termine de escribirse el tema nuevo
        onTriggered: colorsFile.reload()
    }

    // Convierte líneas tipo   clave = "valor"   en un objeto de JavaScript
    function parseToml(txt) {
        const out = {};
        const lines = txt.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*"([^"]*)"/);
            if (m)
                out[m[1]] = m[2];
        }
        return out;
    }

    property var theme: parseToml(colorsFile.text())

    // ───────────── Colores derivados (con valores de respaldo) ─────────────
    readonly property color accent: theme.accent ? theme.accent : "#d9c2a0"
    readonly property color mutedColor: theme.muted ? theme.muted : "#8e8e93"

    // Color de la cápsula: el de la paleta, o el del tema si la entrada es "theme"
    readonly property color pillColor: {
        const v = pillPalette[currentPaletteIndex];
        if (v === "theme") {
            const t = theme[themePillKey] || theme.background;
            return t ? t : "#000000";
        }
        return v;
    }

    readonly property bool pillIsDark: pillColor.hslLightness < 0.5

    // Color de texto e iconos: el "foreground" del tema, pero solo si contrasta
    // con la cápsula (así un color claro no deja letras claras sobre claro).
    readonly property color textColor: {
        const f = theme.foreground ? Qt.color(theme.foreground) : null;
        if (pillIsDark)
            return (f && f.hslLightness > 0.5) ? f : Qt.color("#f5f5f7");
        return (f && f.hslLightness <= 0.5) ? f : Qt.color("#1c1c1e");
    }

    // ───────────── Estado de la música ─────────────
    // Alturas de las barras (0–100) que llegan desde cava
    property var levels: []

    // Solo nos interesa Spotify: Brave también expone MPRIS y lo ignoramos
    property var player: {
        const list = Mpris.players.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].identity.toLowerCase().indexOf("spotify") !== -1)
                return list[i];
        }
        return null;
    }

    readonly property bool playing: player !== null && player.isPlaying

    // ───────────── Componentes reutilizables ─────────────
    // (Los componentes en línea no ven los `id` de afuera: los colores
    //  se les pasan como propiedades desde donde se usan.)

    // Triángulo (dir = 1 apunta a la derecha, dir = -1 a la izquierda)
    component Tri: Shape {
        id: tri
        property int dir: 1
        property color fill: "white"
        width: 12
        height: 14
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: tri.fill
            strokeColor: "transparent"
            startX: tri.dir === 1 ? 0 : 12
            startY: 0
            PathLine { x: tri.dir === 1 ? 12 : 0; y: 7 }
            PathLine { x: tri.dir === 1 ? 0 : 12; y: 14 }
            PathLine { x: tri.dir === 1 ? 0 : 12; y: 0 }
        }
    }

    // Botón: crece un poco al pasar el ratón y se encoge al pulsar
    component Btn: Item {
        id: btn
        signal clicked()
        default property alias content: holder.data

        width: 30
        height: 26
        scale: tap.pressed ? 0.85 : (hover.hovered ? 1.15 : 1.0)
        opacity: hover.hovered ? 1.0 : 0.75
        Behavior on scale { NumberAnimation { duration: 90 } }
        Behavior on opacity { NumberAnimation { duration: 90 } }

        Item {
            id: holder
            anchors.centerIn: parent
            width: 16
            height: 16
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: tap; onTapped: btn.clicked() }
    }

    // ───────────── cava: el ecualizador ─────────────
    // Solo corre mientras suena música, para no gastar CPU en vano.
    Process {
        id: cava
        command: ["cava", "-p", root.cavaConfig]
        running: root.playing

        stdout: SplitParser {
            // Cada línea es un fotograma: "12;45;80;...;"
            onRead: data => {
                root.levels = data.split(";").filter(s => s.length > 0).map(Number);
            }
        }

        onRunningChanged: if (!running) root.levels = []
    }

    // ───────────── La ventana ─────────────
    PanelWindow {
        id: panel

        readonly property bool shouldShow: root.playing || hovered
        property bool hovered: hover.hovered

        // La ventana solo existe mientras la cápsula se ve (o se está animando)
        visible: shouldShow || pill.opacity > 0.01
        color: "transparent"

        // Sin esto, Quickshell reservaría espacio y empujaría tus ventanas hacia arriba
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "mpris-pill"

        anchors.bottom: true
        margins.bottom: 24
        implicitWidth: 460
        implicitHeight: 120

        // Solo la cápsula recibe el ratón; el resto de la ventana deja pasar los clics
        mask: Region { item: pill }

        Rectangle {
            id: pill

            readonly property bool expanded: panel.hovered

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: panel.shouldShow ? 0 : -36

            width: expanded ? 430 : 300
            height: expanded ? 92 : 52
            radius: Math.min(height / 2, 34)
            color: root.pillColor
            border.width: 0
            border.color: root.pillIsDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.10)
            opacity: panel.shouldShow ? 1 : 0

            Behavior on width  { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.0 } }
            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.0 } }
            Behavior on opacity { NumberAnimation { duration: 220 } }
            Behavior on anchors.bottomMargin { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

            // Transición suave al cambiar de color (clic derecho o cambio de tema)
            Behavior on color { ColorAnimation { duration: 250 } }

            HoverHandler { id: hover }

            // Clic derecho: pasa al siguiente color de la paleta (después del último vuelve al primero)
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: root.currentPaletteIndex = (root.currentPaletteIndex + 1) % root.pillPalette.length
            }

            // ── Carátula (izquierda) ──
            ClippingRectangle {
                id: art
                anchors.left: parent.left
                anchors.leftMargin: pill.expanded ? 12 : 14
                anchors.verticalCenter: parent.verticalCenter
                width: height
                height: pill.expanded ? 68 : 36
                radius: pill.expanded ? 14 : 10
                color: "#161616"

                Behavior on anchors.leftMargin { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.0 } }
                Behavior on radius { NumberAnimation { duration: 260 } }

                Image {
                    anchors.fill: parent
                    source: root.player ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize: Qt.size(160, 160)
                }
            }

            // ── Ecualizador (derecha): barras centradas, crecen hacia arriba y abajo ──
            Row {
                id: viz
                anchors.right: parent.right
                anchors.rightMargin: pill.expanded ? 24 : 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Behavior on anchors.rightMargin { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                Repeater {
                    model: root.barCount

                    delegate: Item {
                        id: slot
                        required property int index

                        width: 3
                        height: pill.expanded ? 46 : 30
                        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 3
                            radius: 1.5
                            color: root.accent
                            height: Math.max(3, ((root.levels[slot.index] || 0) / 100) * slot.height)
                            Behavior on height { NumberAnimation { duration: 80 } }
                            Behavior on color { ColorAnimation { duration: 400 } }
                        }
                    }
                }
            }

            // ── Centro: título, artista y controles (solo con hover) ──
            Item {
                id: info
                anchors.left: art.right
                anchors.leftMargin: 14
                anchors.right: viz.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                height: col.height

                opacity: pill.expanded ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Column {
                    id: col
                    width: parent.width
                    spacing: 2

                    Text {
                        width: parent.width
                        text: root.player ? root.player.trackTitle : ""
                        color: root.textColor
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: root.player ? root.player.trackArtist : ""
                        color: root.mutedColor
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Item { width: 1; height: 4 }

                    Row {
                        spacing: 8

                        // Anterior
                        Btn {
                            onClicked: if (root.player) root.player.previous()
                            Row {
                                anchors.centerIn: parent
                                spacing: 1
                                Rectangle { width: 2; height: 14; color: root.textColor }
                                Tri { dir: -1; fill: root.textColor }
                            }
                        }

                        // Pausa / reproducir
                        Btn {
                            onClicked: if (root.player) root.player.togglePlaying()
                            Row {
                                visible: root.playing
                                anchors.centerIn: parent
                                spacing: 4
                                Rectangle { width: 4; height: 14; radius: 1.5; color: root.textColor }
                                Rectangle { width: 4; height: 14; radius: 1.5; color: root.textColor }
                            }
                            Tri {
                                visible: !root.playing
                                anchors.centerIn: parent
                                fill: root.textColor
                            }
                        }

                        // Siguiente
                        Btn {
                            onClicked: if (root.player) root.player.next()
                            Row {
                                anchors.centerIn: parent
                                spacing: 1
                                Tri { dir: 1; fill: root.textColor }
                                Rectangle { width: 2; height: 14; color: root.textColor }
                            }
                        }
                    }
                }
            }
        }
    }
}
