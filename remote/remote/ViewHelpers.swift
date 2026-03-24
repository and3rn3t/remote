//
//  ViewHelpers.swift
//  remote
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Design Tokens

/// Consolidated spacing and radius values used across all views.
/// Spacing scale: 4 · 8 · 12 · 16 · 24 · 32
/// Corner radii: 12 (controls) · 16 (cards)
enum Design {
    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 24
    static let spacingXXL: CGFloat = 32

    // Corner radii
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16

    // Card inner padding (glass containers)
    static let cardPadding: CGFloat = 16

    // Grid column minimums
    static let gridMinSmall: CGFloat = 80
    static let gridMinMedium: CGFloat = 100
    static let gridMinLarge: CGFloat = 120

    // Button dimensions
    static let circleButtonSize: CGFloat = 48
}

// MARK: - Shared Haptic Feedback

#if canImport(UIKit)
func playHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}
#else
func playHaptic(_ style: Any? = nil) {}
#endif
