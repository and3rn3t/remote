# Denon Remote — Roadmap

> A native iOS remote control app for Denon AVR receivers, built with SwiftUI, SwiftData, and iOS 26 Liquid Glass.

---

## Phase 1: Foundation & Project Hygiene ✅

Establish a solid project structure and development workflow.

- [x] `.gitignore` — Exclude DerivedData, xcuserdata, .DS_Store, build artifacts
- [x] `.swiftlint.yml` — Enforce code style (line length, force_cast/try, closures, modifiers)
- [x] `.swift-format` — Consistent formatting (4-space indent, no range operator spacing)
- [x] `Package.swift` — SPM-ready project for future dependency management
- [x] GitHub Actions CI — Build, test, and lint on every push/PR to `main`
- [x] Remove template artifacts (`Item.swift`)
- [x] Scaffold unit tests (DenonReceiver model, DenonAPI parsing, input sources)
- [x] Scaffold UI tests (launch, navigation, add receiver flow)

---

## Phase 2: Production Hardening ✅

Make the app reliable enough for daily use.

### Connection Robustness

- [x] TCP connection timeout (configurable, default ~5 seconds)
- [x] Automatic reconnection with exponential backoff
- [x] Proper `disconnect()` cleanup on view disappear and app background
- [x] Connection state monitoring (detect dropped connections)

### Input Validation

- [x] IP address format validation in add-receiver sheet
- [x] Port range validation (1–65535)
- [x] Inline validation errors in the form
- [x] Prevent duplicate receiver entries (same IP + port)

### Error Handling

- [x] Richer error types: `timeout`, `connectionRefused`, `invalidResponse`, `disconnected`
- [x] User-facing error messages with actionable guidance
- [x] Retry affordance on connection failure
- [x] Graceful degradation when receiver is unreachable

### Accessibility

- [x] VoiceOver labels on all Liquid Glass buttons and controls
- [x] Volume slider accessibility value descriptions ("Volume: 45 dB")
- [ ] Dynamic Type support verification
- [ ] Reduce transparency support for glass effects

---

## Phase 3: Auto-Discovery ✅

Eliminate manual IP entry by finding receivers on the local network.

- [x] `BonjourDiscovery.swift` — `NWBrowser`-based scanner for Denon services
- [x] Research exact Bonjour service type (`_denon._tcp`, `_http._tcp`, or vendor-specific)
- [x] "Scan for Receivers" button in add-receiver sheet
- [x] Discovered receivers list with one-tap add
- [x] Auto-populate name and IP from discovered service metadata
- [x] `NSLocalNetworkUsageDescription` in Info.plist
- [x] `NSBonjourServices` in Info.plist
- [x] Fallback to manual entry when no receivers found
- [x] Background scanning with periodic refresh

---

## Phase 4: Settings & Preferences ✅

Build out the settings screen (placeholder already exists in ReceiverControlView).

- [x] Default volume limit (safety cap to prevent accidental loud output)
- [x] Auto-connect to last-used receiver on launch
- [x] Receiver edit/rename functionality
- [ ] Per-receiver custom names for input sources *(deferred — low priority)*
- [ ] App appearance preferences (if applicable beyond system setting) *(deferred — system default is sufficient)*

---

## Phase 5: Enhanced Controls ✅

Expand receiver control beyond basic power/volume/input.

### Zone 2/3 Support

- [x] Zone power control
- [x] Zone volume control
- [x] Zone input selection
- [x] Zone UI tabs or segmented control

### Surround Mode Selection

- [x] List available surround modes from receiver
- [x] Mode picker UI (Stereo, Dolby, DTS, Multi-Channel, etc.)
- [x] Current mode display in control view

### Now Playing

- [x] Query and display current media info (if supported by input source)
- [ ] Album art display (when available via network sources) *(deferred — requires HTTP API, not telnet)*
- [x] Transport controls for network sources (play/pause/skip)

---

## Phase 6: Polish & Distribution ✅

Prepare for TestFlight distribution.

- [x] Onboarding flow for first-time users (scan or manual add)
- [x] PrivacyInfo.xcprivacy manifest (UserDefaults API, local network)
- [x] Dead code cleanup (unused `glassNamespace`, `parseResponse` wrapper consolidation)
- [x] Favorites filtering — sort/filter receiver list by favorite status
- [x] Version management (semantic versioning, `CFBundleShortVersionString` 1.0.0)

---

## Phase 7: Diagnostics & Reliability ✅

Add observability and improve UX reliability.

- [x] `ConnectionLogger` — `@Observable` timestamped log store (connect, disconnect, command, response, error events)
- [x] Log viewer UI — scrollable, color-coded entries accessible from App Settings
- [x] Volume slider debouncing — only send command after 150ms pause in slider movement
- [x] Reconnection feedback — show attempt count and countdown to next retry
- [x] "Export Logs" share sheet for troubleshooting
- [x] Wire logging hooks into DenonAPI (command sent, response received, errors)

