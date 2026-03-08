//
//  remoteApp.swift
//  remote
//
//  Created by Matt on 3/7/26.
//

import SwiftUI
import SwiftData

@main
struct remoteApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DenonReceiver.self,
            ReceiverScene.self,
        ])

        // When running as test host, use a minimal in-memory container to avoid
        // CloudKit entitlement issues that crash the test bootstrap.
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
        if isTesting {
            // swiftlint:disable:next force_try
            return try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(
                    "testing",
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
            )
        }

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Fall back to in-memory store so the app remains usable
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: showOnboarding) {
                    OnboardingView {
                        showOnboarding.wrappedValue = false
                    }
                    .interactiveDismissDisabled()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !AppSettings.hasCompletedOnboarding },
            set: { newValue in
                AppSettings.hasCompletedOnboarding = !newValue
            }
        )
    }
}
