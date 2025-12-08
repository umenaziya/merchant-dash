# AwareShare - Application Architecture Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Component Design](#component-design)
4. [Application Flow](#application-flow)
5. [Data Flow](#data-flow)
6. [Technical Stack](#technical-stack)
7. [Design Patterns](#design-patterns)

---

## System Overview

AwareShare is a modern iOS peer-to-peer file transfer application built with SwiftUI following the **MVVM (Model-View-ViewModel)** architectural pattern with a **Coordinator pattern** for navigation management. The app supports multiple transport protocols with intelligent fallback mechanisms and concurrent transfer operations.

### Core Capabilities
- **Multi-Protocol Support**: WiFi Aware, Bluetooth LE, Multipeer Connectivity, AirDrop
- **Concurrent Operations**: Up to 2 sends and 2 receives simultaneously
- **Smart Queue Management**: Priority-based transfer queue with per-device limits
- **Real-time Monitoring**: Live progress tracking and performance benchmarking
- **Modern UI/UX**: SwiftUI-based interface with glass morphism design

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PRESENTATION LAYER                              │
│                                  (SwiftUI)                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │   Splash     │  │   Transfer   │  │   Settings   │  │   History    │   │
│  │    View      │  │     View     │  │     View     │  │     View     │   │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │
│         │                  │                  │                  │            │
│         └──────────────────┴──────────────────┴──────────────────┘            │
│                                      ↓                                        │
│                          ┌───────────────────────┐                           │
│                          │   AppCoordinator      │                           │
│                          │  (Navigation & State) │                           │
│                          └───────────────────────┘                           │
│                                      ↓                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                       ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                              BUSINESS LOGIC LAYER                            │
│                            (ViewModels & Services)                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      NetworkingManager                               │   │
│  │                  (Main Orchestrator - @MainActor)                    │   │
│  │                                                                       │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐ │   │
│  │  │ WiFiAware   │  │     BLE     │  │  Multipeer  │  │  AirDrop  │ │   │
│  │  │  Manager    │  │   Manager   │  │   Manager   │  │  Manager  │ │   │
│  │  │   (Actor)   │  │ (@MainActor)│  │ (@MainActor)│  │(@MainActor)│ │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └───────────┘ │   │
│  │                                                                       │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │           TransferQueueManager (@MainActor)                  │   │   │
│  │  │  - Max 2 concurrent sends, 2 concurrent receives             │   │   │
│  │  │  - Per-device concurrency control (1 per type per device)    │   │   │
│  │  │  - Queue processing and state management                     │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                       │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │           ConnectionStateManager (@MainActor)                │   │   │
│  │  │  - Connection status tracking                                │   │   │
│  │  │  - Device connection monitoring                              │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
│  ┌──────────────────────┐        ┌─────────────────────────────────┐       │
│  │  BenchmarkService    │        │     SettingsService             │       │
│  │    (@MainActor)      │        │      (@MainActor)               │       │
│  │  - Transfer metrics  │        │  - App configuration            │       │
│  │  - History tracking  │        │  - Transport priority           │       │
│  │  - Performance stats │        │  - User preferences             │       │
│  └──────────────────────┘        └─────────────────────────────────┘       │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                       ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                              NETWORK LAYER                                   │
│                          (Transport Protocols)                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                      WiFi Aware Protocol Stack                        │  │
│  │  ┌────────────────────┐  ┌────────────────────┐  ┌───────────────┐  │  │
│  │  │ AwareShareConnection│  │  SlidingWindow     │  │  ChunkReceiver│  │  │
│  │  │     Manager         │  │  TransferManager   │  │               │  │  │
│  │  │  (Connection Pool)  │  │  (Sender-side)     │  │ (Receiver)    │  │  │
│  │  └────────────────────┘  └────────────────────┘  └───────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                      Bluetooth LE Protocol Stack                      │  │
│  │  ┌────────────────────┐  ┌────────────────────┐  ┌───────────────┐  │  │
│  │  │  CBCentralManager  │  │ CBPeripheralManager│  │  ChunkHeader  │  │  │
│  │  │   (Discovery)      │  │   (Advertising)    │  │  Protocol     │  │  │
│  │  └────────────────────┘  └────────────────────┘  └───────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │               Multipeer Connectivity Protocol Stack                   │  │
│  │  ┌────────────────────┐  ┌────────────────────┐                      │  │
│  │  │   MCNearbyService  │  │   MCSession        │                      │  │
│  │  │   Advertiser       │  │   (P2P Transfer)   │                      │  │
│  │  └────────────────────┘  └────────────────────┘                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                        AirDrop Integration                            │  │
│  │  ┌────────────────────┐  ┌────────────────────┐                      │  │
│  │  │ UIActivityViewController│ │  BLE Discovery  │                      │  │
│  │  │   (Native Share)   │  │  (Custom Mode)     │                      │  │
│  │  └────────────────────┘  └────────────────────┘                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                       ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DATA LAYER                                      │
│                        (Persistence & Storage)                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌──────────────────────┐        ┌─────────────────────────────────┐       │
│  │   UserDefaults       │        │     FileManager                 │       │
│  │  - App settings      │        │  - Temporary file storage       │       │
│  │  - Transfer history  │        │  - Documents directory          │       │
│  │  - User preferences  │        │  - Received files               │       │
│  └──────────────────────┘        └─────────────────────────────────┘       │
│                                                                               │
│  ┌──────────────────────┐        ┌─────────────────────────────────┐       │
│  │   Keychain (Future)  │        │     CoreData (Planned)          │       │
│  │  - Trusted devices   │        │  - Transfer history             │       │
│  │  - Security tokens   │        │  - Benchmarking data            │       │
│  └──────────────────────┘        └─────────────────────────────────┘       │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Design

### 1. Presentation Layer (UI)

#### AppCoordinator
- **Role**: Central navigation coordinator and state manager
- **Pattern**: Coordinator Pattern + MVVM
- **Responsibilities**:
  - Navigation flow management
  - Global state management
  - Screen transitions
  - Error handling coordination
  - Permission management
  - Multi-device transfer orchestration

**Key Properties**:
```swift
@Published var currentScreen: AppScreen
@Published var isTransitioning: Bool
@Published var selectedDevice: DiscoveredDevice?
@Published var transferMode: TransferMode?
@Published var activeTransfers: [String: TransferOperation]
@Published var networkingManager: NetworkingManager
@Published var connectionStateManager: ConnectionStateManager
```

#### SwiftUI Views
- **Transfer2UIView**: Main device discovery and transfer interface
- **AirDropView**: AirDrop-specific interface with mode selection
- **FileSelectionView**: File picker and selection interface
- **TransferProgressView**: Real-time progress monitoring
- **EnhancedSettingsView**: App configuration and preferences
- **TransferHistoryView**: Transfer history and analytics

### 2. Business Logic Layer

#### NetworkingManager (@MainActor)
- **Role**: Main networking orchestrator
- **Pattern**: Facade Pattern + Delegate Pattern
- **Responsibilities**:
  - Coordinate multiple transport managers
  - Device discovery aggregation
  - Connection management
  - Transfer routing and fallback
  - Progress tracking and reporting
  - Delegate event forwarding

**Key Methods**:
```swift
func startDiscovery() async
func connectToDevice(_ device: DiscoveredDevice) async throws
func sendFile(_ fileURL: URL, to device: ConnectedDevice) async throws
func sendFileToMultipleDevices(_ fileURL: URL, to devices: [ConnectedDevice]) async throws -> [String]
func receiveFile(from device: ConnectedDevice) async throws -> URL
func selectTransport(for device: ConnectedDevice) -> [ConnectionType]
```

#### Transport Managers

**WiFiAwareManager (Actor)**
- **Concurrency**: Actor-isolated for thread-safe access
- **Protocol**: Custom sliding window protocol with chunking
- **Features**:
  - Endpoint discovery and registration
  - Connection pooling via AwareShareConnectionManager
  - Sliding window file transfer (10-window default)
  - ACK batching (5-chunk batches)
  - Handshake timeout management
  - Data path optimization for large files

**BLEManager (@MainActor)**
- **Concurrency**: Main actor for CoreBluetooth requirements
- **Protocol**: Custom chunk-based protocol with headers
- **Features**:
  - Central and peripheral role support
  - Service advertising and scanning
  - MTU negotiation for BLE 5.0
  - Chunk-based transfer with retry
  - ACK protocol for reliability
  - Connection health monitoring

**MultipeerManager (@MainActor)**
- **Framework**: Apple MultipeerConnectivity
- **Protocol**: Native MCSession data transfer
- **Features**:
  - Service discovery and advertising
  - Automatic peer management
  - Session-based file transfer
  - Progress reporting
  - Connection quality monitoring

**AirDropManager (@MainActor)**
- **Integration**: UIActivityViewController + Custom BLE discovery
- **Modes**:
  - Native mode: Direct share sheet
  - Custom mode: BLE discovery + native transfer
- **Features**:
  - Discovery mode toggle
  - Native iOS share sheet integration
  - Device filtering and presentation

#### TransferQueueManager (@MainActor)
- **Role**: Concurrent transfer queue management
- **Pattern**: Queue Pattern + State Machine
- **Limits**:
  - Max 2 concurrent sends
  - Max 2 concurrent receives
  - Max 1 operation per device per type (send/receive)
- **Features**:
  - Operation enqueueing and scheduling
  - Progress tracking
  - State management (queued, active, completed, failed)
  - Automatic cleanup after completion
  - Notification on all transfers complete

**Queue Processing Logic**:
```swift
func processQueue() {
    // Process send operations
    while activeSendCount < maxConcurrentSends {
        // Find next queued send operation
        // Check per-device limits
        // Start operation if allowed
    }
    
    // Process receive operations
    while activeReceiveCount < maxConcurrentReceives {
        // Find next queued receive operation
        // Check per-device limits
        // Start operation if allowed
    }
}
```

#### BenchmarkService (@MainActor)
- **Role**: Performance tracking and analytics
- **Pattern**: Singleton Pattern
- **Features**:
  - Real-time metric tracking
  - Transfer history persistence
  - Statistics calculation
  - CSV/JSON export
  - Speed calculation and ETA estimation

**Tracked Metrics**:
- Transfer ID, filename, file size
- Start time, end time, duration
- Bytes transferred, average speed
- Connection type, device name
- Success/failure status

#### SettingsService (@MainActor)
- **Role**: Centralized configuration management
- **Pattern**: Singleton Pattern + @AppStorage
- **Configuration**:
  - Transport enable/disable flags
  - Transport priority order
  - Transfer settings (chunk size, timeouts)
  - WiFi Aware settings (window size, ACK batch)
  - Privacy settings (device name, avatar)
  - Permission guidance preferences

### 3. Network Layer

#### WiFi Aware Protocol Stack

**AwareShareConnectionManager (Actor)**
- **Role**: Connection pool manager
- **Features**:
  - Multiple simultaneous connections
  - Connection lifecycle management
  - Network event streaming
  - State update monitoring
  - Performance tracking

**SlidingWindowTransferManager**
- **Role**: Sender-side sliding window protocol
- **Algorithm**: Sliding window with ACK-based flow control
- **Features**:
  - Window size: 10 chunks (configurable)
  - Retry on timeout
  - Progress tracking
  - Concurrent chunk sending within window

**ChunkReceiver**
- **Role**: Receiver-side chunk assembly
- **Features**:
  - Out-of-order chunk handling
  - Missing chunk detection
  - ACK batching (every 5 chunks)
  - Progress calculation
  - Complete data reconstruction

#### Bluetooth LE Protocol Stack

**ChunkHeader Protocol**
```swift
struct ChunkHeader: Codable {
    let transferId: String
    let chunkIndex: Int
    let totalChunks: Int
}
```
- **Encoding**: JSON + 2-byte length prefix
- **Purpose**: Multi-transfer support per peripheral
- **Benefits**: Concurrent transfers on same connection

**MTU Negotiation**
- **Default**: 23 bytes (BLE 4.2)
- **Optimized**: Up to 512 bytes (BLE 5.0)
- **Fallback**: Conservative 247 bytes for reliability

**ACK Protocol**
```swift
struct AckMessage: Codable {
    let transferId: String
    let received: [Int]  // Array of received chunk indices
}
```

**Retry Logic**:
- Chunk timeout: 5 seconds
- Max retries: 3 per chunk
- Retry monitoring: Background task per transfer
- ACK-based retry prevention

### 4. Data Layer

#### File Storage
- **Temporary Storage**: NSTemporaryDirectory for in-progress files
- **Documents Storage**: Documents directory for received files
- **Cleanup**: Automatic cleanup on transfer completion and app termination

#### Persistence
- **UserDefaults**: Settings, preferences, transfer history
- **FileManager**: Received files, temporary files
- **Future**: Keychain for trusted devices, CoreData for history

---

## Application Flow

### 1. App Launch Flow
```
┌──────────────┐
│ AwareShareApp│
└──────┬───────┘
       │
       ↓
┌──────────────────┐
│ AppCoordinator   │ → Initialize NetworkingManager
│   (Initialize)   │ → Setup Delegates & Bindings
└──────┬───────────┘ → Show Splash Screen
       │
       ↓
┌──────────────────┐
│  Splash Screen   │ → Animation
└──────┬───────────┘ → Transition to Main
       │
       ↓
┌──────────────────┐
│ Permission Check │ → Check all permissions
└──────┬───────────┘ → Show popup if needed
       │
       ↓
┌──────────────────┐
│ Transfer2UIView  │ → Main interface
└──────────────────┘ → Start discovery
```

### 2. Device Discovery Flow
```
User Action: Open App
       │
       ↓
AppCoordinator.startDiscovery()
       │
       ↓
NetworkingManager.startDiscovery()
       │
       ├─────────────┬─────────────┬──────────────┐
       ↓             ↓             ↓              ↓
WiFiAwareManager  BLEManager  MultipeerManager  (AirDrop on-demand)
   .startDiscovery() .startDiscovery() .startDiscovery()
       │             │             │
       ↓             ↓             ↓
   Browse for    Scan for BLE   Advertise &
   Endpoints     Peripherals    Browse peers
       │             │             │
       └─────────────┴─────────────┘
                     ↓
       NetworkingManagerDelegate
       .didDiscoverDevice()
                     ↓
       AppCoordinator updates
       @Published discoveredDevices
                     ↓
         UI automatically updates
         (Combine @Published)
```

### 3. Connection Flow
```
User Action: Tap Device
       │
       ↓
AppCoordinator.showDeviceSelection(device)
       │
       ├──────────────────────────────┬──────────────────┐
       │                              │                  │
requiresExplicitConnection?      AirDrop/Multipeer   Other
   (WiFiAware, BLE)             (No explicit connect)
       │                              │
       ↓                              ↓
establishConnection()          showSendReceiveOptions()
       │
       ↓
NetworkingManager.connectToDevice()
       │
       ↓
Transport-specific connection
       │
       ├─────────────┬─────────────┐
       ↓             ↓             ↓
WiFiAware:     BLE:          Multipeer:
setupConnection()  connect()    invite()
       │             │             │
       └─────────────┴─────────────┘
                     ↓
       NetworkingManagerDelegate
       .didConnectToDevice()
                     ↓
       AppCoordinator updates
       @Published connectedDevices
                     ↓
       showSendReceiveOptions()
```

### 4. File Transfer Flow (Send)
```
User Action: Select "Send"
       │
       ↓
AppCoordinator.showFileSelection(mode: .send)
       │
       ↓
FileSelectionView presented
       │
User selects files
       │
       ↓
AppCoordinator.selectedFiles = [URLs]
       │
       ↓
NetworkingManager.sendFile(fileURL, to: device)
       │
       ↓
TransferQueueManager.enqueueOperation()
       │
       ├─ Check limits (max 2 sends, 1 per device)
       ├─ Add to queue
       └─ processQueue()
              │
              ↓
     Start operation execution
              │
              ↓
     selectTransport(for: device)
     → Priority: [device.connectionType, ...other enabled]
              │
              ↓
     Try each transport in order
              │
     ├──────────────┬──────────────┬────────────┐
     ↓              ↓              ↓            ↓
WiFiAware:      BLE:          Multipeer:    AirDrop:
sendFile()      sendFile()    sendFile()    present share sheet
     │              │              │            │
     ↓              ↓              ↓            ↓
Sliding Window  Chunk-based   MCSession     Native iOS
Protocol        with ACKs     streaming     AirDrop
     │              │              │            │
     └──────────────┴──────────────┴────────────┘
                     ↓
       Progress updates via delegate
       .didUpdateTransferProgress()
                     ↓
       TransferQueueManager updates
       @Published transferProgress
                     ↓
         UI updates in real-time
                     ↓
       Transfer completes
                     ↓
       TransferQueueManager.completeOperation()
                     ↓
       BenchmarkService.completeTransfer()
                     ↓
       Notification: .allTransfersComplete
       (if all done)
```

### 5. Multi-Device Transfer Flow
```
User Action: Select Multiple Devices
       │
       ↓
AppCoordinator.toggleDeviceSelection() for each
       │
       ↓
AppCoordinator.selectedDevices = [devices]
       │
       ↓
User selects files
       │
       ↓
NetworkingManager.sendFileToMultipleDevices()
       │
       ├─ Connect to all devices (if needed)
       └─ For each device:
              │
              ↓
          NetworkingManager.sendFile()
          → Unique transferId per device
              │
              ↓
          TransferQueueManager.enqueueOperation()
          → Each transfer independently queued
              │
              ↓
          Queue processes based on limits
          → Up to 2 concurrent sends
          → 1 per device per type
              │
              └─────────────────────────────┐
                                            ↓
                            All transfers tracked independently
                            in activeTransfers dictionary
                                            │
                                            ↓
                            Progress updates per transfer ID
                                            │
                                            ↓
                            UI shows all active transfers
                                            │
                                            ↓
                            Notification when all complete
```

### 6. Receive Flow
```
Remote Device: Sends file transfer request
       │
       ↓
NetworkEvent.fileTransferRequest received
       │
       ↓
ConsentPrompting.didRequestFileTransfer()
       │
       ↓
UIAlertController presented
"Accept" or "Reject"
       │
       ├──────────────┐
       ↓              ↓
   Accepted       Rejected
       │              │
       ↓              ↓
Send .fileTransferAccept  Send .fileTransferReject
       │                        │
       ↓                        └─ End
Initialize ChunkReceiver
       │
       ↓
Receive chunks
       ├─ Store out-of-order
       ├─ Send ACKs (batch of 5)
       └─ Update progress
              │
              ↓
All chunks received
       │
       ↓
Reconstruct file
       │
       ↓
Save to Documents directory
       │
       ↓
NetworkingManagerDelegate.didReceiveFile()
       │
       ↓
Show completion notification
```

---

## Data Flow

### State Management
```
User Interaction
       │
       ↓
   View Layer (SwiftUI)
       │
       ↓
AppCoordinator (@Published properties)
       │
       ├─ Combine Publishers
       ├─ @StateObject
       └─ @EnvironmentObject
              │
              ↓
Service Layer (NetworkingManager, etc.)
       │
       ├─ Async/await operations
       ├─ Delegates
       └─ Combine Publishers
              │
              ↓
Network Layer (Transport Managers)
       │
       ├─ Actor isolation (WiFiAware)
       ├─ @MainActor (BLE, Multipeer)
       └─ Async streams
              │
              ↓
Protocol Implementation
       │
       └─ CoreBluetooth, Network, MultipeerConnectivity
```

### Progress Tracking Flow
```
Transport Manager
       │
       ↓
didUpdateTransferProgress(progress, transferId)
       │
       ↓
NetworkingManager
       │
       ├─ TransferQueueManager.updateProgress()
       ├─ BenchmarkService.updateProgress()
       └─ Delegate forwarding
              │
              ↓
AppCoordinator
       │
       ├─ @Published transferProgress updated
       └─ Combine publishers notify
              │
              ↓
SwiftUI View (TransferProgressView)
       │
       └─ Progress bars update automatically
```

### Error Handling Flow
```
Error occurs in Transport Manager
       │
       ↓
throw NetworkError / completion with error
       │
       ↓
NetworkingManager catches
       │
       ├─ Log error
       ├─ Try next transport (if fallback available)
       └─ Report to delegate
              │
              ↓
AppCoordinator.showError()
       │
       ├─ currentError = AppError
       ├─ retryAction closure (if applicable)
       └─ Trigger UI update
              │
              ↓
ErrorOverlayView presented
       │
       ├─ Show error message
       ├─ "Retry" button (if retryAction exists)
       └─ "Dismiss" button
```

---

## Technical Stack

### Frameworks & APIs
- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive programming and data flow
- **Network**: Low-level networking (WiFi Aware)
- **CoreBluetooth**: Bluetooth LE communication
- **MultipeerConnectivity**: Apple P2P framework
- **UIKit**: Share sheet integration (AirDrop)
- **Foundation**: Core utilities and file management
- **OSLog**: Structured logging
- **CryptoKit**: Future security features

### Concurrency Model
- **async/await**: Modern Swift concurrency
- **Actors**: Thread-safe state management (WiFiAwareManager)
- **@MainActor**: UI thread isolation (most managers)
- **Task Groups**: Parallel discovery operations
- **AsyncStream**: Event streaming from Network framework

### Data Persistence
- **@AppStorage**: Settings and preferences (UserDefaults wrapper)
- **UserDefaults**: Transfer history, benchmark data
- **FileManager**: Temporary files, documents directory
- **Future**: Keychain (trusted devices), CoreData (history)

---

## Design Patterns

### 1. Coordinator Pattern
**Implementation**: `AppCoordinator`
- Centralized navigation logic
- Screen flow management
- Global state coordination
- Deep linking support

### 2. MVVM (Model-View-ViewModel)
**Implementation**: Throughout app
- **Models**: `DiscoveredDevice`, `ConnectedDevice`, `TransferOperation`
- **Views**: All SwiftUI views
- **ViewModels**: `AppCoordinator`, `NetworkingManager`
- **Binding**: Combine @Published properties

### 3. Facade Pattern
**Implementation**: `NetworkingManager`
- Simplified interface to complex subsystems
- Hides multiple transport manager complexity
- Unified API for file transfer operations

### 4. Delegate Pattern
**Implementation**: `NetworkingManagerDelegate`, `ConsentPrompting`
- Protocol-based communication
- Loose coupling between layers
- Event forwarding and notifications

### 5. Singleton Pattern
**Implementation**: `BenchmarkService`, `SettingsService`
- Shared instance for app-wide access
- Global state management
- Single source of truth

### 6. Strategy Pattern
**Implementation**: Transport selection and fallback
- Multiple algorithms (WiFiAware, BLE, Multipeer, AirDrop)
- Runtime transport selection
- Automatic fallback on failure

### 7. Observer Pattern
**Implementation**: Combine publishers
- @Published properties
- Reactive data flow
- Automatic UI updates

### 8. Factory Pattern
**Implementation**: Device discovery and creation
- `DiscoveredDevice` creation from different sources
- Transport-specific connection objects
- Unified device model

### 9. Queue Pattern
**Implementation**: `TransferQueueManager`
- Operation queuing and scheduling
- Concurrency limits enforcement
- Priority-based processing

### 10. State Machine Pattern
**Implementation**: Transfer states
```swift
enum TransferState {
    case queued
    case active
    case completed
    case failed
    case cancelled
}
```
- State transitions
- State-based behavior
- Progress tracking per state

---

## Performance Optimizations

### 1. Concurrent Operations
- **Queue Management**: Up to 2 sends + 2 receives simultaneously
- **Per-Device Limits**: Prevents resource exhaustion
- **Task Groups**: Parallel discovery across transports

### 2. Memory Management
- **Weak References**: Delegates and closures
- **Automatic Cleanup**: Temporary file removal
- **Stream Processing**: Chunked file transfer (no full file in memory)

### 3. Network Optimizations
- **Sliding Window**: WiFi Aware transfer efficiency
- **ACK Batching**: Reduced control overhead
- **MTU Negotiation**: BLE 5.0 optimization
- **Data Path**: WiFi Aware large file optimization

### 4. UI Performance
- **@MainActor**: UI updates on main thread
- **Lazy Loading**: Large lists and histories
- **Progress Throttling**: Update rate limiting
- **Background Processing**: File operations off main thread

---

## Security Considerations

### 1. Permission Management
- **Explicit Consent**: User approval for incoming files
- **Trusted Devices**: Automatic accept from trusted peers
- **Privacy**: No data uploaded to cloud
- **Local-only**: All operations on-device

### 2. Data Protection
- **Sandboxed Storage**: App-specific directories only
- **Temporary Files**: Automatic cleanup
- **Future**: Keychain for sensitive data, encryption

### 3. Network Security
- **Peer-to-Peer**: Direct device communication
- **No Internet**: No external servers involved
- **iOS Security**: Built on iOS security model

---

## Future Enhancements

### Planned Features
1. **WiFi Aware Data Path**: Optimized data channel for large files
2. **Encrypted Transfers**: End-to-end encryption option
3. **Resume Support**: Resume interrupted transfers
4. **Background Transfers**: Continue when app backgrounded
5. **QR Code Pairing**: Quick device pairing via QR
6. **Contact Integration**: Transfer to contacts
7. **Cloud Sync**: Optional iCloud backup of history
8. **Android Support**: Cross-platform compatibility (future)

### Technical Improvements
1. **CoreData Migration**: Replace UserDefaults for history
2. **Keychain Integration**: Secure storage for trusted devices
3. **Advanced Benchmarking**: More detailed performance metrics
4. **Network Quality Monitoring**: Real-time connection quality
5. **Adaptive Chunking**: Dynamic chunk size based on connection
6. **Compression**: Optional file compression before transfer

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-XX  
**Author**: AwareShare Team

