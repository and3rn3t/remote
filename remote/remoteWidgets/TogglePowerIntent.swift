//
//  TogglePowerIntent.swift
//  remoteWidgets
//

import AppIntents
import SharedModels
import WidgetKit

struct TogglePowerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Receiver Power"
    static var description = IntentDescription("Toggles the power state of your Denon receiver.")

    func perform() async throws -> some IntentResult {
        guard var status = ReceiverStatus.load() else {
            return .result()
        }

        let command = status.isPowerOn ? "PWSTANDBY" : "PWON"
        let success = await DenonCommandSender.send(command, to: status.ipAddress, port: status.port)

        if success {
            status.isPowerOn.toggle()
            status.lastUpdated = .now
            status.save()
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "ReceiverStatusWidget")
        return .result()
    }
}