---

## Phase 8: Extended Receiver Controls ✅

Additional protocol commands for deeper control.

- [x] Sleep timer (`SLP030/060/090/120/OFF` + `SLP?`) — UI in Quick Actions
- [x] Tone/EQ controls (`PSBAS`/`PSTRE` for bass/treble) — slider UI
- [x] Dynamic Volume / Dynamic EQ toggles (`PSDYNVOL`, `PSDYNEQ`)
- [x] Tuner presets (`TPAN UP/DOWN`) — shown when tuner input is active
- [x] Receiver info query — firmware version and model name in settings

---

## Phase 9: Widgets (WidgetKit) ✅

Home Screen widgets for at-a-glance status and quick controls.

- [x] App Group entitlement (`group.dev.andernet.remote`) for shared data
- [x] Shared `ReceiverStatus` model for App Group UserDefaults
- [x] Widget extension target — `remoteWidgets`
- [x] Small widget: power status + receiver name
- [x] Medium widget: power + volume + input + interactive toggle (App Intent)
- [x] App writes last-known state to App Group on every state change

---

## Phase 10: Live Activities (ActivityKit) ✅

Now Playing on Lock Screen and Dynamic Island.

- [x] `NowPlayingActivity` — `ActivityAttributes` for track, artist, album, input
- [x] Start Live Activity when connected + playing on a network source
- [x] Lock Screen: track name, artist, transport controls (play/pause/skip)
- [x] Dynamic Island: compact = input icon + track; expanded = full transport
- [x] End activity on disconnect or input change away from network source
- [x] `NSSupportsLiveActivities = YES` in Info.plist

---

## Phase 11: Scenes & Presets ✅

Save and recall receiver configurations.

- [x] `ReceiverScene` SwiftData model — name, receiverID, snapshot (input, volume, surround, zones)
- [x] "Save Current Scene" button in Quick Actions
- [x] Scene list view — tap to recall, swipe to delete
- [x] Per-zone scene support — save/restore Zone 2/3 independently
- [x] Quick Scene buttons ("Movie Night", "Music", "Party")

---

## Phase 12: Siri Shortcuts & App Intents ✅

Voice control and Shortcuts app integration.

- [x] App Intents: `PowerOnIntent`, `SetVolumeIntent`, `SetInputIntent`, `ToggleMuteIntent`
- [x] Entity resolution — `ReceiverEntity` + `InputSourceEntity` discover receivers from SwiftData
- [x] Shortcuts app integration — intents appear in Shortcuts
- [x] Siri phrases: "Turn on the living room receiver", "Set volume to 40"
- [x] App Shortcuts — Spotlight suggestions via `RemoteAppShortcuts` provider

---

## Phase 13: Future Vision

Ideas for later exploration, not committed to the roadmap.

- **Apple Watch** — Companion app with quick controls (power, volume, mute)
- **macOS Catalyst / native** — Desktop remote control
- **Multi-receiver control** — Control multiple receivers simultaneously

---

## Phase 14: iCloud Sync ✅

Sync receiver list and scenes across devices via CloudKit.

- [x] iCloud container identifier (`iCloud.dev.andernet.remote`) in entitlements
- [x] SwiftData `ModelConfiguration` with `cloudKitDatabase: .automatic`
- [x] Automatic sync for `DenonReceiver` and `ReceiverScene` models
- [x] iCloud Sync status indicator in App Settings

---

## Phase 15: iPad Optimization ✅

Enhance the app for iPad's larger screen and hardware keyboard.

- [x] `NavigationSplitView` with `.balanced` style and column visibility control
- [x] `horizontalSizeClass` awareness in receiver row (port, volume limit on regular width)
- [x] Keyboard shortcuts: Cmd+N (add receiver), Cmd+, (settings), Cmd+P (power toggle)
- [x] Keyboard shortcuts: Cmd+Up/Down (volume), Cmd+M (mute), Cmd+R (refresh)

---

## Architecture Notes

| Component | Technology | Purpose |
|---|---|---|
| UI | SwiftUI + iOS 26 Liquid Glass | Control interface |
| Data | SwiftData | Receiver persistence |
| State | `@Observable` | Reactive state management |
| Network | CoreFoundation TCP sockets | Denon AVR protocol (telnet on port 23) |
| Concurrency | Swift async/await | Non-blocking I/O |
| Testing | Swift Testing + XCUITest | Unit and UI tests |
| CI/CD | GitHub Actions | Build, test, lint automation |
| Linting | SwiftLint | Code quality enforcement |
| Formatting | swift-format | Consistent code style |
