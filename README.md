# Denon AVR Remote Control App

A modern iOS app for controlling Denon AV Receivers, built with iOS 26 design guidelines featuring Liquid Glass effects.

## Screenshots

| Receiver List | Control View | Now Playing | Zone Control | Settings |
|---|---|---|---|---|
| ![List](screenshots/list.png) | ![Control](screenshots/control.png) | ![Playing](screenshots/playing.png) | ![Zones](screenshots/zones.png) | ![Settings](screenshots/settings.png) |

*Take screenshots using the iOS Simulator or a real device, then save them to the `screenshots/` directory.*

## Features

### 🎨 iOS 26 Design Compliance

- **Liquid Glass Effects**: Modern glassmorphic UI elements that blur content behind them and react to touch
- **Interactive Glass Buttons**: Buttons with `.glass` and `.glassProminent` styles
- **GlassEffectContainer**: Properly grouped glass effects for optimal rendering
- **Customizable Toolbar**: Using the new `toolbar(id:)` API with unique item identifiers
- **Adaptive Layouts**: Split view on iPad, responsive layouts on iPhone
- **Keyboard Shortcuts**: ⌘N (new receiver), ⌘P (power), ⌘M (mute), ⌘R (refresh), ⌘↑/↓ (volume)
- **Haptic Feedback**: Tactile feedback on all interactive controls

### 🎛️ Receiver Control

- **Power Control**: Turn your receiver on/off
- **Volume Management**:
  - Slider for precise control with debouncing (150ms)
  - Quick up/down buttons
  - Mute toggle with visual feedback
  - Configurable volume safety limit (10–98 dB)
- **Input Selection**: Switch between 13 input sources (Blu-ray, Game, TV, Streaming, etc.)
- **Surround Mode Selection**: 18 surround modes (Stereo, Dolby, DTS, Multi-Channel, etc.)
- **Tone Controls**: Bass and treble sliders (±6 dB range)
- **Dynamic Audio**: Dynamic Volume (Off/Light/Medium/Heavy) and Dynamic EQ toggle
- **Sleep Timer**: Set 30/60/90/120-minute sleep timer
- **Real-time Status**: Live updates via state polling and health monitoring
- **Quick Actions**: Refresh state, save/recall scenes, access settings

### 🔊 Multi-Zone Support

- **Zone 2/3 Control**: Independent power, volume, mute, and input per zone
- **Zone Picker**: Segmented control to switch between Main/Zone 2/Zone 3

### 🎵 Now Playing

- **Media Info Display**: Track, artist, and album for network sources
- **Transport Controls**: Play, pause, stop, skip next, skip previous
- **Auto-Detection**: Automatically activates for network inputs (Spotify, Bluetooth, USB, NET, Media Player)

### 📡 Network Communication

- **TCP Connection**: Direct communication with Denon AVR via raw TCP sockets
- **Denon Protocol**: Implements the official Denon AVR command protocol
- **Async/Await**: Modern Swift Concurrency throughout
- **Auto-Reconnection**: Exponential backoff with jitter (up to 5 attempts)
- **Connection Health Monitoring**: 10-second polling interval with dropped connection detection
- **Command Throttling**: 50ms minimum between commands
- **Error Handling**: Rich error types (timeout, connectionRefused, invalidResponse, disconnected) with actionable guidance

### 📡 Auto-Discovery

- **Bonjour Scanning**: Automatic receiver discovery via `NWBrowser`
- **Service Types**: Scans `_denon._tcp` (primary) and `_http._tcp` (fallback)
- **One-Tap Add**: Discovered receivers auto-populate name and IP
- **Fallback**: Manual entry when no receivers found

### 🎬 Scenes & Presets

- **Save Scenes**: Capture current receiver configuration (input, volume, surround, mute)
- **Per-Zone Scenes**: Optionally include Zone 2/3 state
- **Quick Presets**: Movie Night, Music, Party, Gaming, Late Night, Morning
- **Recall**: Tap to instantly restore a saved configuration

### 💾 Data Management

- **SwiftData Integration**: Persistent storage of receivers and scenes
- **iCloud Sync**: Automatic CloudKit synchronization with in-memory fallback
- **Multiple Receivers**: Add and manage multiple AVRs
- **Connection History**: Tracks last connection time
- **Favorites**: Mark and filter frequently used receivers
- **Searchable List**: Filter receivers by name or IP

### 📱 Widgets (WidgetKit)

- **Small Widget**: Power status indicator (green/red dot) with receiver name
- **Medium Widget**: Receiver name, volume, input, last updated timestamp
- **Interactive Power Toggle**: Toggle power directly from the widget via App Intent
- **App Group Sharing**: Real-time state sync via shared `UserDefaults`

