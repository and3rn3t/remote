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
    
    /// The glass effect to apply when transparency is NOT reduced.
    let glassEffect: GlassEffectShapeStyle
    
    /// Fallback background color when transparency IS reduced.
    let fallbackBackground: Color
    
    /// Corner radius for the shape.
    let cornerRadius: CGFloat
    
    init(
        glassEffect: GlassEffectShapeStyle = .regular.interactive(),
        fallbackBackground: Color = Color(.systemBackground).opacity(0.9),
        cornerRadius: CGFloat = 12
    ) {
        self.glassEffect = glassEffect
        self.fallbackBackground = fallbackBackground
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    // Solid background for accessibility
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(fallbackBackground)
                } else {
                    // Liquid Glass effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .glassEffect(glassEffect, in: .rect(cornerRadius: cornerRadius))
                }
            }
    }
}

extension View {
    /// Applies an adaptive glass effect that respects Reduce Transparency preference.
    ///
    /// - Parameters:
    ///   - glassEffect: The glass effect style to use when transparency is enabled.
    ///   - fallbackBackground: The solid background to use when transparency is reduced.
    ///   - cornerRadius: Corner radius of the background shape.
    ///
    /// - Returns: A view with adaptive glass effect or solid background.
    func adaptiveGlassEffect(
        _ glassEffect: GlassEffectShapeStyle = .regular.interactive(),
        fallbackBackground: Color = Color(.systemBackground).opacity(0.9),
        cornerRadius: CGFloat = 12
    ) -> some View {
        modifier(AccessibilityAdaptiveModifier(
            glassEffect: glassEffect,
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
    var tintColor: Color? = nil
    
    func makeBody(configuration: Configuration) -> some View {
        let isLargeText = dynamicTypeSize >= .accessibility1
        
        configuration.label
            .padding(.horizontal, isLargeText ? 24 : 16)
            .padding(.vertical, isLargeText ? 16 : 12)
            .frame(minHeight: isLargeText ? 56 : 44) // Minimum tap target
            .adaptiveGlassEffect(
                isProminent ? .regular.tint(tintColor ?? .blue).interactive() : .regular.interactive(),
                cornerRadius: 12
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
        VStack(spacing: dynamicTypeSize >= .accessibility1 ? 12 : 8) {
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
