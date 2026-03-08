//
//  ToneControlView.swift
//  remote
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Extracted Tone Controls section from ReceiverControlView.
struct ToneControlView: View {
    let api: DenonAPI
    let onError: (String) -> Void

    @State private var toneDebounceTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundStyle(.cyan)

                Text("Tone Controls")
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            GlassEffectContainer(spacing: 12.0) {
                VStack(spacing: 20) {
                    toneSlider(label: "Bass",
                               value: api.state.bass,
                               onSet: { api.state.bass = $0 },
                               apiCall: api.setBass)

                    toneSlider(label: "Treble",
                               value: api.state.treble,
                               onSet: { api.state.treble = $0 },
                               apiCall: api.setTreble)
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
        }
    }

    private func toneSlider(
        label: String,
        value: Int,
        onSet: @escaping (Int) -> Void,
        apiCall: @escaping (Int) async throws -> Void
    ) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(DenonConstants.toneLabel(value))
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { newValue in
                        let target = Int(newValue)
                        onSet(target)
                        toneDebounceTask?.cancel()
                        toneDebounceTask = Task {
                            try? await Task.sleep(for: .milliseconds(DenonConstants.volumeDebounceMilliseconds))
                            guard !Task.isCancelled else { return }
                            do {
                                try await apiCall(target)
                            } catch {
                                onError(error.localizedDescription)
                            }
                        }
                    }
                ),
                in: Double(DenonConstants.toneMin)...Double(DenonConstants.toneMax),
                step: 1
            )
            .tint(.cyan)
            .accessibilityLabel(label)
            .accessibilityValue(DenonConstants.toneLabel(value))
            .accessibilityHint("Adjusts \(label.lowercased()) from minus 6 to plus 6 decibels")
        }
    }
}
