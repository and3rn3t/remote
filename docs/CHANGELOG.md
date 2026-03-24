# Changelog

All notable changes to Denon Remote will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Code coverage reporting in CI pipeline
- CHANGELOG.md for version tracking

### Changed
- Updated CI workflow to use actions/checkout@v6 consistently

### Fixed
- CI workflow version mismatch between jobs

## [1.0.0] - 2026-03-08

### Added
- Initial release with full feature set
- **Core Control**: Power, volume, mute, input selection, surround mode
- **Multi-Zone Support**: Independent control for Main, Zone 2, Zone 3
- **Now Playing**: Track info and transport controls for network sources
- **Bonjour Discovery**: Automatic receiver scanning on local network
- **Scenes & Presets**: Save and recall receiver configurations
- **Widgets**: Small and medium Home Screen widgets with interactive power toggle
- **Live Activities**: Now Playing on Lock Screen and Dynamic Island
- **Siri & Shortcuts**: Voice control via App Intents (power, volume, input, mute)
- **iCloud Sync**: Automatic CloudKit synchronization across devices
- **Advanced Controls**: Sleep timer, tone controls (bass/treble), Dynamic EQ/Volume
- **Diagnostics**: Connection logger with filterable, exportable logs
- **iOS 26 Design**: Liquid Glass effects throughout the UI
- **Accessibility**: VoiceOver labels and haptic feedback
- **iPad Optimization**: Split view, keyboard shortcuts
- **Testing**: 70+ unit tests covering protocol parsing and model logic

### Technical
- Built with SwiftUI, SwiftData, and Swift Concurrency (async/await)
- Raw TCP socket communication with Denon AVR protocol (port 23)
- Auto-reconnection with exponential backoff and jitter
- Connection health monitoring and state polling
- Command throttling (50ms minimum between commands)
- Volume slider debouncing (150ms)
- App Group shared state for widgets and Live Activities
- SwiftLint and swift-format for code quality
- GitHub Actions CI for build, test, and lint
- Swift Testing framework for unit tests
- Comprehensive XCUITest suite for UI flows

---

## Version History

- [1.0.0] - 2026-03-08: Initial release