### 🔴 Live Activities (ActivityKit)

- **Lock Screen**: Track name, artist, album, play/pause icon, volume
- **Dynamic Island (Expanded)**: Full transport info with input icon
- **Dynamic Island (Compact)**: Input icon + track name
- **Auto-Lifecycle**: Starts when connected on a network source, ends on disconnect or input change

### 🗣️ Siri Shortcuts & App Intents

- **Power On/Off**: "Turn on the living room receiver"
- **Set Volume**: "Set volume to 40"
- **Switch Input**: "Switch input on living room receiver"
- **Toggle Mute**: "Mute the living room receiver"
- **Shortcuts App**: All intents available in the Shortcuts app
- **Spotlight Suggestions**: App Shortcuts appear in Spotlight

### 🔍 Diagnostics & Logging

- **Connection Logger**: Timestamped log of connect, disconnect, command, response, and error events
- **Log Viewer**: Scrollable, color-coded log entries with category filtering
- **Export Logs**: Share sheet for troubleshooting
- **Reconnection Feedback**: Attempt count and countdown to next retry

### 🚀 Onboarding

- **First-Launch Flow**: 3-page guided setup (Welcome, Network Access, Get Started)
- **Skippable**: Remembered via `hasCompletedOnboarding` flag

## Architecture

### Core Components

| File | Purpose |
|------|---------|
| **remoteApp.swift** | App entry point, SwiftData container, iCloud/CloudKit configuration |
| **DenonReceiver.swift** | SwiftData model — name, IP, port, favorites, volume limit, connection history |
| **DenonAPI.swift** | `@Observable` TCP client — Denon AVR protocol, auto-reconnect, state management |
| **DenonConstants.swift** | Protocol constants, input sources, surround modes, tone ranges, sleep timers |
| **ContentView.swift** | Master-detail `NavigationSplitView`, receiver list, search, favorites filter |
| **ReceiverControlView.swift** | Main control UI — zone picker, power, volume, inputs, surround, scenes, quick actions |
| **NowPlayingView.swift** | Track/artist/album display with transport controls |
| **ToneControlView.swift** | Bass/treble sliders with debouncing |
| **DynamicSettingsView.swift** | Dynamic EQ toggle, Dynamic Volume selector |
| **ZoneControlView.swift** | Reusable Zone 2/3 control panel — power, volume, mute, input |
| **SceneListView.swift** | Scene list with create/recall/delete |
| **ReceiverScene.swift** | SwiftData model — scene snapshots including optional Zone 2/3 |
| **SettingsView.swift** | Receiver settings (edit, volume limit, info) and app settings (auto-connect, logs, iCloud status) |
| **BonjourDiscovery.swift** | `NWBrowser`-based Bonjour scanner for Denon receivers |
| **ConnectionLogger.swift** | `@Observable` in-memory log store (500 entries) with export support |
| **OnboardingView.swift** | First-launch 3-page guided setup |
| **LogViewerView.swift** | Color-coded, filterable log viewer with share sheet |
| **ReceiverStatus.swift** | Codable struct for App Group state sharing with widgets |

### Siri & Widgets

