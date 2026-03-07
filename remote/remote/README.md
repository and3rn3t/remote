# Denon AVR Remote Control App

A modern iOS app for controlling Denon AV Receivers, built with iOS 26 design guidelines featuring Liquid Glass effects.

## Features

### 🎨 iOS 26 Design Compliance
- **Liquid Glass Effects**: Modern glassmorphic UI elements that blur content behind them and react to touch
- **Interactive Glass Buttons**: Buttons with `.glass` and `.glassProminent` styles
- **GlassEffectContainer**: Properly grouped glass effects for optimal rendering
- **Customizable Toolbar**: Using the new `toolbar(id:)` API with unique item identifiers
- **Adaptive Layouts**: Split view on iPad, responsive layouts on iPhone

### 🎛️ Receiver Control
- **Power Control**: Turn your receiver on/off
- **Volume Management**: 
  - Slider for precise control (0-80 dB range)
  - Quick up/down buttons
  - Mute toggle with visual feedback
- **Input Selection**: Switch between all common inputs (Blu-ray, Game, TV, Streaming, etc.)
- **Real-time Status**: Live updates of receiver state
- **Quick Actions**: Refresh state and access settings

### 📡 Network Communication
- **TCP Connection**: Direct communication with Denon AVR via network
- **Denon Protocol**: Implements the official Denon AVR command protocol
- **Async/Await**: Modern Swift Concurrency throughout
- **Error Handling**: Graceful error handling with user feedback

### 💾 Data Management
- **SwiftData Integration**: Persistent storage of receivers
- **Multiple Receivers**: Add and manage multiple AVRs
- **Connection History**: Tracks last connection time
- **Favorites**: Mark frequently used receivers

## Architecture

### Core Components

**DenonReceiver.swift**
- SwiftData model for storing receiver information
- Tracks name, IP address, port, favorites, and connection history

**DenonAPI.swift**
- Observable class managing network communication
- Implements Denon AVR protocol over TCP
- Provides async methods for all control functions
- Maintains receiver state

**ContentView.swift**
- Master-detail layout with NavigationSplitView
- Receiver list management
- Add receiver sheet

**ReceiverControlView.swift**
- Main control interface with Liquid Glass design
- Power, volume, input, and quick action controls
- Connection management
- Real-time state display

## Denon AVR Protocol

The app uses the standard Denon AVR network protocol (typically port 23):

### Common Commands
- `PWON` / `PWSTANDBY` - Power control
- `MV00` to `MV98` - Set volume (0.0 to 98.0 dB)
- `MVUP` / `MVDOWN` - Volume adjustment
- `MUON` / `MUOFF` - Mute control
- `SIBD` / `SIGAME` / etc. - Input selection
- `PW?` / `MV?` / etc. - Query current state

### Supported Inputs
- Blu-ray (BD)
- Game (GAME)
- Media Player (MPLAY)
- TV Audio (TV)
- Cable/Sat (SAT/CBL)
- DVD
- AUX1/AUX2
- Tuner
- Bluetooth (BT)
- USB/iPod
- Network (NET)
- Spotify

## Setup Instructions

### Requirements
- iOS 26.0 or later
- Xcode 16.0 or later
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
- [ ] Auto-discovery of receivers on network
- [ ] Scene/preset management
- [ ] Zone 2/3 control for multi-zone receivers
- [ ] Surround mode selection
- [ ] Now playing information
- [ ] Widget support
- [ ] Apple Watch companion app
- [ ] Siri Shortcuts integration
- [ ] Live Activities for volume control

## Technical Notes

### Network Protocol
The app uses raw TCP sockets (InputStream/OutputStream) to communicate with the receiver. Each command is terminated with `\r` (carriage return). The receiver responds asynchronously, so the app polls for status updates.

### State Management
The `DenonAPI` class uses Swift's new `@Observable` macro for reactive state updates. This ensures the UI automatically updates when the receiver's state changes.

### Error Handling
All network operations are wrapped in try/catch blocks with proper error propagation. Users receive clear feedback through alerts when operations fail.

## Credits

Built with:
- SwiftUI & SwiftData
- Swift Concurrency (async/await)
- iOS 26 Liquid Glass design system
- Denon AVR network protocol

---

**Note**: This app requires a compatible Denon AV Receiver with network control capabilities. Check your receiver's manual for network control support.
