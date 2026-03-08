//
//  remoteWidgetsBundle.swift
//  remoteWidgets
//

import WidgetKit
import SwiftUI

@main
struct remoteWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ReceiverStatusWidget()
        NowPlayingLiveActivity()
    }
}