| File | Purpose |
|------|---------|
| **ReceiverEntity.swift** | App Entity + Query for receiver discovery from SwiftData |
| **ReceiverIntents.swift** | App Intents — PowerOn, SetVolume, SetInput, ToggleMute |
| **AppShortcuts.swift** | App Shortcuts provider for Spotlight + Siri phrases |
| **NowPlayingActivity.swift** | ActivityKit Live Activity attributes + lifecycle manager |
| **remoteWidgets/** | WidgetKit extension — small/medium widgets, interactive power toggle |

## Denon AVR Protocol

The app uses the standard Denon AVR network protocol (typically port 23):

### Common Commands

- `PWON` / `PWSTANDBY` — Power control
- `MV00` to `MV98` — Set volume (0.0 to 98.0 dB)
- `MVUP` / `MVDOWN` — Volume adjustment
- `MUON` / `MUOFF` — Mute control
- `SI<code>` — Input selection (e.g., `SIBD`, `SIGAME`)
- `MS<code>` — Surround mode selection
- `SLP030/060/090/120/OFF` — Sleep timer
- `PSBAS 44–56` / `PSTRE 44–56` — Bass/treble tone control
- `PSDYNVOL OFF/LIT/MED/HEV` — Dynamic Volume
- `PSDYNEQ ON/OFF` — Dynamic EQ
- `TPANUP` / `TPANDOWN` — Tuner presets
- `NS9A`–`NS9E` — Transport controls (play/pause/stop/skip)
- `NSE` — Now playing query
- `Z2<cmd>` / `Z3<cmd>` — Zone 2/3 commands
- `PW?` / `MV?` / etc. — Query current state

### Supported Inputs

| Code | Input |
|------|-------|
| BD | Blu-ray |
| GAME | Game |
| MPLAY | Media Player |
| TV | TV Audio |
| SAT/CBL | Cable/Sat |
| DVD | DVD |
| AUX1 | AUX1 |
| AUX2 | AUX2 |
| TUNER | Tuner |
| BT | Bluetooth |
| USB/IPOD | USB/iPod |
| NET | Network |
| SPOTIFY | Spotify |

## Setup Instructions

### Requirements

- iOS 26.0 or later
- Xcode 26.0 or later
- Denon AVR with network control enabled
- Receiver and iPhone/iPad on the same network

### Getting Your Receiver's IP Address

1. On your Denon receiver, navigate to Settings → Network
2. Note the IP address (e.g., 192.168.1.100)
3. Ensure "Network Control" is enabled

### Adding a Receiver

1. Launch the app
2. Tap the "+" button
3. Enter receiver name (e.g., "Living Room")
4. Enter IP address from your receiver
5. Leave port as 23 (default) unless you've changed it
6. Tap "Add"

### Connecting

1. Select your receiver from the list
2. Tap "Connect" in the toolbar or the connection button
3. Once connected, all controls become active

## Design Features

### Liquid Glass Implementation

The app extensively uses iOS 26's Liquid Glass design:

```swift
// Interactive glass effect on buttons
.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))

// Tinted glass for active state
.glassEffect(.regular.tint(.purple).interactive(), in: .rect(cornerRadius: 12))

// Glass containers for grouped effects
GlassEffectContainer(spacing: 20.0) {
    // Multiple glass elements
}
```

### Modern SwiftUI Patterns

- **@Observable**: New observation framework for DenonAPI
- **Swift Concurrency**: Async/await throughout
- **SwiftData**: Modern data persistence
- **Customizable Toolbars**: New toolbar API with unique IDs
- **Glass Button Styles**: `.glass` and `.glassProminent`

## Troubleshooting

### Connection Issues

- Verify receiver is on the same WiFi network
- Check IP address is correct in receiver settings
- Ensure "Network Control" is enabled on receiver
- Try restarting the receiver
- Check firewall settings aren't blocking port 23

### Commands Not Working

- Ensure receiver supports the specific input/command
- Verify receiver firmware is up to date
- Try disconnecting and reconnecting
- Check receiver isn't in a restricted mode

## Future Enhancements

Potential features for future versions:

- [ ] Apple Watch companion app with quick controls (power, volume, mute)
- [ ] Album art display for network sources (requires HTTP API)
- [ ] Dynamic Type support verification
- [ ] Reduce transparency support for glass effects

## Technical Notes

### Network Protocol

The app uses raw TCP sockets (`CFStreamCreatePairWithSocketToHost` / `InputStream` / `OutputStream`) to communicate with the receiver on port 23. Each command is terminated with `\r` (carriage return). The receiver responds asynchronously, so the app polls for status updates with a 10-second health monitoring interval. Commands are throttled to a minimum 50ms interval.

### State Management

The `DenonAPI` class uses Swift's `@Observable` macro for reactive state updates. UI components automatically re-render when receiver state changes. Receiver state is also written to an App Group (`group.dev.andernet.remote`) for widget and Live Activity updates, with a 200ms debounce to coalesce rapid changes.

### Data Persistence

Receivers and scenes are stored using SwiftData with automatic iCloud/CloudKit synchronization. The app falls back to in-memory storage if CloudKit is unavailable. Widget state uses `UserDefaults` via the shared App Group.

### Error Handling

All network operations use structured error types (`DenonError`) with rich descriptions and recovery suggestions. Connection failures trigger automatic reconnection with exponential backoff and jitter.

### Testing

The project includes 70+ unit tests (Swift Testing framework) covering model defaults, response parsing (main zone, zone 2/3, now playing, tone, EQ, sleep timer, receiver info), and helper logic. UI tests cover launch, navigation, and the add receiver flow.

## Credits

Built with:

- SwiftUI & SwiftData
- Swift Concurrency (async/await)
- iOS 26 Liquid Glass design system
- Denon AVR network protocol

---

**Note**: This app requires a compatible Denon AV Receiver with network control capabilities. Check your receiver's manual for network control support.
