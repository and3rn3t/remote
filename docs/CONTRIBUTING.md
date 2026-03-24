# Contributing to Denon Remote

Thanks for your interest in contributing! This guide will help you get started.

## Development Setup

### Requirements

- **macOS**: 15.0 or later (for Xcode 26)
- **Xcode**: 26.0 or later
- **SwiftLint**: Install via `brew install swiftlint`
- **xcpretty** (optional): Install via `gem install xcpretty`

### Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/and3rn3t/remote.git
   cd remote
   ```

2. **Open the project**
   ```bash
   open remote/remote.xcodeproj
   ```

3. **Select a simulator**
   - In Xcode, choose `iPhone 17 Pro` or similar iOS 26+ simulator

4. **Build and run**
   - Press `⌘R` to build and run
   - Press `⌘U` to run tests

## Development Workflow

### Code Style

This project follows strict Swift style guidelines enforced by SwiftLint:

- **Indentation**: 4 spaces (no tabs)
- **Line length**: 160 characters (warning), 200 (error)
- **Naming**: Use descriptive names; avoid single-letter variables (except `i`, `x`, `y`, `id`)
- **Force unwraps**: Avoid `!` — use optional binding or `guard` instead
- **Concurrency**: Use `async`/`await` throughout — no completion handlers or Combine

Run the linter before committing:
```bash
swiftlint lint --strict
```

Auto-fix issues when possible:
```bash
swiftlint --fix
```

### Swift Testing

- Use **Swift Testing** framework (`@Test`, `#expect`) for new unit tests
- Add tests to `remote/remoteTests/remoteTests.swift`
- Test naming: `func testFeatureScenario()` or `@Test func featureScenario()`

Example:
```swift
@Test func parseVolumeResponse() {
    let api = DenonAPI()
    api.parseResponseForTesting("MV45\r")
    #expect(api.state.volume == 45)
}
```

Run tests from CLI:
```bash
xcodebuild test \
  -project remote/remote.xcodeproj \
  -scheme remote \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  CODE_SIGNING_ALLOWED=NO
```

### UI Testing

- UI tests live in `remote/remoteUITests/remoteUITests.swift`
- Use XCTest for UI tests (Swift Testing doesn't support UI testing yet)
- Test user flows: navigation, forms, button interactions

### Documentation

- Add DocC-style comments to public APIs:
  ```swift
  /// Brief description.
  ///
  /// Detailed explanation of the function/class/struct.
  ///
  /// - Parameter param: Description of parameter.
  /// - Returns: Description of return value.
  /// - Throws: Description of errors that can be thrown.
  func myFunction(param: String) async throws -> Int { }
  ```

- Keep `CLAUDE.md` updated with architectural changes
- Update `ROADMAP.md` when completing features

## Architecture Guidelines

### State Management

- Use `@Observable` (Swift Observation) for reactive state
- **Never use** `ObservableObject` or `@Published` (this is an iOS 26+ project)
- `DenonAPI` is the single source of truth for receiver state
- SwiftData models persist receivers and scenes
- App Group `UserDefaults` syncs state to widgets/Live Activities

### Networking

- Use raw TCP sockets (`InputStream`/`OutputStream`) for main app
- Use `NWConnection` for lightweight widget/intent commands
- All network I/O must be `async`
- Commands are throttled (50ms minimum between sends)
- Responses are parsed asynchronously in a stream

### UI Patterns

- Use iOS 26 Liquid Glass design:
  - `GlassEffectContainer` for grouped glass elements
  - `.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))` for buttons
  - `.glassEffect(.regular.tint(.color).interactive(), ...)` for active states
- Add haptic feedback to interactive controls
- Include VoiceOver accessibility labels

### Denon Protocol

- Commands terminate with `\r` (carriage return)
- Volume range: 0–98 (maps to 0.0–98.0 dB)
- Zone commands: `Z2<cmd>` for Zone 2, `Z3<cmd>` for Zone 3
- Query current state: append `?` (e.g., `PW?`, `MV?`)
- See `DenonConstants.swift` for input codes and surround modes

## Pull Request Process

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Write clean, well-documented code
   - Add tests for new functionality
   - Run SwiftLint and fix any issues

3. **Test thoroughly**
   - Run unit tests: `⌘U` in Xcode
   - Test on both iPhone and iPad simulators
   - Verify accessibility with VoiceOver enabled

4. **Update documentation**
   - Update `CHANGELOG.md` under `[Unreleased]`
   - Add DocC comments to new public APIs
   - Update `ROADMAP.md` if completing roadmap items

5. **Commit with clear messages**
   ```bash
   git commit -m "feat: add album art display for network sources"
   git commit -m "fix: prevent volume slider from sending duplicate commands"
   git commit -m "docs: add DocC comments to DenonAPI"
   ```

   Use conventional commit prefixes:
   - `feat:` — New feature
   - `fix:` — Bug fix
   - `docs:` — Documentation changes
   - `test:` — Test additions or fixes
   - `refactor:` — Code refactoring
   - `style:` — Formatting, linting
   - `chore:` — Build, CI, or maintenance

6. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```
   - Open a pull request on GitHub
   - Describe what changed and why
   - Link to any related issues

7. **CI must pass**
   - GitHub Actions will run build, test, and lint
   - Fix any failures before requesting review

## Project Structure

```
remote/
├── SharedModels/            # Shared Swift package
│   └── Sources/SharedModels/
│       ├── ReceiverStatus.swift       # App Group state
│       ├── NowPlayingAttributes.swift # Live Activity
│       └── DenonCommandSender.swift   # Lightweight TCP
├── remote/                  # Main app target
│   ├── remoteApp.swift
│   ├── DenonAPI.swift       # Core TCP client
│   ├── DenonReceiver.swift  # SwiftData model
│   ├── DenonConstants.swift # Protocol constants
│   ├── ContentView.swift    # Master-detail UI
│   ├── ReceiverControlView.swift
│   ├── [other views]
│   ├── ReceiverIntents.swift # Siri Shortcuts
│   └── AppShortcuts.swift
├── remoteWidgets/           # WidgetKit extension
├── remoteTests/             # Unit tests
└── remoteUITests/           # UI tests
```

## Common Tasks

### Adding a New Denon Command

1. Add protocol constant to `DenonConstants.swift`
2. Add parsing logic to `DenonAPI.parseResponse()`
3. Add command sender method to `DenonAPI`
4. Add UI control to relevant view
5. Add unit test to `remoteTests.swift`

### Adding a New Widget

1. Create widget struct in `remoteWidgets/`
2. Implement `Widget` protocol
3. Add to `remoteWidgetsBundle`
4. Update `ReceiverStatus` in `SharedModels` if needed
5. Test on Home Screen and Lock Screen

### Adding a New App Intent

1. Create intent struct conforming to `AppIntent`
2. Implement `perform()` method
3. Add to `AppShortcuts.swift` for Siri phrases
4. Test via Siri and Shortcuts app

## Need Help?

- **Issues**: Check [GitHub Issues](https://github.com/and3rn3t/remote/issues)
- **Questions**: Open a discussion or issue
- **Bugs**: Open an issue with steps to reproduce

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.
