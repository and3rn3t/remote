//
//  AppShortcuts.swift
//  remote
//
//  Created by Matt on 3/8/26.
//

import AppIntents

struct RemoteAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PowerOnIntent(),
            phrases: [
                "Turn on \(\.$receiver) with \(.applicationName)",
                "Power on \(\.$receiver) with \(.applicationName)",
            ],
            shortTitle: "Power Receiver",
            systemImageName: "power"
        )

        AppShortcut(
            intent: SetVolumeIntent(),
            phrases: [
                "Set \(\.$receiver) volume with \(.applicationName)",
                "Change volume on \(\.$receiver) with \(.applicationName)",
            ],
            shortTitle: "Set Volume",
            systemImageName: "speaker.wave.2.fill"
        )

        AppShortcut(
            intent: SetInputIntent(),
            phrases: [
                "Switch input on \(\.$receiver) with \(.applicationName)",
                "Change \(\.$receiver) input with \(.applicationName)",
            ],
            shortTitle: "Set Input",
            systemImageName: "tv.and.hifispeaker.fill"
        )

        AppShortcut(
            intent: ToggleMuteIntent(),
            phrases: [
                "Mute \(\.$receiver) with \(.applicationName)",
                "Unmute \(\.$receiver) with \(.applicationName)",
            ],
            shortTitle: "Toggle Mute",
            systemImageName: "speaker.slash.fill"
        )
    }
}
