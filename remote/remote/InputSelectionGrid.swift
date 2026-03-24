//
//  InputSelectionGrid.swift
//  remote
//

import SwiftUI

/// Reusable grid of input source buttons with glass styling.
struct InputSelectionGrid: View {
    let currentInput: String
    /// Custom aliases from the receiver (keyed by input code). Falls back to built-in names.
    var aliases: [String: String] = [:]
    let onSelect: (String) -> Void

    var body: some View {
        GlassEffectContainer(spacing: 12.0) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                ForEach(DenonInputs.all, id: \.code) { input in
                    let isSelected = currentInput == input.code
                    let displayName = aliases[input.code] ?? input.name
                    Button {
                        playHaptic(.light)
                        onSelect(input.code)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: DenonInputs.icon(for: input.code))
                                .font(.title2)
                                .foregroundStyle(isSelected ? .white : .primary)

                            Text(displayName)
                                .font(.caption)
                                .foregroundStyle(isSelected ? .white : .primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(
                        isSelected ?
                            .regular.tint(.purple).interactive() :
                            .regular.interactive(),
                        in: .rect(cornerRadius: 12)
                    )
                    .accessibilityLabel(displayName)
                    .accessibilityValue(isSelected ? "Selected" : "")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}
