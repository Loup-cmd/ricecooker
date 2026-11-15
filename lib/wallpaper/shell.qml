// hypr-switch built-in wallpaper layer.
//
// Ricings that do not draw their own background (waybar/rofi dotfiles, or any
// ricing without the Omarchy shell) get the image hypr-switch sets through
// omarchy-theme-bg-set: ~/.local/state/omarchy/current/background. The link is
// re-read every few seconds so a later `omarchy-theme-bg-set` is picked up.
//
// Started with: qs -p ~/.hypr-switch/lib/wallpaper
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string link: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
    property string current: ""

    Process {
        id: resolve
        command: ["readlink", "-f", root.link]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = this.text.trim();
                if (path !== "" && path !== root.current)
                    root.current = path;
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: resolve.running = true
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "hypr-switch-wallpaper"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "#000000"

            Image {
                anchors.fill: parent
                source: root.current !== "" ? "file://" + root.current : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                smooth: true
            }
        }
    }
}
