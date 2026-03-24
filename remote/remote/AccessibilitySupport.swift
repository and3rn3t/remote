//
//  AccessibilitySupport.swift
//  remote
//
//  Created by OpenClaw on 3/8/26.
//

import SwiftUI

/// View modifier that adapts UI for accessibility preferences.
///
/// Handles:
/// - Reduce Transparency: Replaces glass effects with solid backgrounds
/// - Dynamic Type: Ensures text scales appropriately
struct AccessibilityAdaptiveModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let isProminent: Bool
    let tintColor: Color?
    let fallbackBackground: Color
    let cornerRadius: CGFloat

    init(
        isProminent: Bool = false,
        tintColor: Color? = nil,
        fallbackBackground: Color = Color(.systemBackground).opacity(0.9),
        cornerRadius: CGFloat = Design.cornerRadius
    ) {
        self.isProminent = isProminent
        self.tintColor = tintColor
        self.fallbackBackground = fallbackBackground
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(fallbackBackground)
                } else if isProminent, let tint = tintColor {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                }
            }
    }
}

extension View {
    /// Applies an adaptive glass effect that respects Reduce Transparency preference.
    ///
    /// - Parameters:
    ///   - isProminent: Whether to use a prominent (tinted) glass effect.
    ///   - tintColor: Tint color when `isProminent` is true.
    ///   - fallbackBackground: The solid background to use when transparency is reduced.
    ///   - cornerRadius: Corner radius of the background shape.
    ///
    /// - Returns: A view with adaptive glass effect or solid background.
    func adaptiveGlassEffect(
        isProminent: Bool = false,
        tintColor: Color? = nil,
        fallbackBackground: Color = Color(.systemBackground).opacity(0.9),
        cornerRadius: CGFloat = Design.cornerRadius
    ) -> some View {
        modifier(AccessibilityAdaptiveModifier(
            isProminent: isProminent,
            tintColor: tintColor,
            fallbackBackground: fallbackBackground,
            cornerRadius: cornerRadius
        ))
    }
}

/// Button style that adapts to Dynamic Type size.
///
/// Increases padding and minimum tap target size for larger text sizes.
struct AdaptiveButtonStyle: ButtonStyle {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var isProminent: Bool = false
    var tintColor: Color?

    func makeBody(configuration: Configuration) -> some View {
        let isLargeText = dynamicTypeSize >= .accessibility1

        configuration.label
            .padding(.horizontal, isLargeText ? Design.spacingXL : Design.spacingLG)
            .padding(.vertical, isLargeText ? Design.spacingLG : Design.spacingMD)
            .frame(minHeight: isLargeText ? 56 : 44)
            .adaptiveGlassEffect(
                isProminent: isProminent,
                tintColor: tintColor ?? .blue,
                cornerRadius: Design.cornerRadius
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    /// Applies an adaptive button style that respects Dynamic Type.
    ///
    /// - Parameters:
    ///   - isProminent: Whether to use a prominent (tinted) style.
    ///   - tintColor: Optional tint color for prominent style.
    func adaptiveButtonStyle(isProminent: Bool = false, tintColor: Color? = nil) -> some View {
        buttonStyle(AdaptiveButtonStyle(isProminent: isProminent, tintColor: tintColor))
    }
}

/// Slider view that adapts to Dynamic Type and accessibility preferences.
struct AccessibleSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let label: String
    let valueFormatter: (Double) -> String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 1,
        label: String,
        valueFormatter: @escaping (Double) -> String = { "\(Int($0))" }
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.label = label
        self.valueFormatter = valueFormatter
    }

    var body: some View {
        VStack(spacing: dynamicTypeSize >= .accessibility1 ? Design.spacingMD : Design.spacingSM) {
            HStack {
                Text(label)
                    .font(.headline)
                Spacer()
                Text(valueFormatter(value))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(label): \(valueFormatter(value))")
            }

            Slider(value: $value, in: range, step: step)
                .accessibilityValue(valueFormatter(value))
                .accessibilityLabel(label)
        }
    }
}

/// Helper to calculate appropriate font sizes for Dynamic Type.
extension Font {
    /// Returns a scaled font that respects user's Dynamic Type preference.
    ///
    /// - Parameter style: The text style (e.g., .body, .headline).
    /// - Returns: A font that scales with Dynamic Type.
    static func scaledFont(_ style: Font.TextStyle) -> Font {
        .system(style, design: .default)
    }
}
