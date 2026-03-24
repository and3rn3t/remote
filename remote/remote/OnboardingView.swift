//
//  OnboardingView.swift
//  remote
//
//  Created by Matt on 3/7/26.
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    var onComplete: () -> Void

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            networkPage.tag(1)
            getStartedPage.tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "hifispeaker.2.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text("Welcome to Denon Remote")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Control your Denon AVR receivers from your iPhone or iPad.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            GlassEffectContainer(spacing: 0) {
                Button {
                    playHaptic()
                    withAnimation { currentPage = 1 }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
                .accessibilityLabel("Continue to next page")
            }
        }
        .padding(32)
    }

    // MARK: - Network Page

    private var networkPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "wifi")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text("Local Network Access")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("This app needs local network access to discover and control receivers on your Wi-Fi network. You'll be prompted to allow this.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            GlassEffectContainer(spacing: 0) {
                Button {
                    playHaptic()
                    withAnimation { currentPage = 2 }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
                .accessibilityLabel("Continue to next page")
            }
        }
        .padding(32)
    }

    // MARK: - Get Started Page

    private var getStartedPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text("Add Your Receiver")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Scan your network to find receivers automatically, or add one manually with its IP address.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            GlassEffectContainer(spacing: 0) {
                Button {
                    playHaptic()
                    AppSettings.hasCompletedOnboarding = true
                    onComplete()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.blue).interactive(), in: .rect(cornerRadius: 14))
                .accessibilityLabel("Get started with the app")
            }
        }
        .padding(32)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
