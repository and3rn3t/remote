# CLAUDE.md — Denon Remote

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

## Build & Test

```bash
# Build
xcodebuild build \
  -project remote/remote.xcodeproj \
  -scheme remote \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO

# Test
xcodebuild test \
  -project remote/remote.xcodeproj \
  -scheme remote \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO

# Lint
swiftlint lint --strict
```

## Project Structure

```
remote/
├── remote/                  # Main app target
│   ├── remoteApp.swift      # Entry point, SwiftData container
│   ├── DenonAPI.swift       # @Observable TCP client, protocol implementation
│   ├── DenonReceiver.swift  # SwiftData model
│   ├── DenonConstants.swift # Protocol constants, input/surround maps
│   ├── ReceiverScene.swift  # SwiftData scene/preset model
│   ├── ReceiverStatus.swift # Codable App Group shared state
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
│   ├── TogglePowerIntent.swift
│   ├── ReceiverStatus.swift      # Shared model (duplicate)
│   └── NowPlayingAttributes.swift
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
- SwiftData models use `.automatic` CloudKit configuration
- Widget/Intent targets use lightweight `NWConnection` TCP — not `DenonAPI`

### Testing

- Unit tests live in `remoteTests/remoteTests.swift`
- UI tests live in `remoteUITests/remoteUITests.swift`
- Use Swift Testing (`@Test`, `#expect`), not XCTest, for new unit tests
