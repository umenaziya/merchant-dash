# AwareShare - Visual Architecture Diagrams

## Table of Contents
1. [System Architecture Diagram](#system-architecture-diagram)
2. [Network Stack Diagram](#network-stack-diagram)
3. [Transfer Flow Diagram](#transfer-flow-diagram)
4. [State Machine Diagrams](#state-machine-diagrams)
5. [Class Relationships](#class-relationships)

---

## System Architecture Diagram

### Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                               │
│                              iOS APPLICATION                                  │
│                            (AwareShare.app)                                   │
│                                                                               │
└───────────────────────────────┬─────────────────────────────────────────────┘
                                │
                                ↓
┌───────────────────────────────────────────────────────────────────────────────┐
│                          PRESENTATION LAYER                                    │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                         SwiftUI View Layer                               │ │
│  │  ┌──────────────┐ ┌───────────────┐ ┌──────────────┐ ┌──────────────┐ │ │
│  │  │AnimatedSplash│ │Transfer2UIView│ │FileSelection │ │TransferProgress│ │ │
│  │  │  ScreenView  │ │               │ │     View     │ │     View       │ │ │
│  │  └──────────────┘ └───────────────┘ └──────────────┘ └──────────────┘ │ │
│  │                                                                          │ │
│  │  ┌──────────────┐ ┌───────────────┐ ┌──────────────┐ ┌──────────────┐ │ │
│  │  │  AirDropView │ │SettingsView   │ │HistoryView   │ │ErrorOverlay  │ │ │
│  │  └──────────────┘ └───────────────┘ └──────────────┘ └──────────────┘ │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                       │                                       │
│                                       ↓                                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                         AppCoordinator                                   │ │
│  │                    (@MainActor ObservableObject)                         │ │
│  │                                                                          │ │
│  │  Responsibilities:                                                       │ │
│  │  • Navigation flow management (currentScreen: AppScreen)                │ │
│  │  • Global state coordination (@Published properties)                    │ │
│  │  • Error handling (currentError: AppError?)                             │ │
│  │  • Multi-device selection (selectedDevices: [DiscoveredDevice])         │ │
│  │  • Transfer state (activeTransfers, transferProgress)                   │ │
│  │  • Permission management (showPermissionPopup: Bool)                    │ │
│  │                                                                          │ │
│  │  @Published Properties:                                                  │ │
│  │  • currentScreen: AppScreen                                             │ │
│  │  • discoveredDevices: [DiscoveredDevice]                                │ │
│  │  • connectedDevices: [ConnectedDevice]                                  │ │
│  │  • activeTransfers: [String: TransferOperation]                         │ │
│  │  • transferProgress: [String: Double]                                   │ │
│  │  • networkingManager: NetworkingManager                                 │ │
│  │  • connectionStateManager: ConnectionStateManager                       │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
└───────────────────────────────┬───────────────────────────────────────────────┘
                                │
                                ↓
┌───────────────────────────────────────────────────────────────────────────────┐
│                         BUSINESS LOGIC LAYER                                   │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                       NetworkingManager                                  │ │
│  │                      (@MainActor ObservableObject)                       │ │
│  │                                                                          │ │
│  │  Responsibilities:                                                       │ │
│  │  • Orchestrate all transport managers                                   │ │
│  │  • Aggregate device discovery from multiple transports                  │ │
│  │  • Route transfers to appropriate transport                             │ │
│  │  • Implement fallback mechanism on failure                              │ │
│  │  • Delegate event forwarding                                            │ │
│  │                                                                          │ │
│  │  @Published Properties:                                                  │ │
│  │  • discoveredDevices: [DiscoveredDevice]                                │ │
│  │  • connectedDevices: [ConnectedDevice]                                  │ │
│  │  • isDiscovering: Bool                                                  │ │
│  │  • connectionStatus: ConnectionStatus                                   │ │
│  │  • transferProgress: [String: Double] (mirrored from queue)             │ │
│  │  • activeTransfers: [String: TransferOperation] (mirrored from queue)   │ │
│  │                                                                          │ │
│  │  Transport Managers:                                                     │ │
│  │  • private let wifiAwareManager: WiFiAwareManager                       │ │
│  │  • private let bleManager: BLEManager                                   │ │
│  │  • private let airDropManager: AirDropManager                           │ │
│  │  • private let multipeerManager: MultipeerManager                       │ │
│  │  • private let transferQueueManager: TransferQueueManager               │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌──────────────────────┬──────────────────────┬─────────────────────┐      │
│  │                      │                      │                     │      │
│  ↓                      ↓                      ↓                     ↓      │
│  ┌────────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐    │
│  │TransferQueue   │ │ConnectionState│ │BenchmarkServ │ │SettingsServ  │    │
│  │   Manager      │ │   Manager     │ │    ice       │ │    ice       │    │
│  │ (@MainActor)   │ │ (@MainActor)  │ │(@MainActor)  │ │(@MainActor)  │    │
│  └────────────────┘ └──────────────┘ └──────────────┘ └──────────────┘    │
│  • Queue ops       • Track conn     • Track metrics  • App config      │    │
│  • Max 2 sends     • Device state   • History persist• Transport pri   │    │
│  • Max 2 receives  • Health monitor • Stats calc    • User prefs      │    │
│  • Per-dev limits  • Status updates • CSV/JSON exp  • @AppStorage     │    │
│                                                                               │
└───────────────────────────────┬───────────────────────────────────────────────┘
                                │
                                ↓
┌───────────────────────────────────────────────────────────────────────────────┐
│                            NETWORK LAYER                                       │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                      WiFiAwareManager (Actor)                            │ │
│  │                                                                          │ │
│  │  Concurrency: Actor-isolated for thread safety                          │ │
│  │  Protocol: Custom sliding window with chunking                          │ │
│  │                                                                          │ │
│  │  Components:                                                             │ │
│  │  • private var networkManager: NetworkManager?                          │ │
│  │  • private var connectionManager: ConnectionManager?                    │ │
│  │  • private var endpointRegistry: [String: WAEndpoint]                   │ │
│  │  • private var slidingWindowManagers: [String: SlidingWindowTransferMgr]│ │
│  │  • private var chunkReceivers: [String: ChunkReceiver]                  │ │
│  │                                                                          │ │
│  │  Features:                                                               │ │
│  │  • Endpoint discovery & registration                                    │ │
│  │  • Connection pooling                                                   │ │
│  │  • Sliding window (10 chunks, configurable)                             │ │
│  │  • ACK batching (5 chunks, configurable)                                │ │
│  │  • Handshake timeout (3s, configurable)                                 │ │
│  │  • Data path optimization for large files (>10MB)                       │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                        BLEManager (@MainActor)                           │ │
│  │                                                                          │ │
│  │  Concurrency: @MainActor (CoreBluetooth requirement)                    │ │
│  │  Protocol: Chunk-based with headers                                     │ │
│  │                                                                          │ │
│  │  Components:                                                             │ │
│  │  • private var centralManager: CBCentralManager?                        │ │
│  │  • private var peripheralManager: CBPeripheralManager?                  │ │
│  │  • private var discoveredPeripherals: [CBPeripheral]                    │ │
│  │  • private var connectedPeripherals: [CBPeripheral]                     │ │
│  │  • private var characteristicCache: [UUID: [CBUUID: CBCharacteristic]]  │ │
│  │  • private var negotiatedMTUs: [UUID: Int]                              │ │
│  │                                                                          │ │
│  │  Features:                                                               │ │
│  │  • Central & peripheral role support                                    │ │
│  │  • Service advertising & scanning (UUID: 52D6E035-6071-4C7A-A758-82AC28CB58AC)            │ │
│  │  • MTU negotiation for BLE 5.0 (up to 512 bytes)                       │ │
│  │  • Chunk header protocol (multi-transfer support)                       │ │
│  │  • ACK protocol for reliability                                         │ │
│  │  • Retry logic (5s timeout, max 3 retries)                              │ │
│  │  • Connection health monitoring                                         │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    MultipeerManager (@MainActor)                         │ │
│  │                                                                          │ │
│  │  Framework: Apple MultipeerConnectivity                                 │ │
│  │  Protocol: Native MCSession data transfer                               │ │
│  │                                                                          │ │
│  │  Components:                                                             │ │
│  │  • private var session: MCSession?                                      │ │
│  │  • private var serviceAdvertiser: MCNearbyServiceAdvertiser?            │ │
│  │  • private var serviceBrowser: MCNearbyServiceBrowser?                  │ │
│  │  • private let serviceType = "awareshare"                               │ │
│  │                                                                          │ │
│  │  Features:                                                               │ │
│  │  • Automatic peer discovery & management                                │ │
│  │  • Session-based file transfer via MCSession                            │ │
│  │  • Built-in progress reporting                                          │ │
│  │  • Connection quality monitoring                                        │ │
│  │  • Reliable data delivery                                               │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                      AirDropManager (@MainActor)                         │ │
│  │                                                                          │ │
│  │  Integration: UIActivityViewController + Custom BLE discovery           │ │
│  │                                                                          │ │
│  │  Modes:                                                                  │ │
│  │  • Native Mode: Direct share sheet (default)                            │ │
│  │  • Custom Mode: BLE discovery + native transfer                         │ │
│  │                                                                          │ │
│  │  Components:                                                             │ │
│  │  • private var bleManager: BLEManager (for custom discovery)            │ │
│  │  • private var discoveredDevices: [DiscoveredDevice]                    │ │
│  │                                                                          │ │
│  │  Features:                                                               │ │
│  │  • Mode toggle (@AppStorage)                                            │ │
│  │  • Native iOS share sheet integration (UIActivityViewController)        │ │
│  │  • Custom BLE-based discovery for AwareShare devices                    │ │
│  │  • Device filtering & presentation                                      │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
└───────────────────────────────┬───────────────────────────────────────────────┘
                                │
                                ↓
┌───────────────────────────────────────────────────────────────────────────────┐
│                              DATA LAYER                                        │
│                                                                               │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────┐  │
│  │   UserDefaults       │  │   FileManager        │  │  Keychain(Future)│  │
│  │  ──────────────────  │  │  ──────────────────  │  │  ──────────────  │  │
│  │  • Settings          │  │  • Temporary storage │  │  • Trusted devs  │  │
│  │  • Transfer history  │  │  • Documents dir     │  │  • Sec tokens    │  │
│  │  • Benchmark data    │  │  • Received files    │  │                  │  │
│  │  • User preferences  │  │  • File operations   │  │                  │  │
│  └──────────────────────┘  └──────────────────────┘  └──────────────────┘  │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

---

## Network Stack Diagram

### Detailed Network Protocol Stack

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        APPLICATION LAYER (AwareShare)                        │
└─────────────────────────────────────┬───────────────────────────────────────┘
                                      ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TRANSPORT ABSTRACTION LAYER                          │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                       NetworkingManager API                             │ │
│  │  • sendFile(fileURL, to: device)                                       │ │
│  │  • receiveFile(from: device)                                           │ │
│  │  • connectToDevice(device)                                             │ │
│  │  • startDiscovery() / stopDiscovery()                                  │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────┬───────────────────────────────────────────────────────┘
                      │
         ┌────────────┼────────────┬────────────┐
         │            │            │            │
         ↓            ↓            ↓            ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                       PROTOCOL IMPLEMENTATIONS                               │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    WiFi Aware Protocol Stack                         │   │
│  │                                                                      │   │
│  │  Application Protocol Layer:                                        │   │
│  │  ┌────────────────────────────────────────────────────────────────┐│   │
│  │  │ NetworkEvent (Codable enum)                                    ││   │
│  │  │ • fileTransferRequest(fileName, fileSize, transferId, usePath) ││   │
│  │  │ • fileTransferAccept(transferId)                               ││   │
│  │  │ • fileTransferReject(transferId, reason)                       ││   │
│  │  │ • fileChunk(transferId, chunkIndex, totalChunks, data)         ││   │
│  │  │ • chunkAck(transferId, received: [Int])                        ││   │
│  │  │ • fileTransferComplete(transferId)                             ││   │
│  │  │ • fileTransferError(transferId, error)                         ││   │
│  │  └────────────────────────────────────────────────────────────────┘│   │
│  │                            ↕                                        │   │
│  │  Transfer Control Layer:                                            │   │
│  │  ┌────────────────────────────────────────────────────────────────┐│   │
│  │  │ SlidingWindowTransferManager                                   ││   │
│  │  │ • Window size: 10 chunks (configurable)                        ││   │
│  │  │ • Retry timeout: 3 seconds                                     ││   │
│  │  │ • Max retries: 3 per chunk                                     ││   │
│  │  │ • Flow control via ACKs                                        ││   │
│  │  │                                                                ││   │
│  │  │ ChunkReceiver                                                  ││   │
│  │  │ • Out-of-order chunk handling                                 ││   │
│  │  │ • ACK batch size: 5 chunks                                    ││   │
│  │  │ • Missing chunk detection                                     ││   │
│  │  │ • Complete data reconstruction                                ││   │
│  │  └────────────────────────────────────────────────────────────────┘│   │
│  │                            ↕                                        │   │
│  │  Connection Management Layer:                                       │   │
│  │  ┌────────────────────────────────────────────────────────────────┐│   │
│  │  │ AwareShareConnectionManager (Actor)                            ││   │
│  │  │ • Connection pooling                                           ││   │
│  │  │ • State update monitoring                                      ││   │
│  │  │ • AsyncStream event handling                                   ││   │
│  │  │ • Performance tracking                                         ││   │
│  │  └────────────────────────────────────────────────────────────────┘│   │
│  │                            ↕                                        │   │
│  │  Transport Layer:                                                   │   │
│  │  ┌────────────────────────────────────────────────────────────────┐│   │
│  │  │ Apple Network Framework                                        ││   │
│  │  │ • NetworkConnection (WiFi Aware)                               ││   │
│  │  │ • TCP framing                                                  ││   │
│  │  │ • JSON encoding/decoding                                       ││   │
│  │  │ • Performance mode: .default                                   ││   │
│  │  │ • Service class: .background                                   ││   │
│  │  └────────────────────────────────────────────────────────────────┘│   │
│  │                            ↕                                        │   │
│  │  Physical Layer:                                                    │   │
│  │  ┌────────────────────────────────────────────────────────────────┐│   │
│  │  │ WiFi Aware (iOS 26.0+)                                         ││   │
│  │  │ • 2.4 GHz / 5 GHz bands                                        ││   │
│  │  │ • Direct device-to-device                                      ││   │
│  │  │ • 50-100+ Mbps throughput                                      ││   │
│  │  │ • 100+ meter range                                             ││   │
│  │  └────────────────────────────────────────────────────────────────┘│   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                  Bluetooth LE Protocol Stack                        │   │
│  │                                                                      │   │
│  │  Application Protocol Layer:                                        │   │
│  │  ┌────────────────────────────────────────────────────────────────┐│   │
│  │  │ FileMetadata (Codable struct)                                  ││   │
│  │  │ • fileName: String                                             ││   │
│  │  │ • fileSize: Int                                                ││   │
│  │  │ • transferId: String                                           ││   │
│  │  │                                                                ││   │
│  │  │ ChunkHeader (Codable struct)                                   ││   │
│  │  │ • transferId: String                                           ││   │
│  │  │ • chunkIndex: Int                                              ││   │
│  │  │ • totalChunks: Int                                             ││   │
│  │  │ • Encoding: [2-byte length][JSON header][payload]             ││   │
│  │  │                                                                ││   │
│  │  │ AckMessage (Codable struct)                                    ││   │
│  │  │ • transferId: String                                           ││   │
│  │  │ • received: [Int] (chunk indices)                              ││   │
│  │  └────────────────────────────────────────────────────────────────┘│   │
│  │                            ↕                                        │   │
│  │  Transfer Control Layer:                                            │   │
│  │  ┌────────────────────────────────────────────────────────────────┐│   │
│  │  │ Chunk Management                                               ││   │
│  │  │ • Chunk size: MTU-based (20-247 bytes payload)                ││   │
│  │  │ • Write queue per peripheral                                  ││   │
│  │  │ • Flow control via writeValue responses                       ││   │
│  │  │                                                                ││   │
│  │  │ Retry Mechanism                                                ││   │
│  │  │ • Chunk timeout: 5 seconds                                    ││   │
│  │  │ • Max retries: 3 per chunk                                    ││   │
│  │  │ • Background retry monitor task                               ││   │
│  │  │ • ACK-based retry prevention                                  ││   │
│  │  └────────────────────────────────────────────────────────────────┘│   │
│  │                            ↕                                        │   │
│  │  GATT Profile Layer:                                                │   │
│  │  ┌────────────────────────────────────────────────────────────────┐│   │
│  │  │ Custom GATT Service (UUID: 52D6E035-6071-4C7A-A758-82AC28CB58AC)││  │
│  │  │ ┌────────────────────────────────────────────────────────────┐││   │
│  │  │ │ Characteristics:                                           │││   │
│  │  │ │ • Metadata Char (UUID: ...8C7)                             │││   │
│  │  │ │   Properties: Read, Write, Notify                          │││   │
│  │  │ │ • FileTransfer Char (UUID: ...ABDF)                         │││   │
│  │  │ │   Properties: Read, Write, Notify                          │││   │
│  │  │ │ • ACK Char (UUID: ...AA0B)                                  │││   │
│  │  │ │   Properties: Read, Write, Notify                          │││   │
│  │  │ └────────────────────────────────────────────────────────────┘││   │
│  │  └────────────────────────────────────────────────────────────────┘│   │
│  │                            ↕                                        │   │
│  │  Link Layer:                                                        │   │
│  │  ┌────────────────────────────────────────────────────────────────┐│   │
│  │  │ CoreBluetooth Framework                                        ││   │
│  │  │ • CBCentralManager (scanner/connector)                         ││   │
│  │  │ • CBPeripheralManager (advertiser/server)                      ││   │
│  │  │ • MTU negotiation (default 23, up to 512 for BLE 5.0)         ││   │
│  │  │ • Connection monitoring                                        ││   │
│  │  └────────────────────────────────────────────────────────────────┘│   │
│  │                            ↕                                        │   │
│  │  Physical Layer:                                                    │   │
│  │  ┌────────────────────────────────────────────────────────────────┐│   │
│  │  │ Bluetooth Low Energy 5.0                                       ││   │
│  │  │ • 2.4 GHz ISM band                                             ││   │
│  │  │ • 1-5 Mbps throughput                                          ││   │
│  │  │ • 10-50 meter range                                            ││   │
│  │  │ • Low power consumption                                        ││   │
│  │  └────────────────────────────────────────────────────────────────┘│   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │               Multipeer Connectivity Protocol Stack                 │   │
│  │                                                                      │   │
│  │  Application Layer:                                                 │   │
│  │  ┌────────────────────────────────────────────────────────────────┐│   │
│  │  │ MCSession Data Transfer                                        ││   │
│  │  │ • session.send(data, toPeers:, with: .reliable)                ││   │
│  │  │ • Progress.fractionCompleted tracking                          ││   │
│  │  └────────────────────────────────────────────────────────────────┘│   │
│  │                            ↕                                        │   │
│  │  Framework Layer:                                                   │   │
│  │  ┌────────────────────────────────────────────────────────────────┐│   │
│  │  │ Apple MultipeerConnectivity Framework                          ││   │
│  │  │ • MCNearbyServiceAdvertiser                                    ││   │
│  │  │ • MCNearbyServiceBrowser                                       ││   │
│  │  │ • MCSession (peer-to-peer session)                             ││   │
│  │  │ • MCPeerID (device identifier)                                 ││   │
│  │  │ • Service type: "awareshare"                                   ││   │
│  │  └────────────────────────────────────────────────────────────────┘│   │
│  │                            ↕                                        │   │
│  │  Transport Layer:                                                   │   │
│  │  ┌────────────────────────────────────────────────────────────────┐│   │
│  │  │ WiFi Direct / Bluetooth (automatic selection)                  ││   │
│  │  │ • Hybrid WiFi/Bluetooth for discovery                          ││   │
│  │  │ • Automatic transport upgrade to WiFi                          ││   │
│  │  │ • 20-50 Mbps typical throughput                                ││   │
│  │  └────────────────────────────────────────────────────────────────┘│   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Transfer Flow Diagram

### Complete Transfer Lifecycle

```
┌───────────────────────────────────────────────────────────────────────────┐
│                         TRANSFER LIFECYCLE                                 │
└───────────────────────────────────────────────────────────────────────────┘

USER INITIATES TRANSFER
         │
         ↓
    ┌─────────────────────────┐
    │ 1. Select Device        │
    │    from discovery list  │
    └────────┬────────────────┘
             │
             ↓
    ┌─────────────────────────┐         ┌──────────────────────┐
    │ 2. Connection Required? ├───YES───>│ 3. Establish Connect │
    │    (WiFiAware/BLE)      │         │    await connectTo() │
    └────────┬────────────────┘         └──────────┬───────────┘
             │NO                                   │
             │                                     ↓
             │                            ┌──────────────────────┐
             │                            │ 4. Connection Ready  │
             │                            │    Notify delegate   │
             │                            └──────────┬───────────┘
             │                                       │
             └───────────────┬───────────────────────┘
                             ↓
                    ┌─────────────────────────┐
                    │ 5. Select Transfer Mode │
                    │    Send or Receive?     │
                    └────────┬────────────────┘
                             │
                  ┌──────────┴──────────┐
                  │                     │
                  ↓                     ↓
        ┌───────────────┐      ┌───────────────┐
        │ 6a. SEND Mode │      │ 6b. RECEIVE   │
        │                │      │     Mode      │
        └───────┬───────┘      └───────┬───────┘
                │                      │
                ↓                      ↓
    ┌───────────────────────┐  ┌───────────────────────┐
    │ 7a. Select Files      │  │ 7b. Wait for Request  │
    │     File Picker UI    │  │     Listen for event  │
    └───────┬───────────────┘  └───────┬───────────────┘
            │                          │
            ↓                          ↓
    ┌───────────────────────┐  ┌───────────────────────┐
    │ 8a. Enqueue Operation │  │ 8b. Show Consent UI   │
    │     TransferQueue     │  │     Accept/Reject?    │
    │     .enqueue(send)    │  └───────┬───────────────┘
    └───────┬───────────────┘          │
            │                          ↓
            │                  ┌───────────────────────┐
            │                  │ 8c. Send Accept/Reject│
            │                  │     Message           │
            │                  └───────┬───────────────┘
            │                          │
            │              ┌───────────┴────────────┐
            │              │ Rejected? → End        │
            │              │ Accepted? → Continue   │
            │              └───────────┬────────────┘
            │                          │
            └──────────────┬───────────┘
                           ↓
            ┌─────────────────────────────────┐
            │ 9. TransferQueueManager         │
            │    Check limits:                │
            │    • activeSendCount < 2?       │
            │    • 1 per device per type?     │
            │    If YES: Start immediately    │
            │    If NO: Queue and wait        │
            └────────────┬────────────────────┘
                         │
                         ↓
            ┌─────────────────────────────────┐
            │ 10. Select Transport            │
            │     Priority order:             │
            │     [device.connectionType,     │
            │      ...other enabled]          │
            └────────────┬────────────────────┘
                         │
         ┌───────────────┼───────────────┬──────────────┐
         │               │               │              │
         ↓               ↓               ↓              ↓
┌────────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐
│11a. WiFiAware  │ │11b. BLE    │ │11c.Multipeer│ │11d.AirDrop │
│    Transfer    │ │   Transfer │ │   Transfer  │ │   Transfer │
└───────┬────────┘ └──────┬─────┘ └──────┬─────┘ └──────┬─────┘
        │                 │               │              │
        ↓                 ↓               ↓              ↓
┌──────────────────────────────────────────────────────────────┐
│              12. Protocol-Specific Transfer                   │
│                                                              │
│  WiFiAware:                  BLE:                            │
│  • Send handshake           • Send metadata                 │
│  • Wait for accept          • Send chunks with headers      │
│  • Sliding window send      • Wait for ACKs                 │
│  • ACK batches              • Retry on timeout              │
│                                                              │
│  Multipeer:                 AirDrop:                         │
│  • MCSession.send()         • UIActivityViewController      │
│  • Progress tracking        • Native iOS handling           │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ↓
        ┌────────────────────────────────┐
        │ 13. Progress Updates           │
        │     • didUpdateTransferProgress│
        │     • Update @Published        │
        │     • UI auto-updates          │
        │     • BenchmarkService tracks  │
        └────────────────────────────────┘
                     │
           ┌─────────┴─────────┐
           │                   │
           ↓                   ↓
    ┌─────────────┐     ┌─────────────┐
    │14a. Success │     │14b. Failure │
    │             │     │             │
    └──────┬──────┘     └──────┬──────┘
           │                   │
           ↓                   ↓
    ┌─────────────┐     ┌─────────────┐
    │15a. Complete│     │15b. Try Next│
    │    Operation│     │    Transport│
    │    success=T│     │    (fallback)│
    └──────┬──────┘     └──────┬──────┘
           │                   │
           │                   └──────────┐
           │                              │
           │              ┌───────────────┘
           │              │ All Failed?
           │              ↓
           │     ┌───────────────────┐
           │     │15c. Complete      │
           │     │     Operation     │
           │     │     success=false │
           │     └────────┬──────────┘
           │              │
           └──────────────┴─────────────┐
                                        ↓
                           ┌─────────────────────────┐
                           │ 16. Post-Transfer       │
                           │     • Update UI         │
                           │     • Save to history   │
                           │     • Cleanup files     │
                           │     • Notify completion │
                           └─────────────────────────┘
                                        │
                                        ↓
                           ┌─────────────────────────┐
                           │ 17. Check Queue         │
                           │     • Process next ops  │
                           │     • Start queued      │
                           └─────────────────────────┘
                                        │
                                        ↓
                           ┌─────────────────────────┐
                           │ 18. All Transfers Done? │
                           │     • Post notification │
                           │     • .allTransfersComplete│
                           └─────────────────────────┘
```

---

## State Machine Diagrams

### Transfer Operation State Machine

```
                    ┌──────────────┐
                    │   QUEUED     │ ← Initial state when enqueued
                    │              │
                    └──────┬───────┘
                           │
                           │ Queue processes
                           │ (limits allow)
                           ↓
                    ┌──────────────┐
            ┌──────>│   ACTIVE     │ ← Transfer in progress
            │       │              │
            │       └──────┬───────┘
            │              │
            │              │ Progress updates
            │              │ (0.0 → 1.0)
            │              │
            │              ↓
            │       ┌──────────────┐
            │       │ Transferring │
            │       │ Progress: X% │
            │       └──────┬───────┘
            │              │
            │      ┌───────┴───────┐
            │      │               │
            │      ↓               ↓
            │  ┌─────────┐    ┌─────────┐
            │  │ SUCCESS │    │ FAILURE │
            │  └────┬────┘    └────┬────┘
            │       │              │
            │       ↓              ↓
            │  ┌──────────────────────┐
            └──│   COMPLETED       │
               │   success: Bool   │
               │   progress: 1.0   │
               └──────────┬─────────┘
                          │
                          │ After cleanup delay (8s)
                          ↓
                    ┌──────────────┐
                    │   REMOVED    │ ← Cleaned up from active
                    │              │
                    └──────────────┘

Alternative Path:
                    ┌──────────────┐
                    │   QUEUED     │
                    └──────┬───────┘
                           │
                           │ User cancels
                           ↓
                    ┌──────────────┐
                    │  CANCELLED   │
                    └──────┬───────┘
                           │
                           ↓
                    ┌──────────────┐
                    │   REMOVED    │
                    └──────────────┘
```

### Connection State Machine

```
                    ┌─────────────────┐
                    │  DISCONNECTED   │ ← Initial state
                    │                 │
                    └────────┬────────┘
                             │
                             │ connectToDevice()
                             ↓
                    ┌─────────────────┐
                    │   CONNECTING    │
                    │  (Establishing) │
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
                    ↓                 ↓
        ┌─────────────────┐   ┌─────────────────┐
        │    CONNECTED    │   │   ERROR         │
        │   (Ready for    │   │  (Failed to     │
        │    transfer)    │   │   connect)      │
        └────────┬────────┘   └────────┬────────┘
                 │                     │
                 │ Transfer in         │
                 │ progress            │
                 ↓                     │
        ┌─────────────────┐            │
        │  TRANSFERRING   │            │
        │   (Active ops)  │            │
        └────────┬────────┘            │
                 │                     │
                 │ Transfer complete   │
                 │ or error            │
                 ↓                     │
        ┌─────────────────┐            │
        │    CONNECTED    │            │
        │   (Idle again)  │            │
        └────────┬────────┘            │
                 │                     │
                 │ disconnect()        │
                 ↓                     │
        ┌─────────────────┐            │
        │ DISCONNECTED    │<───────────┘
        │                 │
        └─────────────────┘
```

---

## Class Relationships

### Core Component Relationships

```
┌────────────────────────────────────────────────────────────────────────┐
│                         AppCoordinator                                  │
│                      (@MainActor ObservableObject)                      │
│  ──────────────────────────────────────────────────────────────────── │
│  @Published var currentScreen: AppScreen                               │
│  @Published var discoveredDevices: [DiscoveredDevice]                  │
│  @Published var connectedDevices: [ConnectedDevice]                    │
│  @Published var activeTransfers: [String: TransferOperation]           │
│  @Published var transferProgress: [String: Double]                     │
│  @Published var networkingManager: NetworkingManager                   │
│  @Published var connectionStateManager: ConnectionStateManager         │
└────────────────┬────────────────────────────────┬──────────────────────┘
                 │ owns                           │ owns
                 │                                │
                 ↓                                ↓
    ┌────────────────────────┐      ┌────────────────────────────┐
    │   NetworkingManager    │      │ ConnectionStateManager     │
    │  (@MainActor, ObsObj)  │      │     (@MainActor)           │
    └────────────┬───────────┘      └────────────────────────────┘
                 │ owns                           
                 │                                
    ┌────────────┼──────────────┬──────────────┬───────────────┐
    │            │              │              │               │
    ↓            ↓              ↓              ↓               ↓
┌──────────┐ ┌───────────┐ ┌────────────┐ ┌─────────────┐ ┌───────────┐
│WiFiAware │ │BLEManager │ │Multipeer   │ │AirDrop      │ │TransferQ  │
│Manager   │ │(@MainActor)│ │Manager     │ │Manager      │ │Manager    │
│(Actor)   │ └───────────┘ │(@MainActor)│ │(@MainActor) │ │(@MainActor)│
└──────────┘               └────────────┘ └─────────────┘ └───────────┘
     │                                                            │
     │ owns                                                       │ manages
     │                                                            │
     ↓                                                            ↓
┌──────────────────────────────────┐              ┌────────────────────────┐
│ AwareShareConnectionManager      │              │  TransferOperation     │
│            (Actor)               │              │     (Struct)           │
│  ┌────────────────────────────┐ │              │ ──────────────────── │
│  │ SlidingWindowTransferMgr   │ │              │ id: String            │
│  │ ChunkReceiver              │ │              │ type: TransferType    │
│  │ NetworkManager             │ │              │ state: TransferState  │
│  │ ConnectionManager          │ │              │ progress: Double      │
│  └────────────────────────────┘ │              └────────────────────────┘
└──────────────────────────────────┘


DEPENDENCIES:

AppCoordinator
    │
    ├─> NetworkingManager (1:1)
    │       │
    │       ├─> WiFiAwareManager (1:1, actor)
    │       ├─> BLEManager (1:1)
    │       ├─> MultipeerManager (1:1)
    │       ├─> AirDropManager (1:1)
    │       └─> TransferQueueManager (1:1)
    │               │
    │               └─> TransferOperation (1:many)
    │
    ├─> ConnectionStateManager (1:1)
    └─> BenchmarkService.shared (singleton)
    └─> SettingsService.shared (singleton)


DELEGATES:

NetworkingManager ────implements────> NetworkingManagerDelegate
    │                                           ↑
    └───────────────────────────────delegates──┘
                                                │
                                      AppCoordinator

WiFiAwareManager ────implements────> WiFiAwareManagerProtocol
BLEManager       ────implements────> ConsentPrompting
MultipeerManager ────implements────> MCSessionDelegate, MCNearbyServiceBrowserDelegate

```

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-XX  
**Author**: AwareShare Team

