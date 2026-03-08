//
//  ViewHelpers.swift
//  remote
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Shared Haptic Feedback

#if canImport(UIKit)
func playHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}
#else
func playHaptic(_ style: Any? = nil) {}
#endif
