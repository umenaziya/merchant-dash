# AwareShare - Complete Application Flow Documentation

## Table of Contents
1. [Overview](#overview)
2. [App Launch Flow](#app-launch-flow)
3. [Device Discovery Flow](#device-discovery-flow)
4. [Connection Flow](#connection-flow)
5. [Send File Flow](#send-file-flow)
6. [Receive File Flow](#receive-file-flow)
7. [Multi-Device Transfer Flow](#multi-device-transfer-flow)
8. [Settings & Configuration Flow](#settings--configuration-flow)
9. [History & Analytics Flow](#history--analytics-flow)
10. [Error Handling Flow](#error-handling-flow)
11. [App Lifecycle Flow](#app-lifecycle-flow)

---

## Overview

This document provides a detailed walkthrough of all user flows in the AwareShare application. Each flow includes step-by-step user actions, system responses, and state transitions.

### Flow Notation
- **User Action**: Actions taken by the user
- **System Response**: Automatic system behavior
- **State Change**: Changes to app state
- **Screen Transition**: Navigation between screens

---

## Complete App Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        AWARESHARE APP FLOW                               │
└─────────────────────────────────────────────────────────────────────────┘

APP LAUNCH
    ↓
┌──────────────────┐
│  Splash Screen   │  (AnimatedSplashScreenView)
│  currentScreen = │  - Logo animation
│  .splash         │  - Ring animations
└────────┬─────────┘  - Text flowing animation
         │
         ↓ (Auto-transition after animation)
┌──────────────────┐
│ Permission Check │  (PermissionWindowPopupView overlay)
│ showPermission   │  - Bluetooth permission
│ Popup = true     │  - Local Network permission
└────────┬─────────┘  - File access permissions
         │
         ├─────────────────┬─────────────────┐
         ↓                 ↓                 ↓
    [Grant]           [Dismiss]        [Already Granted]
         │                 │                 │
         ↓                 ↓                 ↓
┌──────────────────┐ ┌──────────┐  ┌──────────────────┐
│ Main Screen      │ │  Exit    │  │ Main Screen      │
│ Transfer2UIView  │ │  App     │  │ Transfer2UIView  │
│ currentScreen =  │ └──────────┘  │ currentScreen =  │
│ .transfer2       │               │ .transfer2       │
└────────┬─────────┘               └────────┬─────────┘
         │                                   │
         └───────────────────┬───────────────┘
                             │
                             ↓
                    ┌──────────────────┐
                    │ Device Discovery  │
                    │ - Orbital circles │
                    │ - Device nodes    │
                    │ - Transport icons │
                    └────────┬──────────┘
                             │
                ┌────────────┼────────────┐
                ↓            ↓            ↓
        ┌───────────┐ ┌──────────┐ ┌──────────┐
        │ Tap Tab   │ │ Tap      │ │ Tap      │
        │ Navigation│ │ Device   │ │ Settings │
        └─────┬─────┘ └────┬─────┘ └────┬─────┘
              │             │             │
              ↓             ↓             ↓
    ┌─────────────┐ ┌──────────────┐ ┌──────────────┐
    │ History Tab │ │ Device       │ │ Settings Tab │
    │ AirDrop Tab │ │ Selection    │ │              │
    │             │ └──────┬───────┘ └──────────────┘
    └─────────────┘        │
                           ↓
              ┌────────────────────────┐
              │ Connection Required?   │
              │ (WiFi Aware/BLE)      │
              └────────┬───────────────┘
                       │
          ┌────────────┴────────────┐
          ↓                         ↓
    [YES - Connect]          [NO - Skip]
          │                         │
          ↓                         ↓
┌──────────────────┐      ┌──────────────────┐
│ Establish        │      │ Send/Receive      │
│ Connection       │      │ Options           │
│ - WiFiAware      │      │ (Multipeer/AirDrop)│
│ - BLE            │      └────────┬───────────┘
│ - Multipeer      │               │
└────────┬─────────┘               │
         │                         │
         └──────────┬───────────────┘
                    ↓
         ┌──────────────────────┐
         │ Send/Receive Options │
         │ (SendReceiveOptionsView)│
         └──────────┬───────────┘
                    │
          ┌─────────┴─────────┐
          ↓                   ↓
    [Select Send]        [Select Receive]
          │                   │
          ↓                   ↓
┌──────────────────┐ ┌──────────────────┐
│ File Selection   │ │ Wait for Incoming │
│ (FileSelectionView)│ │ Transfer Request │
└────────┬─────────┘ └────────┬─────────┘
         │                     │
         ↓                     ↓
┌──────────────────┐ ┌──────────────────┐
│ Select Files     │ │ Consent Prompt   │
│ - Photos         │ │ - Accept/Reject  │
│ - Videos         │ └────────┬─────────┘
│ - Documents      │          │
└────────┬─────────┘          ↓
         │            ┌──────────────────┐
         ↓            │ Receive File     │
┌──────────────────┐ │ - Chunk reception│
│ Transfer Setup   │ │ - File save      │
│ - Generate ID    │ └──────────────────┘
│ - Select transport│
│ - Enqueue        │
└────────┬─────────┘
         │
         ↓
┌──────────────────┐
│ Transfer Queue   │
│ - Max 2 sends    │
│ - Max 2 receives │
│ - Per-device limit│
└────────┬─────────┘
         │
         ↓
┌──────────────────┐
│ Transfer Progress│
│ (TransferProgressView)│
│ - Progress bars  │
│ - Speed display  │
│ - ETA            │
└────────┬─────────┘
         │
         ↓
┌──────────────────┐
│ Transfer Complete│
│ (TransferCompleteView)│
│ - Success message│
│ - File info      │
└────────┬─────────┘
         │
         ↓
┌──────────────────┐
│ Return to Main   │
│ (Transfer2UIView)│
└──────────────────┘

TAB NAVIGATION (Available from Main Screen)
    │
    ├─→ History Tab
    │   └─→ TransferHistoryView
    │       ├─ View past transfers
    │       ├─ View metrics
    │       └─ Export data
    │
    ├─→ AirDrop Tab
    │   └─→ AirDropView
    │       ├─ Native mode
    │       └─ Custom mode
    │
    └─→ Settings Tab
        └─→ EnhancedSettingsView
            ├─ Transport settings
            ├─ Transfer settings
            ├─ WiFi Aware settings
            ├─ Privacy settings
            └─ App settings

ERROR HANDLING (Can occur at any point)
    │
    └─→ ErrorOverlayView
        ├─ Error message
        ├─ Retry button (if applicable)
        └─ Dismiss button
```

---

## App Launch Flow

### Flow Diagram
```
App Launch
    ↓
AwareShareApp.swift (@main)
    ↓
AppCoordinatorView
    ↓
AppCoordinator.init()
    ├─ Initialize NetworkingManager
    ├─ Initialize ConnectionStateManager
    ├─ Setup delegates
    ├─ Setup Combine observers
    └─ Setup permission refresh
    ↓
┌──────────────────────┐
│  STEP 1: SPLASH      │
│  AnimatedSplashScreen│
│  currentScreen =      │
│  .splash              │
│  - Logo animation     │
│  - Ring animations    │
│  - Text flowing       │
└──────────┬────────────┘
           │
           ↓ (Auto-transition after animation completes)
┌──────────────────────┐
│  STEP 2: PERMISSION  │
│  PermissionWindow    │
│  PopupView (overlay)  │
│  showPermissionPopup  │
│  = true               │
│  - Check permissions  │
│  - Show popup if needed│
└──────────┬────────────┘
           │
           ├─────────────────┬─────────────────┐
           ↓                 ↓                 ↓
    [User Grants]      [User Dismisses]  [Already Granted]
           │                 │                 │
           ↓                 ↓                 ↓
┌──────────────────┐ ┌──────────┐  ┌──────────────────┐
│ STEP 3: MAIN     │ │  Exit   │  │ STEP 3: MAIN     │
│ Transfer2UIView  │ │  App     │  │ Transfer2UIView  │
│ currentScreen =  │ └──────────┘  │ currentScreen =  │
│ .transfer2       │               │ .transfer2       │
│ - Device discovery│               │ - Device discovery│
│ - Orbital circles│               │ - Orbital circles│
│ - Auto-discovery │               │ - Auto-discovery │
└──────────────────┘               └──────────────────┘
```

### Detailed Steps

#### Step 1: App Initialization & Splash Screen
**User Action**: Launch app from home screen

**System Response**:
- `AwareShareApp.swift` entry point executes (`@main`)
- `AppCoordinatorView` created with `@StateObject`
- `AppCoordinator.init()` called:
  - Creates `NetworkingManager` instance
  - Creates `ConnectionStateManager` instance
  - Sets `networkingManager.delegate = self`
  - Configures `connectionStateManager` with networking manager
  - Sets up Combine observers for:
    - `transferProgress`
    - `activeTransfers`
    - `.allTransfersComplete` notification
  - Sets up permission refresh on foreground
  - Initializes `currentScreen = .splash`

**Splash Screen Display**:
- `AnimatedSplashScreenView` displayed (based on `currentScreen == .splash`)
- Splash animation sequence:
  1. Background fades in (1.0s)
  2. Logo entrance with scaling (0.8s spring, 0.3s delay)
  3. Ring animations start (continuous, 0.5s delay)
  4. Text flowing animation (0.8s delay)
  5. Hovering animation (continuous, 1.2s delay)
- After animation completes (or timeout), calls `coordinator.showStartTransfer()`

**State Change**:
- `currentScreen = .splash`
- `isTransitioning = false`
- `discoveredDevices = []`
- `connectedDevices = []`

#### Step 2: Permission Screen
**System Response**:
- `showStartTransfer()` called:
  - Sets `showPermissionPopup = true`
  - Permission popup displayed as overlay (`PermissionWindowPopupView`)
  - `PermissionsManager` checks:
    - Bluetooth permission (`CBManager.authorization`)
    - Local Network permission (`NWPathMonitor`)
    - File access permissions (Photos, Documents)

**Permission Popup Display**:
- Overlay appears with `zIndex(1000)` above main content
- Shows permission requirements:
  - Bluetooth access needed
  - Local Network access needed
  - File access needed
- User options:
  - **Grant Permissions**: Opens Settings app or grants via system prompts
  - **Dismiss**: Closes popup (can be shown again later)

**If Permissions Missing**:
- `showPermissionPopup = true`
- `PermissionWindowPopupView` displayed as overlay
- User can:
  - Tap "Grant Permissions" → Opens Settings or system permission dialogs
  - Tap "Dismiss" → Closes popup, continues to main screen

**If Permissions Granted**:
- `hasPermissions = true`
- `showPermissionPopup = false`
- `coordinator.requestPermissions()` called:
  - Checks if permission instructions should be shown
  - Navigates to main screen

**State Change**:
- `showPermissionPopup = true` (if permissions missing)
- `hasPermissions = true` (after granting)
- `showPermissionPopup = false` (after granting or dismissing)

#### Step 3: Main Screen Display
**System Response**:
- `showTransfer2()` called:
  - Resets transfer state
  - `navigate(to: .transfer2)`
  - `Transfer2UIView` displayed

**Main Screen Features**:
- `Transfer2UIView` displayed
- `onAppear` triggers:
  - Starts orbital circles animation (continuous)
  - Calls `startDiscovery()` automatically
  - Sets `isDiscovering = true`
  - Sets `pulseAnimation = true`

**Device Discovery**:
- Automatic discovery starts:
  - WiFi Aware (if enabled)
  - Bluetooth LE (if enabled)
  - Multipeer (if enabled)
- Devices appear as nodes around orbital circles
- Transport legend shows available connection types
- Device count updates in real-time

**Tab Navigation**:
- Bottom tab bar available:
  - **Home**: Device discovery (current screen)
  - **History**: Transfer history
  - **AirDrop**: AirDrop interface
  - **Settings**: App settings

**State Change**:
- `currentScreen = .transfer2`
- `isDiscovering = true`
- `pulseAnimation = true`
- Discovery starts across all enabled transports

---

## Device Discovery Flow

### Flow Diagram
```
User Action: Single Tap Center Icon
    ↓
handleSingleTap()
    ↓
startDiscovery()
    ├─ Reset discovered devices
    ├─ Set isDiscovering = true
    ├─ Set pulseAnimation = true
    └─ Call networkingManager.startDiscovery()
        ↓
NetworkingManager.startDiscovery()
    ├─ Set isDiscovering = true
    └─ withTaskGroup (parallel):
        ├─ WiFiAwareManager.startDiscovery() (if enabled)
        ├─ BLEManager.startDiscovery() (if enabled)
        ├─ MultipeerManager.startDiscovery() (if enabled)
        └─ AirDropManager (on-demand)
        ↓
Transport-Specific Discovery
    ├─ WiFiAware: Browse & Listen endpoints
    ├─ BLE: Scan & Advertise peripherals
    └─ Multipeer: Browse & Advertise peers
        ↓
Device Found Events
    ├─ Transport manager calls delegate
    └─ NetworkingManagerDelegate.didDiscoverDevice()
        ↓
NetworkingManager Processing
    ├─ Aggregate devices (handle duplicates)
    ├─ Update @Published discoveredDevices
    └─ Notify AppCoordinator
        ↓
UI Update
    └─ Transfer2UIView automatically updates
        ├─ Device nodes appear around circles
        ├─ Device count updates
        └─ Transport legend shows
```

### Detailed Steps

#### 1. Start Discovery
**User Action**: Single tap on center radar icon

**System Response**:
- `handleSingleTap()` called
- `startDiscovery()` executed:
  - `coordinator.networkingManager.resetDiscovery()` clears existing devices
  - `isDiscovering = true`
  - `pulseAnimation = true`
  - `await coordinator.networkingManager.startDiscovery()`

**State Change**:
- `isDiscovering = true`
- `pulseAnimation = true`
- `discoveredDevices = []` (reset)

#### 2. Parallel Discovery
**System Response**:
- `NetworkingManager.startDiscovery()` executes:
  - Checks `SettingsService` for enabled transports
  - Uses `withTaskGroup` for parallel execution:
    - If WiFi Aware enabled: `wifiAwareManager.startDiscovery()`
    - If Bluetooth enabled: `bleManager.startDiscovery()`
    - If Multipeer enabled: `multipeerManager.startDiscovery()`
  - Each transport manager starts its discovery process

#### 3. Device Discovery (WiFi Aware)
**System Response**:
- `WiFiAwareManager.startDiscovery()`:
  - Creates endpoint browser
  - Creates endpoint listener
  - Registers service type
  - Starts browsing for endpoints
  - Starts listening for connections

**When Device Found**:
- `didFindEndpoint()` called
- Creates `DiscoveredDevice` with:
  - `id`: Endpoint identifier
  - `name`: From metadata
  - `connectionType`: `.wifiAware`
  - `avatarIndex`: From metadata
- Calls `delegate.didDiscoverDevice(device)`

#### 4. Device Discovery (Bluetooth LE)
**System Response**:
- `BLEManager.startDiscovery()`:
  - Starts central manager scanning
  - Starts peripheral manager advertising
  - Scans for service UUID

**When Device Found**:
- `didDiscover()` called
- Extracts device name and avatar index from advertisement
- Creates `DiscoveredDevice` with:
  - `id`: Peripheral identifier
  - `name`: From advertisement
  - `connectionType`: `.bluetooth`
  - `avatarIndex`: From advertisement
- Calls `delegate.didDiscoverDevice(device)`

#### 5. Device Discovery (Multipeer)
**System Response**:
- `MultipeerManager.startDiscovery()`:
  - Starts service browser
  - Starts service advertiser
  - Creates MCSession

**When Device Found**:
- `browser(_:foundPeer:withDiscoveryInfo:)` called
- Creates `DiscoveredDevice` with:
  - `id`: Peer ID
  - `name`: Peer display name
  - `connectionType`: `.multipeer`
- Calls `delegate.didDiscoverDevice(device)`

#### 6. Device Aggregation
**System Response**:
- `NetworkingManager.didDiscoverDevice()` called
- Checks for duplicate devices (same device via different transports)
- Aggregates devices:
  - If device already exists, updates connection types
  - If new device, adds to list
- Updates `@Published discoveredDevices`

**State Change**:
- `discoveredDevices` array updated
- UI automatically refreshes via Combine

#### 7. UI Update
**System Response**:
- `Transfer2UIView` observes `coordinator.networkingManager.discoveredDevices`
- `DeviceNodesView` renders devices:
  - Positions devices around orbital circles
  - Shows device avatar
  - Shows connection type badge
  - Shows connection status badge
- Updates device count display
- Shows transport legend if devices found

#### 8. Stop Discovery
**User Action**: Double tap on center radar icon

**System Response**:
- `handleDoubleTap()` called:
  - `isDiscovering = false`
  - `pulseAnimation = false`
  - `coordinator.networkingManager.resetDiscovery()`
  - Stops all transport discovery

**State Change**:
- `isDiscovering = false`
- `pulseAnimation = false`
- Discovery stopped

---

## Connection Flow

### Flow Diagram
```
User Action: Tap Device Node
    ↓
showDeviceSelection(device)
    ├─ Set selectedDevice = device
    └─ Check requiresExplicitConnection()
        ├─ YES (WiFi Aware, BLE)
        │   └─ establishConnection(to: device)
        │       ├─ Mark device as connecting
        │       ├─ Call networkingManager.connectToDevice()
        │       └─ Wait for connection
        │           ↓
        │       Transport-Specific Connection
        │       ├─ WiFiAware: setupConnection()
        │       ├─ BLE: connect() + discover services
        │       └─ Multipeer: invitePeer()
        │           ↓
        │       Connection Established
        │       ├─ Delegate: didConnectToDevice()
        │       ├─ Update connectionStateManager
        │       └─ Navigate to send/receive options
        │
        └─ NO (Multipeer, AirDrop)
            └─ showSendReceiveOptions()
                └─ Navigate directly to options
```

### Detailed Steps

#### 1. Device Selection
**User Action**: Tap on a device node in `Transfer2UIView`

**System Response**:
- `onDeviceSelected(device)` called
- `coordinator.showDeviceSelection(device: device)` executed:
  - `selectedDevice = device`
  - Checks `requiresExplicitConnection(device.connectionType)`

**State Change**:
- `selectedDevice = device`

#### 2. Connection Requirement Check
**System Response**:
- `requiresExplicitConnection()` returns:
  - `true` for `.wifiAware` and `.bluetooth`
  - `false` for `.multipeer` and `.airDrop`

**If Explicit Connection Required**:
- Proceeds to `establishConnection(to: device)`

**If No Explicit Connection**:
- Directly calls `showSendReceiveOptions()`
- Skips connection step

#### 3. Connection Establishment (WiFi Aware)
**System Response**:
- `establishConnection(to: device)` called:
  - `connectionStateManager.markConnecting(deviceId: device.id)`
  - `await networkingManager.connectToDevice(device)`

**WiFiAwareManager Connection**:
- Looks up endpoint from registry
- `AwareShareConnectionManager.setupConnection()`:
  - Creates network connection
  - Establishes data path
  - Sets up event streaming
- Connection established

**On Success**:
- `NetworkingManagerDelegate.didConnectToDevice()` called
- `connectionStateManager` updated
- `connectedDevices` array updated

**On Failure**:
- Error caught
- `showError()` called with retry action
- Connection state marked as error

#### 4. Connection Establishment (Bluetooth LE)
**System Response**:
- `BLEManager.connectToDevice()`:
  - Finds peripheral from discovered devices
  - `CBCentralManager.connect(peripheral)`
  - Waits for connection
  - Discovers services and characteristics
  - Enables notifications

**On Success**:
- Connection established
- Services discovered
- Ready for transfer

**On Failure**:
- Error caught and reported
- Retry option provided

#### 5. Connection Establishment (Multipeer)
**System Response**:
- `MultipeerManager.connectToDevice()`:
  - Looks up peer from discovered peers
  - `browser.invitePeer(peer, to: session)`
  - Waits for invitation acceptance

**On Success**:
- Peer added to session
- Connection established

**On Failure**:
- Error caught and reported

#### 6. Navigate to Send/Receive Options
**System Response**:
- After connection established (or if not required):
  - `showSendReceiveOptions()` called
  - `navigate(to: .sendReceiveOptions)`
  - `SendReceiveOptionsView` displayed

**State Change**:
- `currentScreen = .sendReceiveOptions`
- Device connection status updated

---

## Send File Flow

### Flow Diagram
```
User Action: Select "Send"
    ↓
showFileSelection(mode: .send)
    ├─ Set transferMode = .send
    └─ Navigate to FileSelectionView
        ↓
User Action: Select Files
    ├─ File picker presented
    ├─ User selects files
    └─ Files added to selectedFiles
        ↓
User Action: Tap "Send"
    ↓
startTransfer()
    ├─ Validate device connection
    ├─ Get connected device
    └─ Call coordinator.sendSelectedFiles()
        ↓
AppCoordinator.sendSelectedFiles()
    ├─ For each file:
    │   └─ networkingManager.sendFile(fileURL, to: device)
    │       ↓
    │   NetworkingManager.sendFile()
    │   ├─ Generate transferId
    │   ├─ Select transport(s)
    │   ├─ Create TransferOperation
    │   └─ Enqueue to TransferQueueManager
    │       ↓
    │   TransferQueueManager.enqueueOperation()
    │   ├─ Add to queue
    │   ├─ Set state = .queued
    │   └─ processQueue()
    │       ↓
    │   Queue Processing
    │   ├─ Check concurrency limits
    │   ├─ Check per-device limits
    │   └─ Start operation if allowed
    │       ↓
    │   Transport-Specific Transfer
    │   ├─ WiFiAware: Sliding window protocol
    │   ├─ BLE: Chunked transfer with headers
    │   ├─ Multipeer: MCSession file transfer
    │   └─ AirDrop: Native share sheet
    │       ↓
    │   Progress Updates
    │   ├─ Transport manager reports progress
    │   ├─ TransferQueueManager updates progress
    │   └─ UI updates automatically
    │       ↓
    │   Transfer Complete
    │   ├─ TransferQueueManager.completeOperation()
    │   ├─ BenchmarkService.completeTransfer()
    │   └─ Check if all transfers done
    │       ↓
    │   All Transfers Complete
    │   └─ Post .allTransfersComplete notification
    │       ↓
    │   Navigate to Completion Screen
    └─ showTransferComplete()
```

### Detailed Steps

#### 1. Select Send Mode
**User Action**: Tap "Send" button in `SendReceiveOptionsView`

**System Response**:
- `coordinator.showFileSelection(mode: .send)` called
- `transferMode = .send`
- `navigate(to: .fileSelection)`

**State Change**:
- `currentScreen = .fileSelection`
- `transferMode = .send`

#### 2. File Selection
**User Action**: Tap file type or browse files

**System Response**:
- `FileSelectionView` displays file picker
- User selects files
- Files added to `coordinator.selectedFiles`

**State Change**:
- `selectedFiles` array updated

#### 3. Initiate Transfer
**User Action**: Tap "Send" button in file selection

**System Response**:
- `startTransfer()` called:
  - Validates `selectedDevice` exists
  - Gets connected device from `connectionStateManager`
  - Calls `coordinator.sendSelectedFiles(to: connectedDevice)`

#### 4. Send Files
**System Response**:
- `AppCoordinator.sendSelectedFiles()`:
  - For each file in `selectedFiles`:
    - `await networkingManager.sendFile(fileURL, to: device)`

#### 5. Transfer Setup
**System Response**:
- `NetworkingManager.sendFile()`:
  - Generates unique `transferId`
  - Validates user-selected transports (if any)
  - Calls `selectTransport(for: device)` for fallback list
  - Creates `TransferOperation`:
    - `id`: transferId
    - `type`: `.send`
    - `fileName`: file name
    - `fileSize`: file size
    - `deviceName`: device name
    - `deviceId`: device id
  - Stores file size for benchmarking
  - Enqueues operation with execution closure

#### 6. Queue Processing
**System Response**:
- `TransferQueueManager.enqueueOperation()`:
  - Adds operation to `queuedTransfers`
  - Adds to `activeTransfers` dictionary
  - Sets `transferProgress[transferId] = 0.0`
  - Stores execution closure
  - Calls `processQueue()`

**Queue Processing Logic**:
- Checks `activeSendCount < maxConcurrentSends` (2)
- Checks `canStartOperation()`:
  - Per-device limit: max 1 send per device
  - Unknown device limit: max 1 send
- If allowed, calls `startOperation()`

#### 7. Operation Execution
**System Response**:
- `startOperation()`:
  - Updates state to `.active`
  - Increments `activeSendCount`
  - Tracks device active type
  - Executes closure in `Task`

**Execution Closure**:
- Tries transports in priority order
- For each transport:
  - Attempts transfer
  - On failure, tries next transport
  - On success, completes

#### 8. WiFi Aware Transfer
**System Response**:
- `WiFiAwareManager.sendFile()`:
  - Gets connection from pool
  - Sends `FileTransferReq` message:
    - `fileName`, `fileSize`, `transferId`
  - Waits for `FileTransferAccept` (3s timeout)
  - Initializes `SlidingWindowTransferManager`:
    - Window size: 10 chunks
    - Retry timeout: 3 seconds
    - Max retries: 3
  - Streams file in chunks:
    - Reads chunk from file
    - Sends chunk via network
    - Waits for ACK batch (every 5 chunks)
    - Slides window forward
  - Sends `FileTransferComplete` when done

**Progress Updates**:
- `slidingWindowManager.getProgress()` called periodically
- `delegate.didUpdateTransferProgress()` called
- `TransferQueueManager.updateProgress()` updates state
- UI updates automatically

#### 9. Bluetooth LE Transfer
**System Response**:
- `BLEManager.sendFile()`:
  - Sends metadata via metadata characteristic:
    - `fileName`, `fileSize`, `transferId`
  - Waits for implicit accept (receiver starts receiving)
  - Calculates chunks based on MTU:
    - MTU: 247 bytes
    - Header: ~50 bytes
    - Payload: ~197 bytes
  - Sends chunks sequentially:
    - Each chunk has header: `{transferId, chunkIndex, totalChunks}`
    - Sends chunk data
    - Waits for write response
  - Receives ACKs every 5 chunks
  - Retries on timeout (5s, max 3 retries)

**Progress Updates**:
- Progress calculated from chunks sent
- Updates via delegate

#### 10. Multipeer Transfer
**System Response**:
- `MultipeerManager.sendFile()`:
  - Gets session for device
  - Sends file via `MCSession.sendResource()`
  - Progress reported via delegate
  - Timeout handled (30 seconds)

**Progress Updates**:
- Native progress reporting
- Updates via delegate

#### 11. Transfer Completion
**System Response**:
- Transport manager reports completion
- `NetworkingManager` calls:
  - `transferQueueManager.completeOperation(transferId, success: true)`
  - `benchmarkService.completeTransfer(transferId)`

**Queue Manager**:
- Updates state to `.completed`
- Decrements `activeSendCount`
- Removes from device tracking
- Sets progress to 1.0
- Schedules cleanup after 8 seconds
- Calls `processQueue()` for next operations
- Checks if all transfers complete

**All Transfers Complete**:
- If all transfers done:
  - Posts `.allTransfersComplete` notification
  - Includes: `completedCount`, `failedCount`, `failedTransfers`

#### 12. Navigate to Completion
**System Response**:
- `AppCoordinator.handleAllTransfersComplete()`:
  - Cleans up temporary files
  - Calls `showTransferComplete()`
  - `navigate(to: .transferComplete)`

**State Change**:
- `currentScreen = .transferComplete`
- `transferComplete = true`

---

## Receive File Flow

### Flow Diagram
```
Remote Device: Sends File Transfer Request
    ↓
NetworkEvent.fileTransferRequest Received
    ↓
ConsentPrompting.didRequestFileTransfer()
    ├─ Show consent UI (iOSConsentPresenter)
    └─ Wait for user decision
        ├─ User Accepts
        │   └─ Send FileTransferAccept
        │       ↓
        │   Initialize Reception
        │   ├─ WiFiAware: Initialize ChunkReceiver
        │   ├─ BLE: Setup reception buffer
        │   └─ Multipeer: Setup file reception
        │       ↓
        │   Receive Chunks
        │   ├─ Store chunks (out-of-order OK)
        │   ├─ Send ACKs (batched)
        │   └─ Update progress
        │       ↓
        │   All Chunks Received
        │   ├─ Reconstruct file
        │   ├─ Verify file size
        │   └─ Save to Documents directory
        │       ↓
        │   Transfer Complete
        │   ├─ BenchmarkService.completeTransfer()
        │   ├─ Show completion notification
        │   └─ Delegate: didReceiveFile()
        │
        └─ User Rejects
            └─ Send FileTransferReject
                └─ End
```

### Detailed Steps

#### 1. Receive Transfer Request
**System Response**:
- Remote device sends `FileTransferReq` message
- Transport manager receives message
- Calls `ConsentPrompting.didRequestFileTransfer()`:
  - Extracts: `fileName`, `fileSize`, `transferId`

#### 2. Consent Prompt
**System Response**:
- `iOSConsentPresenter.presentConsent()`:
  - Creates `UIAlertController`
  - Shows file name and size
  - "Accept" and "Reject" buttons
  - User makes decision

**State Change**:
- Consent prompt displayed

#### 3. User Accepts
**User Action**: Tap "Accept" on consent prompt

**System Response**:
- Sends `FileTransferAccept` message to sender
- Initializes reception based on transport:

**WiFi Aware Reception**:
- Creates `ChunkReceiver`:
  - `totalSize`: file size
  - `ackBatchSize`: 5 chunks
- Sets up chunk storage dictionary

**BLE Reception**:
- Initializes reception buffer
- Sets up chunk storage
- Enables characteristic notifications

**Multipeer Reception**:
- Sets up file reception continuation
- Stores continuation for when file received

#### 4. Receive Chunks
**System Response**:
- Chunks received via transport-specific mechanism

**WiFi Aware**:
- `didReceiveChunk()` called
- Stores chunk in dictionary: `chunks[chunkIndex] = data`
- Tracks received chunks
- Every 5 chunks, sends `ChunkAck` batch
- Updates progress: `receivedBytes / totalSize`

**BLE**:
- Characteristic update received
- Parses chunk header
- Stores chunk data
- Sends ACK every 5 chunks
- Updates progress

**Multipeer**:
- `session(_:didStartReceivingResourceWithName:fromPeer:withProgress:)` called
- Progress updates automatically
- File received to temporary location

#### 5. File Reconstruction
**System Response**:
- When all chunks received (or file complete):

**WiFi Aware**:
- Checks if all chunks present
- Reconstructs file in order:
  - Creates output file
  - Writes chunks sequentially
  - Verifies total size

**BLE**:
- All chunks received
- Reconstructs file in order
- Verifies size

**Multipeer**:
- File received to temporary location
- Moves to Documents directory

#### 6. Save File
**System Response**:
- Saves file to Documents directory:
  - `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]`
  - Creates unique filename if needed
  - Writes file data
  - Verifies file size

#### 7. Transfer Complete
**System Response**:
- `BenchmarkService.completeTransfer()`:
  - Records metrics
  - Saves to history
- `NetworkingManagerDelegate.didReceiveFile()` called
- Shows completion notification
- Updates UI

**State Change**:
- Transfer marked as complete
- File available in Documents directory

---

## Multi-Device Transfer Flow

### Flow Diagram
```
User Action: Select Multiple Devices
    ↓
toggleDeviceSelection(device) for each device
    ├─ Add/remove from selectedDevices array
    └─ Update selection state
        ↓
User Action: Select Files & Tap Send
    ↓
sendToSelectedDevices(fileURL)
    ├─ Connect to all devices (if needed)
    ├─ For each device:
    │   └─ networkingManager.sendFile(fileURL, to: device)
    │       └─ Creates unique transferId per device
    │           ↓
    │       TransferQueueManager.enqueueOperation()
    │       └─ Each transfer independently queued
    │           ↓
    │       Queue Processing
    │       ├─ Up to 2 concurrent sends
    │       ├─ Per-device limit: 1 send per device
    │       └─ Remaining queued
    │           ↓
    │       Progress Tracking
    │       ├─ Each transfer tracked separately
    │       ├─ Progress updates per transferId
    │       └─ UI shows all active transfers
    │           ↓
    │       Transfers Complete
    │       ├─ Individual transfers complete
    │       └─ Queue processes next transfers
    │           ↓
    │       All Transfers Complete
    │       └─ Post .allTransfersComplete notification
    │           ↓
    │       Navigate to Completion Screen
    └─ showTransferComplete()
```

### Detailed Steps

#### 1. Select Multiple Devices
**User Action**: Tap multiple device nodes in `Transfer2UIView`

**System Response**:
- For each tap:
  - `coordinator.toggleDeviceSelection(device)` called
  - If device already selected, removes from `selectedDevices`
  - If not selected, adds to `selectedDevices`
  - Updates selection state

**State Change**:
- `selectedDevices` array updated
- Device selection state updated

#### 2. Select Files
**User Action**: Navigate to file selection and select files

**System Response**:
- Files added to `coordinator.selectedFiles`

#### 3. Initiate Multi-Device Transfer
**User Action**: Tap "Send" button

**System Response**:
- `coordinator.sendToSelectedDevices(fileURL)` called:
  - Validates `selectedDevices` not empty
  - For each device:
    - If `requiresExplicitConnection()`:
      - `await networkingManager.connectToDevice(device)`
    - Gets connected device
    - Adds to `connectedDevices` array

#### 4. Send to All Devices
**System Response**:
- `networkingManager.sendFileToMultipleDevices(fileURL, to: connectedDevices)`:
  - For each device:
    - Generates unique `transferId`
    - Calls `sendFile(fileURL, to: device)`
    - Each transfer independently enqueued

#### 5. Queue Management
**System Response**:
- Each transfer enqueued separately:
  - Unique `transferId` per device
  - Independent `TransferOperation`
  - Independent execution closure

**Queue Processing**:
- Processes up to 2 concurrent sends
- Respects per-device limit (1 send per device)
- Queues remaining transfers
- Processes next when slot available

#### 6. Progress Tracking
**System Response**:
- Each transfer tracked separately:
  - `transferProgress[transferId]` per transfer
  - `activeTransfers[transferId]` per transfer
- UI displays all active transfers:
  - `TransferProgressView` shows all transfers
  - Progress bars per transfer
  - Device names per transfer

#### 7. Completion Handling
**System Response**:
- As transfers complete:
  - Individual transfers marked complete
  - Queue processes next transfers
  - Progress updates continue

**All Transfers Complete**:
- When all transfers done:
  - Posts `.allTransfersComplete` notification
  - Includes summary:
    - `completedCount`
    - `failedCount`
    - `failedTransfers` array
- Navigates to completion screen

---

## Settings & Configuration Flow

### Flow Diagram
```
User Action: Tap Settings Tab
    ↓
showSettings()
    └─ Navigate to EnhancedSettingsView
        ↓
Settings Categories
    ├─ Transport Settings
    │   ├─ Enable/disable transports
    │   └─ Set priority order
    ├─ Transfer Settings
    │   ├─ Chunk size
    │   ├─ Timeout values
    │   └─ Retry settings
    ├─ WiFi Aware Settings
    │   ├─ Sliding window size
    │   ├─ ACK batch size
    │   └─ Handshake timeout
    ├─ Privacy Settings
    │   ├─ Device name
    │   └─ Avatar selection
    └─ App Settings
        ├─ Permission instructions
        └─ Reset options
        ↓
User Action: Change Setting
    ├─ SettingsService updates value
    ├─ @AppStorage persists to UserDefaults
    └─ UI updates immediately
```

### Detailed Steps

#### 1. Navigate to Settings
**User Action**: Tap "Settings" tab

**System Response**:
- `coordinator.showSettings()` called
- `navigate(to: .settings)`
- `EnhancedSettingsView` displayed

#### 2. View Settings
**System Response**:
- Settings loaded from `SettingsService`:
  - Transport enable/disable flags
  - Transport priority order
  - Transfer settings
  - WiFi Aware settings
  - Privacy settings

#### 3. Modify Settings
**User Action**: Toggle switches, change values

**System Response**:
- `SettingsService` updates values:
  - `@AppStorage` properties update
  - Values persist to `UserDefaults`
  - UI updates immediately

**Settings Categories**:
- **Transport Settings**:
  - `useWiFiAware`, `useBluetooth`, `useMultipeer`
  - `transportPriorityOrder`
- **Transfer Settings**:
  - `preferredChunkSize`
  - `transferTimeoutSeconds`
  - `maxRetries`
- **WiFi Aware Settings**:
  - `slidingWindowSize`
  - `ackBatchSize`
  - `handshakeTimeoutSeconds`
- **Privacy Settings**:
  - `deviceName`
  - `selectedAvatar`

#### 4. Settings Applied
**System Response**:
- Settings take effect immediately:
  - Transport enable/disable affects discovery
  - Priority order affects transport selection
  - Transfer settings affect new transfers
  - Privacy settings affect device appearance

---

## History & Analytics Flow

### Flow Diagram
```
User Action: Tap History Tab
    ↓
showHistory()
    └─ Navigate to TransferHistoryView
        ↓
Load Transfer History
    ├─ BenchmarkService.getTransferHistory()
    ├─ Load from UserDefaults
    └─ Display transfers
        ↓
Transfer List Display
    ├─ Sort by date (newest first)
    ├─ Show transfer details:
    │   ├─ File name
    │   ├─ Device name
    │   ├─ File size
    │   ├─ Duration
    │   ├─ Speed
    │   └─ Success/failure status
    └─ Filter options
        ↓
User Action: Tap Transfer
    └─ Show Transfer Details
        ├─ Full metrics
        ├─ Timeline
        └─ Export options
            ↓
User Action: Export
    ├─ CSV export
    └─ JSON export
```

### Detailed Steps

#### 1. Navigate to History
**User Action**: Tap "History" tab

**System Response**:
- `coordinator.showHistory()` called
- `navigate(to: .history)`
- `TransferHistoryView` displayed

#### 2. Load History
**System Response**:
- `BenchmarkService.getTransferHistory()` called
- Loads from `UserDefaults`
- Parses transfer records
- Sorts by date (newest first)

#### 3. Display History
**System Response**:
- Shows transfer list:
  - File name
  - Device name
  - Connection type
  - File size
  - Duration
  - Average speed
  - Success/failure status
  - Date/time

#### 4. View Details
**User Action**: Tap on a transfer

**System Response**:
- Shows detailed metrics:
  - Transfer ID
  - Start/end time
  - Bytes transferred
  - Speed over time
  - Error details (if failed)

#### 5. Export Data
**User Action**: Tap "Export" button

**System Response**:
- `BenchmarkService.exportHistory()`:
  - CSV export: Comma-separated values
  - JSON export: Structured data
- Share sheet presented
- User can save or share

---

## Error Handling Flow

### Flow Diagram
```
Error Occurs
    ↓
Error Caught
    ├─ Transport Manager Level
    │   ├─ Log error
    │   └─ Throw to NetworkingManager
    │       ↓
    │   NetworkingManager Level
    │   ├─ Log error
    │   ├─ Try fallback transport (if available)
    │   └─ Report to delegate
    │       ↓
    │   AppCoordinator Level
    │   ├─ showError(error, retryAction)
    │   ├─ Set currentError
    │   └─ Set retryAction closure
    │       ↓
    │   UI Level
    │   └─ ErrorOverlayView displayed
    │       ├─ Show error message
    │       ├─ Show retry button (if retryAction)
    │       └─ Show dismiss button
    │           ↓
    │       User Action
    │       ├─ Retry: Execute retryAction
    │       └─ Dismiss: dismissError()
```

### Detailed Steps

#### 1. Error Occurs
**System Response**:
- Error occurs at transport level:
  - Connection failure
  - Transfer timeout
  - Protocol error
  - File access error

#### 2. Error Propagation
**System Response**:
- Transport manager catches error:
  - Logs error with details
  - Throws to `NetworkingManager`

**NetworkingManager**:
- Catches error
- Logs error
- Tries fallback transport (if available):
  - Gets transport list
  - Tries next transport
  - If all fail, reports error
- Calls `delegate.didFailTransfer()` or similar

#### 3. Error Display
**System Response**:
- `AppCoordinator.showError()` called:
  - `currentError = error`
  - `retryAction = closure` (if applicable)
  - UI updates automatically

**ErrorOverlayView**:
- Displays error overlay:
  - Error message from `AppError`
  - Retry button (if `retryAction` exists)
  - Dismiss button

#### 4. Error Recovery
**User Action**: Tap "Retry" button

**System Response**:
- `retryAction()` executed:
  - Re-attempts operation
  - Fresh transport selection
  - New transfer ID
  - Re-enqueued to queue

**User Action**: Tap "Dismiss" button

**System Response**:
- `coordinator.dismissError()` called:
  - `currentError = nil`
  - `retryAction = nil`
  - Overlay dismissed

---

## App Lifecycle Flow

### Flow Diagram
```
App Launch
    ↓
App Active
    ├─ Discovery running
    ├─ Transfers active
    └─ UI updates
        ↓
App Backgrounds
    ├─ didEnterBackgroundNotification
    ├─ Cleanup temporary files
    ├─ Pause discovery (optional)
    └─ Continue transfers (if supported)
        ↓
App Foregrounds
    ├─ willEnterForegroundNotification
    ├─ Refresh permissions
    ├─ Resume discovery
    └─ Update UI state
        ↓
App Terminates
    ├─ willTerminateNotification
    ├─ cleanupOnAppTermination()
    ├─ Cleanup temporary files
    └─ Save state (if needed)
```

### Detailed Steps

#### 1. App Active
**System Response**:
- App is active and running
- Discovery continues
- Transfers proceed
- UI updates normally

#### 2. App Backgrounds
**System Response**:
- `didEnterBackgroundNotification` received
- `AppCoordinatorView.onReceive()`:
  - `coordinator.cleanupTemporaryFiles()` called
  - Temporary files cleaned up
- Discovery may pause (depending on implementation)
- Transfers may continue (if supported)

#### 3. App Foregrounds
**System Response**:
- `willEnterForegroundNotification` received
- `AppCoordinator.setupPermissionRefresh()`:
  - `refreshPermissionStatus()` called
  - Permissions checked
  - UI updated
- Discovery resumes
- UI state refreshed

#### 4. App Terminates
**System Response**:
- `willTerminateNotification` received
- `AppCoordinatorView.onReceive()`:
  - `coordinator.cleanupOnAppTermination()` called
  - Temporary files cleaned up
  - State saved (if needed)

---

## Summary

This document covers all major user flows in the AwareShare application. Each flow includes:

1. **User Actions**: What the user does
2. **System Responses**: How the app responds
3. **State Changes**: How app state updates
4. **Screen Transitions**: How navigation works

For implementation details, refer to:
- `ARCHITECTURE.md` for system design
- `COMPONENT_FLOW.md` for component interactions
- `VERIFICATION_GUIDE.md` for testing procedures

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-15  
**Maintained By**: AwareShare Team

