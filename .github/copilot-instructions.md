# Copilot Instructions — Denon Remote

## Project Overview

Native iOS remote control app for Denon AV Receivers. Built with SwiftUI, SwiftData, and iOS 26 Liquid Glass design.

## Tech Stack

- **Language**: Swift 6.2 (strict concurrency)
- **UI**: SwiftUI with iOS 26 Liquid Glass (`GlassEffectContainer`, `.glass`, `.glassProminent`)
- **Data**: SwiftData with iCloud/CloudKit sync
- **Observation**: `@Observable` macro (not `ObservableObject`)
- **Concurrency**: `async`/`await` throughout — no Combine, no completion handlers
- **Networking**: Raw TCP sockets via `CFStreamCreatePairWithSocketToHost` and `NWConnection` (for intents/widgets)
- **Minimum Target**: iOS 26.0
- **Build Tool**: Xcode 26 / SPM (`Package.swift`, no external dependencies)

## Project Structure

```
remote/
├── SharedModels/            # Local Swift package (shared between targets)
│   ├── Package.swift
│   └── Sources/SharedModels/
│       ├── ReceiverStatus.swift      # Codable App Group shared state
│       ├── NowPlayingAttributes.swift # ActivityKit attributes
│       └── DenonCommandSender.swift  # Lightweight NWConnection TCP sender
├── remote/                  # Main app target
│   ├── remoteApp.swift      # Entry point, SwiftData container
│   ├── DenonAPI.swift       # @Observable TCP client, protocol implementation
│   ├── DenonReceiver.swift  # SwiftData model
│   ├── DenonConstants.swift # Protocol constants, input/surround maps
│   ├── ReceiverScene.swift  # SwiftData scene/preset model
│   ├── BonjourDiscovery.swift
│   ├── ConnectionLogger.swift
│   ├── ContentView.swift    # NavigationSplitView, receiver list
│   ├── ReceiverControlView.swift  # Main control UI
│   ├── NowPlayingView.swift
│   ├── ToneControlView.swift
│   ├── DynamicSettingsView.swift
│   ├── ZoneControlView.swift
│   ├── SceneListView.swift
│   ├── SettingsView.swift
│   ├── OnboardingView.swift
│   ├── LogViewerView.swift
│   ├── ReceiverEntity.swift      # App Entity for Siri
│   ├── ReceiverIntents.swift     # App Intents
│   ├── AppShortcuts.swift        # Spotlight / Siri phrases
│   └── NowPlayingActivity.swift  # ActivityKit Live Activity
├── remoteWidgets/           # WidgetKit extension target
│   ├── ReceiverWidgets.swift
│   ├── NowPlayingLiveActivity.swift
│   └── TogglePowerIntent.swift
├── remoteTests/             # Unit tests (Swift Testing)
└── remoteUITests/           # UI tests (XCTest)
```

## Conventions

### Swift Style

- 4-space indentation
- Use Swift Testing framework (`@Test`, `#expect`) for unit tests, not XCTest
- Prefer `let` over `var`; avoid force unwraps and force casts
- Follow SwiftLint rules in `.swiftlint.yml`

### UI Patterns

- Use `GlassEffectContainer` to group multiple glass elements
- Use `.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))` for interactive buttons
- Use `.glassEffect(.regular.tint(.color).interactive(), ...)` for active/selected states
- All interactive controls should include haptic feedback (`UIImpactFeedbackGenerator`)
- Add VoiceOver accessibility labels to all custom controls

### Denon Protocol

- Commands are sent over TCP port 23, terminated with `\r`
- Responses are asynchronous — the app polls and parses a stream
- Volume is an integer 00–98 (mapped to 0.0–98.0 dB); ignore `MVMAX` responses
- Zone 2/3 commands use `Z2`/`Z3` prefix (e.g., `Z2PWON`, `Z3MV50`)
- Input codes and surround modes are defined in `DenonConstants.swift`

### Data Flow

- `DenonAPI` is the single source of truth for receiver state
- Receiver state is synced to App Group `UserDefaults` (`group.dev.andernet.remote`) for widgets
- Shared types (`ReceiverStatus`, `NowPlayingAttributes`, `DenonCommandSender`) live in the `SharedModels` local Swift package
- SwiftData models use `.automatic` CloudKit configuration
- Widget/Intent targets use lightweight `DenonCommandSender` TCP — not `DenonAPI`

### Testing

- Unit tests live in `remoteTests/remoteTests.swift`
- UI tests live in `remoteUITests/remoteUITests.swift`
- Run tests: `xcodebuild test -project remote/remote.xcodeproj -scheme remote -destination 'platform=iOS Simulator,name=iPhone 17'`

## CI

GitHub Actions workflow (`.github/workflows/ci.yml`):
- Build and test on `macos-15` with Xcode 26.3
- SwiftLint on every push/PR to `main`
