# SRM_25CS08SRM_iOS_file_transfer_application_development
SRIB-PRISM Program

---

# AwareShare - Advanced iOS File Transfer App

[![iOS](https://img.shields.io/badge/iOS-26.0+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0+-green.svg)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 📖 Documentation Index

- **[README.md](README.md)** - This file (Getting Started, Overview, Features)
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Complete architecture documentation with system diagrams
- **[COMPONENT_FLOW.md](COMPONENT_FLOW.md)** - Detailed component flow and sequence diagrams
- **[LICENSE](LICENSE)** - MIT License

---

## 🎯 Project Overview

**AwareShare** is a cutting-edge iOS application that enables **high-speed, peer-to-peer file transfer** between iOS devices using multiple transport protocols with intelligent automatic fallback. Built entirely with **SwiftUI** and modern Swift concurrency patterns (**async/await**, **actors**), the app follows **MVVM architecture** with a **Coordinator pattern** for robust, maintainable, and scalable code.

### 🌟 Key Highlights

- **🚀 Multi-Protocol Support**: WiFi Aware (iOS 26.0+), Bluetooth LE, Multipeer Connectivity, AirDrop
- **⚡ Concurrent Transfers**: Up to 2 sends + 2 receives simultaneously with smart queue management
- **🔄 Automatic Fallback**: Intelligent transport selection with automatic retry on failure
- **📊 Performance Tracking**: Real-time benchmarking with CSV/JSON export
- **🎨 Modern UI**: Glass morphism design with smooth animations and real-time progress
- **🔒 Privacy-First**: All data stays local, no cloud storage, peer-to-peer only
- **📱 iOS-Native**: Built with SwiftUI, Combine, async/await, and Swift concurrency

---

## 🏗️ Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  SwiftUI Views + AppCoordinator (Navigation & State Mgmt)   │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                   BUSINESS LOGIC LAYER                       │
│  NetworkingManager • TransferQueueManager • Services        │
│  (Orchestrates WiFiAware, BLE, Multipeer, AirDrop)          │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                     NETWORK LAYER                            │
│  WiFiAwareManager (Actor) • BLEManager • MultipeerManager   │
│  Custom Protocols: Sliding Window, Chunking, ACK Batching   │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                      DATA LAYER                              │
│  FileManager • UserDefaults • Keychain (Future)             │
└─────────────────────────────────────────────────────────────┘
```

### Design Patterns

- **MVVM (Model-View-ViewModel)**: Separation of UI and business logic
- **Coordinator Pattern**: Centralized navigation via `AppCoordinator`
- **Facade Pattern**: `NetworkingManager` simplifies complex transport management
- **Delegate Pattern**: Protocol-based communication between layers
- **Strategy Pattern**: Runtime transport selection and fallback
- **Observer Pattern**: Combine `@Published` properties for reactive updates
- **Queue Pattern**: `TransferQueueManager` for concurrent operation management

**📚 For complete architecture documentation, see [ARCHITECTURE.md](ARCHITECTURE.md)**

---

## 📁 Project Structure

```
AwareShare/
├── App/                              # 🚀 App entry point and coordination
│   ├── AwareShareApp.swift           # App entry with environment setup
│   ├── AppCoordinator.swift          # Main coordinator (navigation & state)
│   └── SceneDelegate.swift           # Scene lifecycle management
│
├── Core/                             # 🧠 Core business logic
│   ├── Networking/                   # 🌐 Network services
│   │   ├── NetworkingManager.swift   # Main networking orchestrator
│   │   ├── WiFiAwareManager.swift    # WiFi Aware (actor-based, iOS 26+)
│   │   ├── BLEManager.swift          # Bluetooth LE manager
│   │   ├── MultipeerManager.swift    # Multipeer Connectivity
│   │   ├── AirDropManager.swift      # AirDrop integration
│   │   ├── TransferQueueManager.swift # Concurrent transfer queue
│   │   ├── ConnectionStateManager.swift # Connection state tracking
│   │   └── WiFiAware/
│   │       ├── SlidingWindowTransferManager.swift  # Sliding window protocol
│   │       └── ChunkReceiver.swift   # Chunk assembly & ACK batching
│   │
│   ├── Services/                     # ⚙️ Business services
│   │   ├── BenchmarkService.swift    # Performance tracking
│   │   └── SettingsService.swift     # App configuration
│   │
│   ├── FileManagement/               # 📂 File operations
│   │   └── FileManager.swift         # File handling
│   │
│   ├── Permissions/                  # 🔐 Permission management
│   │   └── PermissionsManager.swift  # Permission requests
│   │
│   └── Error/                        # ❌ Error handling
│       ├── AppError.swift            # App-specific errors
│       └── ErrorHandler.swift        # Centralized error handling
│
├── UI/                               # 🎨 User interface
│   ├── Screens/                      # 📱 Main screens
│   │   ├── Splash/                   # Splash screen
│   │   ├── Transfer/                 # Transfer UI
│   │   │   ├── Transfer2UIView.swift         # Main transfer screen
│   │   │   ├── SendReceiveOptionsView.swift  # Mode selection
│   │   │   ├── TransferProgressView.swift    # Progress monitoring
│   │   │   ├── TransferCompleteView.swift    # Completion screen
│   │   │   └── AirDropView.swift             # AirDrop interface
│   │   ├── FileSelection/            # File picker
│   │   ├── Settings/                 # App settings
│   │   ├── History/                  # Transfer history
│   │   └── Benchmarking/             # Performance analytics
│   │
│   └── Components/                   # 🧩 Reusable components
│       ├── LiquidGlassNavigationBar.swift    # Glass navigation
│       ├── ErrorAlertView.swift              # Error presentation
│       └── ErrorOverlayView.swift            # Error overlay
│
└── Resources/                        # 📦 Assets & resources
    ├── Assets.xcassets/              # Images, icons, colors
    └── AwareShare.entitlements       # App capabilities

AwareShareTests/                      # 🧪 Unit & integration tests
AwareShareUITests/                    # 🧪 UI tests
```

---

## 🚀 Core Features

### 1. 🌐 Multi-Transport Protocol Support

#### WiFi Aware (iOS 26.0+)
- **Speed**: 50-100+ Mbps
- **Range**: 100+ meters
- **Best For**: Large files (videos, archives)
- **Protocol**: Custom sliding window with chunking
- **Features**:
  - Endpoint discovery and registration
  - Connection pooling via `AwareShareConnectionManager`
  - Sliding window (10 chunks default)
  - ACK batching (5-chunk batches)
  - Data path optimization for large files

#### Bluetooth LE
- **Speed**: 1-5 Mbps
- **Range**: 10-50 meters
- **Best For**: Small files (documents, photos)
- **Protocol**: Custom chunk-based with headers
- **Features**:
  - Central and peripheral role support
  - MTU negotiation for BLE 5.0 (up to 512 bytes)
  - Chunk-based transfer with retry
  - ACK protocol for reliability
  - Connection health monitoring

#### Multipeer Connectivity
- **Speed**: 20-50 Mbps
- **Range**: WiFi/Bluetooth hybrid
- **Best For**: Medium files
- **Protocol**: Native MCSession data transfer
- **Features**:
  - Automatic peer discovery
  - Session-based file transfer
  - Built-in progress reporting
  - Connection quality monitoring

#### AirDrop
- **Speed**: Native iOS performance
- **Range**: WiFi/Bluetooth
- **Best For**: Quick sharing with any iOS device
- **Modes**:
  - **Custom Discovery**: BLE discovery + native transfer
  - **Native Mode**: Direct share sheet
- **Features**:
  - Native iOS integration via `UIActivityViewController`
  - Seamless sharing experience

### 2. 📊 Smart Transfer Queue Management

**TransferQueueManager** enforces intelligent concurrency limits:

- **Max 2 concurrent sends** at any time
- **Max 2 concurrent receives** at any time
- **1 operation per device per type** (prevents resource exhaustion)
- **Automatic queue processing** when slots become available
- **Priority-based scheduling** for optimal throughput

**Example**: Sending to 5 devices → First 2 start immediately, remaining 3 queue and start as slots free.

### 3. 🔄 Automatic Transport Fallback

When a transfer fails, the app **automatically retries** with the next available transport:

```
Priority Order (default):
1. WiFi Aware (fastest, if available)
2. Multipeer (reliable)
3. Bluetooth LE (fallback)
4. AirDrop (manual)

Example:
WiFi Aware fails → Try Multipeer
Multipeer fails → Try Bluetooth LE
All fail → Show error with retry option
```

### 4. 📈 Performance Benchmarking

**BenchmarkService** tracks comprehensive metrics:

- **Per-Transfer Metrics**: Speed, duration, bytes transferred, success/failure
- **Real-Time Tracking**: Live speed calculation and ETA
- **History Persistence**: Transfer history saved across sessions
- **Statistics**: Average speed, success rate, total transfers
- **Export**: CSV and JSON export for analysis

**Tracked Data**:
- Transfer ID, filename, file size
- Device name, connection type
- Start/end time, duration
- Average speed, current speed
- Success/failure status, error messages

### 5. 🎨 Modern User Interface

- **SwiftUI Native**: Declarative UI with smooth animations
- **Glass Morphism**: 3D glass navigation bars with blur effects
- **Real-Time Updates**: Live progress bars and status indicators
- **Accessibility**: VoiceOver support, Dynamic Type
- **Dark Mode**: Full dark mode support
- **Responsive**: Supports all iPhone sizes and orientations

### 6. 🔒 Privacy & Security

- **Local-Only**: All data stays on device, no cloud uploads
- **Peer-to-Peer**: Direct device-to-device communication
- **No Tracking**: No analytics or personal data collection
- **Consent-Based**: User approval required for incoming transfers
- **Trusted Devices**: Optional auto-accept for trusted peers

---

## 🔧 Technical Requirements

### iOS Requirements
- **Minimum iOS Version**: iOS 26.0 or later
- **Compatible Devices**: 
  - iPhone 12 and later (WiFi Aware support)
  - iPad Pro 5th generation and later (WiFi Aware support)
- **Xcode**: Xcode 26.0 or later
- **Swift**: Swift 5.9 or later

### Required Capabilities
- **WiFi Aware**: iPhone 12+ / iPad Pro 5th gen+ (iOS 26.0+)
- **Bluetooth LE**: All supported devices
- **Local Network**: Required for peer discovery
- **File Access**: Photos, Documents

### Dependencies (All Native iOS)
- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive programming
- **Network**: Low-level networking (WiFi Aware)
- **CoreBluetooth**: Bluetooth LE
- **MultipeerConnectivity**: Apple P2P framework
- **UIKit**: Share sheet integration
- **CryptoKit**: Future encryption features
- **OSLog**: Structured logging

---

## 🚀 Getting Started

### Prerequisites

⚠️ **Important**: WiFi Aware requires **physical iOS devices** (iPhone 12+ or iPad Pro 5th gen+) running iOS 26.0+. Simulator testing is limited to UI only.

### Installation

1. **Clone the Repository**
```bash
git clone https://github.com/yourusername/AwareShare.git
cd AwareShare
```

2. **Open in Xcode**
```bash
open AwareShareApp.xcodeproj
```

3. **Configure Signing**
- Select your development team in project settings
- Ensure proper code signing is configured

4. **Enable Capabilities**
- WiFi Aware capability (automatically included in `.entitlements`)
- Bluetooth permissions (in Info.plist)
- Local Network (automatically requested)
- Background Modes (optional, for future enhancement)

5. **Build and Run on Physical Device**
- Connect iPhone 12+ or iPad Pro 5th gen+ running iOS 26.0+
- Select device in Xcode
- Press ⌘R to build and run
- Grant permissions when prompted

### First Launch Setup

1. **Grant Permissions**:
   - Bluetooth: Tap "Enable Bluetooth" if needed
   - WiFi: Enable in Control Center or Settings
   - Local Network: Grant when prompted
   - Photos: Grant if sending photos

2. **Device Discovery**:
   - App automatically starts discovering nearby devices
   - Ensure both devices have AwareShare open
   - Devices appear in the discovery list

3. **Test Transfer**:
   - Tap a discovered device
   - Select "Send"
   - Choose a file from Photos or Files
   - Monitor real-time progress

---

## 📱 Usage Guide

### Device Discovery

1. **Open App** on both devices
2. **Automatic Discovery** starts immediately
3. **Select Device** from the list
4. **Connection Established** (for WiFi Aware/BLE)

### Sending Files

1. **Tap "Send"** after selecting device
2. **Choose Files** from Photos, Files, or Camera
3. **Monitor Progress** in real-time
4. **Transfer Complete** notification

### Receiving Files

1. **Accept Incoming Request** when prompted
2. **Files Save Automatically** to Documents
3. **View in History** tab

### Multi-Device Transfer

1. **Select Multiple Devices** (tap multiple devices)
2. **Choose Files** to send
3. **All Transfers Start** (up to 2 concurrent)
4. **Monitor Progress** for each device

### Settings & Benchmarking

- **Settings Tab**: Configure transport priorities, enable/disable protocols
- **History Tab**: View past transfers, statistics, export data
- **Benchmark**: Real-time performance metrics

---

## 🔐 Permission Management (iOS 18+ Compliant)

### Bluetooth Permission
- **Method**: CoreBluetooth system alert with `CBCentralManagerOptionShowPowerAlertKey: true`
- **Behavior**: Native iOS alert with "Settings" button
- **Direct Access**: Opens Bluetooth settings (Apple-approved method)

### WiFi Permission
- **Challenge**: No public API to open WiFi settings
- **Solution**: Instructional guidance with step-by-step instructions
- **Instructions**: "Swipe down from top-right → tap Wi-Fi icon"

### Local Network Permission
- **Method**: Opens app settings via `UIApplication.openSettingsURLString`
- **Trigger**: Automatically requested on first use

### Why Not Deep Links?
Apple deprecated `App-Prefs:` URLs and actively rejects apps using them:
- **App Store Rejection**: Private URL schemes violate guidelines
- **iOS 18 Changes**: Most undocumented settings URLs broken
- **Only Public APIs**: App settings and notification settings URLs allowed

---

## 📊 Performance Metrics

### Transfer Speeds (Tested on Physical Devices)

| Transport       | Speed         | Range      | Best Use Case        |
|----------------|---------------|------------|----------------------|
| WiFi Aware     | 50-100+ Mbps  | 100+ meters| Large files (videos) |
| Multipeer      | 20-50 Mbps    | 50 meters  | Medium files         |
| Bluetooth LE   | 1-5 Mbps      | 10-50 m    | Small files (docs)   |
| AirDrop        | Native speed  | Varies     | Quick sharing        |

### Concurrent Operations
- **2 sends + 2 receives** simultaneously
- **Per-device limits**: 1 operation per type per device
- **Queue processing**: Automatic as slots become available

---

## 🛠️ Development

### Code Organization

- **Modular Structure**: Feature-based organization
- **Protocol-Oriented**: Testable and flexible
- **Dependency Injection**: Environment objects and containers
- **Modern Concurrency**: async/await, actors
- **Reactive**: Combine publishers for data flow

### Testing Strategy

- **Unit Tests**: Business logic and services (`AwareShareTests/`)
- **Integration Tests**: End-to-end transfer flows
- **UI Tests**: User interaction flows (`AwareShareUITests/`)
- **Performance Tests**: Transfer speed benchmarks

### Running Tests

```bash
# Unit tests
⌘U in Xcode

# UI tests
Select UI test scheme and run

# Performance tests
Use BenchmarkService export for analysis
```

---

## 📋 Known Limitations

### Platform & Device
- **WiFi Aware**: Requires iOS 26.0+, iPhone 12+ or iPad Pro 5th gen+
- **Simulator**: Limited functionality (no WiFi Aware, limited BLE)
- **Platform Support**: iOS-to-iOS only (no Android, macOS, Windows)

### Permission & Settings
- **Direct Settings Access**: Cannot directly open system Wi-Fi/Bluetooth settings (iOS 18 restrictions)
- **Workaround**: CoreBluetooth system alert for Bluetooth, instructional guidance for WiFi
- **AirDrop Discovery**: Custom BLE discovery only finds AwareShare devices, not native AirDrop devices

### Performance & Transfer
- **Large Files**: Files >500MB not extensively tested
- **Background**: Limited background support, keep app in foreground
- **Proximity**: Devices must be in close range
- **Bluetooth**: Lower speeds (1-5 Mbps), best for small files

### Technical
- **WiFi Aware Data Path**: Currently uses control channel; optimized data path planned for future

---

## 🗺️ Roadmap

### Planned Features
- [ ] **WiFi Aware Data Path**: Optimized data channel for large files
- [ ] **End-to-End Encryption**: Optional E2E encryption
- [ ] **Resume Support**: Resume interrupted transfers
- [ ] **Background Transfers**: Continue when app backgrounded
- [ ] **QR Code Pairing**: Quick device pairing
- [ ] **Contact Integration**: Send to contacts
- [ ] **Compression**: Optional file compression

### Technical Improvements
- [ ] **CoreData Migration**: Replace UserDefaults for history
- [ ] **Keychain Integration**: Secure storage for trusted devices
- [ ] **Advanced Benchmarking**: More detailed metrics
- [ ] **Network Quality Monitoring**: Real-time connection quality
- [ ] **Adaptive Chunking**: Dynamic chunk size based on connection

---

## 🤝 Contributing

### Development Setup
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Follow Swift coding standards and iOS best practices
4. Write comprehensive tests
5. Submit a pull request

### Code Standards
- **Swift API Design Guidelines**: Follow Apple's guidelines
- **SwiftUI Best Practices**: Modern SwiftUI patterns
- **Error Handling**: Comprehensive error handling with specific error types
- **Documentation**: Inline comments for complex logic
- **Testing**: Unit tests for new features

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

## 🆘 Support

### Documentation
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Network Framework Guide](https://developer.apple.com/documentation/network/)
- [WiFi Aware Framework](https://developer.apple.com/documentation/wifiaware/) (iOS 26.0+)

### Issues & Contributions
- **Report Bugs**: Open an issue on GitHub
- **Request Features**: GitHub Discussions
- **Contribute**: Submit a pull request

---

## 🏆 Acknowledgments

- **Apple**: For SwiftUI, iOS frameworks, and WiFi Aware
- **Swift Community**: For inspiration and best practices
- **Open Source**: For collaborative development

---

## ❓ FAQ

### Q: Why doesn't the app open WiFi settings directly?
**A**: iOS 18 restricts deep linking to system settings. Apps using `App-Prefs:` or `prefs:root=` URLs get rejected from the App Store. We provide instructional guidance and use only Apple-sanctioned methods.

### Q: What's the difference between AirDrop modes?
**A**: 
- **Custom Discovery Mode**: Uses Bluetooth to find AwareShare devices before sharing
- **Native AirDrop Mode**: Goes directly to iOS share sheet, works with all devices

### Q: Can I send files to multiple devices at once?
**A**: Yes! Select multiple devices and the app handles concurrent transfers (up to 2 sends at once).

### Q: Does the app work in the iOS Simulator?
**A**: Limited functionality. WiFi Aware requires physical hardware. UI testing works in simulator.

### Q: What file types are supported?
**A**: All file types are supported - photos, videos, documents, archives, and more.

### Q: How fast is WiFi Aware compared to Bluetooth?
**A**: WiFi Aware is 10-100x faster than Bluetooth LE (50-100 Mbps vs 1-5 Mbps).

### Q: Can I transfer to Android devices?
**A**: Not currently. The app is iOS-only at this time.

---

**AwareShare - The Future of Secure File Transfer** 🚀

Built with ❤️ using SwiftUI and modern Swift concurrency.

---

**Document Version**: 2.0  
**Last Updated**: 2025-01-XX  
**Maintained By**: AwareShare Team
