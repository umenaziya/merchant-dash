# AwareShare - Component Flow & Sequence Diagrams

## Table of Contents
1. [Complete Transfer Flow](#complete-transfer-flow)
2. [Discovery & Connection Sequences](#discovery--connection-sequences)
3. [WiFi Aware Protocol Flow](#wifi-aware-protocol-flow)
4. [Bluetooth LE Protocol Flow](#bluetooth-le-protocol-flow)
5. [Queue Management Flow](#queue-management-flow)
6. [Error Handling & Retry Flow](#error-handling--retry-flow)

---

## Complete Transfer Flow

### End-to-End File Transfer Sequence

```
┌──────────┐         ┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│  User A  │         │  Device A    │         │  Device B    │         │  User B      │
│ (Sender) │         │ (AwareShare) │         │ (AwareShare) │         │ (Receiver)   │
└────┬─────┘         └──────┬───────┘         └──────┬───────┘         └──────┬───────┘
     │                      │                        │                        │
     │ 1. Open App          │                        │                        │
     ├─────────────────────>│                        │                        │
     │                      │                        │                        │
     │                      │ 2. Start Discovery     │                        │
     │                      │ (WiFi/BLE/Multipeer)   │                        │
     │                      ├───────────────────────>│                        │
     │                      │                        │                        │
     │                      │ 3. Advertise/Browse    │                        │
     │                      │<──────────────────────>│                        │
     │                      │                        │                        │
     │                      │ 4. Device Discovered   │                        │
     │<─────────────────────┤                        │                        │
     │ (Shows in UI)        │                        │                        │
     │                      │                        │                        │
     │ 5. Tap Device        │                        │                        │
     ├─────────────────────>│                        │                        │
     │                      │                        │                        │
     │                      │ 6. Establish Connection│                        │
     │                      ├───────────────────────>│                        │
     │                      │                        │                        │
     │                      │ 7. Connection Ready    │                        │
     │                      │<──────────────────────>│                        │
     │                      │                        │                        │
     │ 8. Select "Send"     │                        │                        │
     ├─────────────────────>│                        │                        │
     │                      │                        │                        │
     │ 9. Choose Files      │                        │                        │
     ├─────────────────────>│                        │                        │
     │                      │                        │                        │
     │                      │ 10. File Transfer Req  │                        │
     │                      │ (fileName, size, id)   │                        │
     │                      ├───────────────────────>│                        │
     │                      │                        │                        │
     │                      │                        │ 11. Show Accept Prompt │
     │                      │                        ├───────────────────────>│
     │                      │                        │                        │
     │                      │                        │ 12. Accept Transfer    │
     │                      │                        │<───────────────────────┤
     │                      │                        │                        │
     │                      │ 13. Accept Message     │                        │
     │                      │<───────────────────────┤                        │
     │                      │                        │                        │
     │ 14. Start Transfer   │                        │                        │
     │ (Progress shown)     │                        │                        │
     │<─────────────────────┤                        │                        │
     │                      │                        │                        │
     │                      │ 15. Send Chunks        │                        │
     │                      │ (Chunk 0, 1, 2...)     │                        │
     │                      ├───────────────────────>│                        │
     │                      │                        │                        │
     │                      │ 16. ACK Batch          │                        │
     │                      │ (Chunks 0-4 received)  │                        │
     │                      │<───────────────────────┤                        │
     │                      │                        │                        │
     │ 17. Progress Update  │                        │ 18. Progress Update    │
     │ (25% complete)       │                        │ (25% received)         │
     │<─────────────────────┤                        ├───────────────────────>│
     │                      │                        │                        │
     │                      │ ... More chunks ...    │                        │
     │                      │<──────────────────────>│                        │
     │                      │                        │                        │
     │                      │ 19. Transfer Complete  │                        │
     │                      ├───────────────────────>│                        │
     │                      │                        │                        │
     │                      │                        │ 20. Save File          │
     │                      │                        │ (Documents directory)  │
     │                      │                        │                        │
     │ 21. Success          │                        │ 22. File Received      │
     │<─────────────────────┤                        ├───────────────────────>│
     │ (Show completion)    │                        │ (Show notification)    │
     │                      │                        │                        │
```

---

## Discovery & Connection Sequences

### Multi-Transport Discovery Flow

```
┌──────────────────┐
│ User Opens App   │
└────────┬─────────┘
         │
         ↓
┌─────────────────────────────────────────────────────────────┐
│                  AppCoordinator                              │
│                 .startDiscovery()                            │
└────────┬────────────────────────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────────────────────────┐
│              NetworkingManager.startDiscovery()              │
│           ┌─────────────────────────────────┐               │
│           │ withTaskGroup (parallel tasks)  │               │
│           └────────┬────────────────────────┘               │
└────────────────────┼────────────────────────────────────────┘
                     │
         ┌───────────┼───────────┬───────────┐
         │           │           │           │
         ↓           ↓           ↓           ↓
┌────────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐
│ WiFiAware  │ │   BLE    │ │Multipeer │ │ AirDrop │
│  .start    │ │  .start  │ │  .start  │ │(manual) │
│ Discovery()│ │Discovery()│ │Discovery()│ │         │
└─────┬──────┘ └────┬─────┘ └────┬─────┘ └────┬────┘
      │            │           │           │
      │            │           │           │
      ↓            ↓           ↓           ↓
┌─────────────────────────────────────────────────────┐
│         Transport-Specific Discovery                 │
│                                                      │
│  WiFiAware:        BLE:           Multipeer:        │
│  └─ browse()       └─ scanFor()   └─ browse()      │
│  └─ listen()          Peripherals    └─ advertise()│
│                                                      │
└────┬──────────────┬──────────────┬──────────────────┘
     │              │              │
     ↓              ↓              ↓
┌────────────────────────────────────────────────────┐
│  Device Found Events                               │
│  ┌──────────────────────────────────────────────┐ │
│  │ NetworkingManagerDelegate                    │ │
│  │ .didDiscoverDevice(DiscoveredDevice)         │ │
│  └─────────────────┬────────────────────────────┘ │
└────────────────────┼───────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────┐
│  AppCoordinator                                      │
│  @Published discoveredDevices.append(device)         │
└────────────────────┬────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────┐
│  SwiftUI View Auto-Update                            │
│  Transfer2UIView shows device in list                │
└─────────────────────────────────────────────────────┘
```

### Connection Establishment Sequence

```
User Taps Device in List
         │
         ↓
┌─────────────────────────────────────────────────────┐
│ AppCoordinator.showDeviceSelection(device)           │
│                                                      │
│ Decision: requiresExplicitConnection?                │
│ └─ WiFiAware: YES                                   │
│ └─ BLE: YES                                         │
│ └─ Multipeer: NO (connect on send/receive)          │
│ └─ AirDrop: NO (native handles it)                  │
└────────┬────────────────────────────────────────────┘
         │
    ┌────┴────┐
    │         │
    ↓         ↓
  YES        NO
    │         │
    │         └─────────────────────────────┐
    │                                       │
    ↓                                       ↓
┌───────────────────────────────┐  ┌────────────────────────┐
│ establishConnection()         │  │ showSendReceiveOptions()│
│                               │  │ (Skip connection step) │
│ ┌──────────────────────────┐ │  └────────────────────────┘
│ │NetworkingManager         │ │
│ │.connectToDevice(device)  │ │
│ └────────┬─────────────────┘ │
│          │                   │
└──────────┼───────────────────┘
           │
      ┌────┴────┐
      │         │
      ↓         ↓
┌───────────┐ ┌────────────┐
│ WiFiAware │ │    BLE     │
│ Connect   │ │  Connect   │
└─────┬─────┘ └─────┬──────┘
      │             │
      ↓             ↓
┌────────────────────────────────────────┐
│ Transport-Specific Connection          │
│                                        │
│ WiFiAware:                             │
│ ├─ Lookup endpoint from registry      │
│ ├─ ConnectionManager.setupConnection() │
│ └─ NetworkConnection established       │
│                                        │
│ BLE:                                   │
│ ├─ Find peripheral from cache         │
│ ├─ CBCentralManager.connect()         │
│ ├─ Discover services & characteristics│
│ └─ Enable notifications                │
└────────┬───────────────────────────────┘
         │
         ↓
┌────────────────────────────────────────┐
│ Connection Ready Event                 │
│                                        │
│ NetworkingManagerDelegate              │
│ .didConnectToDevice(ConnectedDevice)   │
└────────┬───────────────────────────────┘
         │
         ↓
┌────────────────────────────────────────┐
│ AppCoordinator                         │
│ @Published connectedDevices.append()   │
│ connectionStatus = .connected          │
└────────┬───────────────────────────────┘
         │
         ↓
┌────────────────────────────────────────┐
│ Navigate to Send/Receive Options       │
└────────────────────────────────────────┘
```

---

## WiFi Aware Protocol Flow

### Sliding Window Transfer Protocol

```
SENDER (Device A)                                    RECEIVER (Device B)
┌────────────────────┐                              ┌────────────────────┐
│                    │                              │                    │
│ 1. Handshake       │                              │                    │
│ ┌────────────────┐ │                              │                    │
│ │FileTransferReq │ │                              │                    │
│ │- fileName      │ ├─────────────────────────────>│ 2. Consent Check   │
│ │- fileSize      │ │                              │ ┌────────────────┐ │
│ │- transferId    │ │                              │ │Show Accept UI  │ │
│ │- useDataPath   │ │                              │ └────────────────┘ │
│ └────────────────┘ │                              │         │          │
│         │          │                              │         ↓          │
│         │          │                              │    User Accepts    │
│         │          │                              │         │          │
│         ↓          │                              │         ↓          │
│  Wait for Accept   │ 3. Accept Message            │ ┌────────────────┐ │
│  (3s timeout)      │<─────────────────────────────┤ │FileTransferAcc │ │
│         │          │                              │ │- transferId    │ │
│         ↓          │                              │ └────────────────┘ │
│ ┌────────────────┐ │                              │                    │
│ │ Initialize     │ │                              │ ┌────────────────┐ │
│ │ Sliding Window │ │                              │ │ Initialize     │ │
│ │ Manager        │ │                              │ │ ChunkReceiver  │ │
│ │- Window: 10    │ │                              │ │- ACK batch: 5  │ │
│ │- Retry: 3      │ │                              │ └────────────────┘ │
│ └────────────────┘ │                              │                    │
│         │          │                              │                    │
│         ↓          │                              │                    │
│ 4. Start Sending   │                              │                    │
│ ┌────────────────┐ │                              │                    │
│ │Send Window 0-9 │ │  5. Chunk Stream             │                    │
│ │Chunk 0 ────────┼─┼─────────────────────────────>│ Store chunk 0     │
│ │Chunk 1 ────────┼─┼─────────────────────────────>│ Store chunk 1     │
│ │Chunk 2 ────────┼─┼─────────────────────────────>│ Store chunk 2     │
│ │Chunk 3 ────────┼─┼─────────────────────────────>│ Store chunk 3     │
│ │Chunk 4 ────────┼─┼─────────────────────────────>│ Store chunk 4     │
│ └────────────────┘ │                              │         │          │
│         │          │                              │         ↓          │
│    Wait for ACK    │  6. ACK Batch (chunks 0-4)   │ ┌────────────────┐ │
│         │          │<─────────────────────────────┤ │ChunkAck        │ │
│         ↓          │                              │ │- transferId    │ │
│ ┌────────────────┐ │                              │ │- received:[0-4]│ │
│ │Process ACK     │ │                              │ └────────────────┘ │
│ │- Mark 0-4 OK   │ │                              │                    │
│ │- Slide window  │ │                              │                    │
│ │  to 5-14       │ │                              │                    │
│ └────────────────┘ │                              │                    │
│         │          │                              │                    │
│         ↓          │                              │                    │
│ ┌────────────────┐ │  7. Next Window              │                    │
│ │Send Window 5-14│ │                              │                    │
│ │Chunk 5 ────────┼─┼─────────────────────────────>│ Store chunk 5     │
│ │Chunk 6 ────────┼─┼─────────────────────────────>│ Store chunk 6     │
│ │... (continues) │ │                              │ ...                │
│ └────────────────┘ │                              │                    │
│                    │                              │                    │
│     ... (repeat sliding window process) ...       │                    │
│                    │                              │                    │
│ ┌────────────────┐ │  8. Last Chunks              │                    │
│ │Final Chunks    │ │                              │                    │
│ │Chunk N-1 ──────┼─┼─────────────────────────────>│ Store chunk N-1   │
│ │Chunk N ────────┼─┼─────────────────────────────>│ Store chunk N     │
│ └────────────────┘ │                              │         │          │
│         │          │  9. Final ACK                │         ↓          │
│         ↓          │<─────────────────────────────┤ ┌────────────────┐ │
│  Wait for Final ACK│                              │ │All chunks OK   │ │
│         │          │                              │ └────────────────┘ │
│         ↓          │                              │         │          │
│ ┌────────────────┐ │  10. Complete Message        │         ↓          │
│ │FileTransfer    │ │                              │ ┌────────────────┐ │
│ │Complete        │ ├─────────────────────────────>│ │Reconstruct File│ │
│ │- transferId    │ │                              │ │- Join chunks   │ │
│ └────────────────┘ │                              │ │- Verify size   │ │
│         │          │                              │ │- Save file     │ │
│         ↓          │                              │ └────────────────┘ │
│  Transfer Success  │                              │  Transfer Success  │
│                    │                              │                    │
└────────────────────┘                              └────────────────────┘

BENEFITS:
- Concurrent chunk sending (up to 10 in-flight)
- Flow control via ACKs
- Reduced latency (no wait per chunk)
- Efficient retransmission (only failed chunks)
```

### WiFi Aware Retry & Error Handling

```
SENDER                                    RECEIVER
┌────────────────┐                       ┌────────────────┐
│ Send Chunk 5   ├──────────────────────>│ Receive OK     │
│ Send Chunk 6   ├──────────────────────>│ Receive OK     │
│ Send Chunk 7   ├─────────X LOST        │                │
│ Send Chunk 8   ├──────────────────────>│ Receive OK     │
│ Send Chunk 9   ├──────────────────────>│ Receive OK     │
└────────┬───────┘                       └────────┬───────┘
         │                                        │
         │ Wait for ACK (batch of 5)              │
         │                                        ↓
         │                               ┌────────────────┐
         │                               │ ACK Batch      │
         │                               │ Received:      │
         │                               │ [5,6,8,9]      │
         │                               │ Missing: [7]   │
         │    ACK: [5,6,8,9]             └────────────────┘
         │<──────────────────────────────         │
         ↓                                        │
┌────────────────┐                                │
│ Process ACK    │                                │
│ - 5,6,8,9 OK   │                                │
│ - 7 MISSING    │                                │
│ - Keep 7 in    │                                │
│   retry queue  │                                │
└────────┬───────┘                                │
         │                                        │
         ↓ Timeout Check (3s)                     │
┌────────────────┐                                │
│ Retry Chunk 7  ├───────────────────────────────>│ Receive Chunk 7 │
└────────┬───────┘                       ┌────────┴───────┐
         │                               │ Now complete:  │
         │                               │ [5,6,7,8,9]    │
         │     ACK: [5,6,7,8,9]          └────────────────┘
         │<──────────────────────────────         │
         ↓                                        │
┌────────────────┐                                │
│ All ACKed      │                                │
│ Slide Window   │                                │
└────────────────┘                                │

MAX RETRIES: 3
If chunk fails 3 times → Transfer fails
```

---

## Bluetooth LE Protocol Flow

### BLE Chunked Transfer with Headers

```
SENDER (Central)                                   RECEIVER (Peripheral)
┌────────────────────┐                            ┌────────────────────┐
│                    │                            │                    │
│ 1. Discovery       │                            │ 1. Advertising     │
│ ┌────────────────┐ │                            │ ┌────────────────┐ │
│ │Scan for        │ │                            │ │Advertise       │ │
│ │BLE Service     │ │<──────────────────────────>│ │BLE Service     │ │
│ │UUID: 52D6E035...│ │    Advertisement Data      │ │UUID: 52D6E035...│ │
│ └────────────────┘ │                            │ │- Device name   │ │
│         │          │                            │ │- Avatar index  │ │
│         ↓          │                            │ └────────────────┘ │
│ 2. Connect Request │                            │                    │
│ ┌────────────────┐ │                            │                    │
│ │CBCentralManager│ ├───────────────────────────>│ 3. Accept Connect  │
│ │.connect()      │ │                            │ ┌────────────────┐ │
│ └────────────────┘ │                            │ │didReceiveConnect│ │
│         │          │                            │ └────────────────┘ │
│         ↓          │    Connection Established   │         │          │
│ 4. Service Discovery                            │         ↓          │
│ ┌────────────────┐ │                            │ 5. Setup Services  │
│ │Discover:       │ │                            │ ┌────────────────┐ │
│ │- Metadata Char │ │                            │ │- Metadata Char │ │
│ │- FileTransfer  │ │                            │ │- FileTransfer  │ │
│ │- ACK Char      │ │                            │ │- ACK Char      │ │
│ └────────────────┘ │                            │ └────────────────┘ │
│         │          │                            │                    │
│         ↓          │                            │                    │
│ 6. MTU Negotiation │                            │                    │
│ ┌────────────────┐ │                            │ ┌────────────────┐ │
│ │Request max MTU │ ├───────────────────────────>│ │Negotiate MTU   │ │
│ │iOS auto-handles│ │<───────────────────────────┤ │iOS auto-handles│ │
│ │Result: 247B    │ │    MTU Negotiated: 247B    │ │Result: 247B    │ │
│ └────────────────┘ │                            │ └────────────────┘ │
│         │          │                            │                    │
│         ↓          │                            │                    │
│ 7. Send Metadata   │                            │                    │
│ ┌────────────────┐ │  8. Metadata Message       │                    │
│ │FileMetadata:   │ │                            │                    │
│ │- fileName      │ ├───────────────────────────>│ 9. Decode Metadata │
│ │- fileSize      │ │  (Characteristic Write)    │ ┌────────────────┐ │
│ │- transferId    │ │                            │ │Show Consent UI │ │
│ └────────────────┘ │                            │ └────────┬───────┘ │
│         │          │                            │          ↓         │
│   Wait for Accept  │                            │    User Accepts    │
│         │          │  10. Accept (implicit)     │          │         │
│         │          │    (No explicit ACK)       │          ↓         │
│         │          │                            │ ┌────────────────┐ │
│         │          │                            │ │Initialize RX   │ │
│         │          │                            │ │Buffer          │ │
│         │          │                            │ └────────────────┘ │
│         ↓          │                            │                    │
│ 11. Calculate Chunks                            │                    │
│ ┌────────────────┐ │                            │                    │
│ │MTU: 247 bytes  │ │                            │                    │
│ │Header: ~50B    │ │                            │                    │
│ │Payload: ~197B  │ │                            │                    │
│ │Total chunks: N │ │                            │                    │
│ └────────────────┘ │                            │                    │
│         │          │                            │                    │
│         ↓          │                            │                    │
│ 12. Send Chunks with Headers                    │                    │
│ ┌────────────────┐ │                            │                    │
│ │Chunk 0:        │ │  13. Chunk 0 Header+Data   │                    │
│ │┌──────────────┐│ │                            │                    │
│ ││Header:       ││ ├───────────────────────────>│ 14. Parse Header   │
│ ││- transferId  ││ │  (FileTransfer Char Write) │ ┌────────────────┐ │
│ ││- chunkIdx: 0 ││ │                            │ │Extract:        │ │
│ ││- total: N    ││ │                            │ │- transferId    │ │
│ │└──────────────┘│ │                            │ │- chunkIndex    │ │
│ │Payload: [...]  │ │                            │ │- totalChunks   │ │
│ └────────────────┘ │                            │ │Store payload   │ │
│         │          │                            │ └────────────────┘ │
│         ↓          │                            │         │          │
│  Wait for write    │  15. Write Response        │         ↓          │
│  response          │<───────────────────────────┤  Write Success     │
│         │          │                            │         │          │
│         ↓          │                            │         ↓          │
│ Send Chunk 1...    │                            │ Process Chunk 1... │
│         │          │                            │         │          │
│     (continues)    │                            │    (continues)     │
│         │          │                            │         │          │
│         ↓          │                            │         ↓          │
│ Every 5 chunks:    │  16. ACK Message           │ Every 5 chunks:    │
│         │          │<───────────────────────────┤ ┌────────────────┐ │
│         ↓          │  (ACK Characteristic)      │ │Send ACK        │ │
│ ┌────────────────┐ │                            │ │Received:[0-4]  │ │
│ │Process ACK     │ │                            │ └────────────────┘ │
│ │- Mark chunks OK│ │                            │                    │
│ │- Update timeout│ │                            │                    │
│ └────────────────┘ │                            │                    │
│         │          │                            │                    │
│ Continue sending   │                            │ Continue receiving │
│         │          │                            │         │          │
│         ↓          │                            │         ↓          │
│ ┌────────────────┐ │  17. Final Chunks          │                    │
│ │Send remaining  │ ├───────────────────────────>│ ┌────────────────┐ │
│ │chunks          │ │                            │ │All chunks      │ │
│ └────────────────┘ │                            │ │received?       │ │
│         │          │  18. Final ACK             │ │YES: Complete   │ │
│         ↓          │<───────────────────────────┤ └────────┬───────┘ │
│ ┌────────────────┐ │                            │          ↓         │
│ │All ACKed       │ │                            │ ┌────────────────┐ │
│ │Transfer Done   │ │                            │ │Reconstruct File│ │
│ └────────────────┘ │                            │ │in order        │ │
│         │          │                            │ │- Join payloads │ │
│         ↓          │                            │ │- Save to disk  │ │
│  Success           │                            │ └────────────────┘ │
│                    │                            │         │          │
│                    │                            │         ↓          │
│                    │                            │    Success         │
│                    │                            │                    │
└────────────────────┘                            └────────────────────┘

CHUNK HEADER FORMAT:
┌──────────────────────────────────────┐
│ [Length: 2 bytes]                    │ ← Length of JSON header
│ [JSON Header]                         │ ← {"transferId":"...","chunkIndex":0,"totalChunks":100}
│ [Payload Data: ~197 bytes]            │ ← Actual file data
└──────────────────────────────────────┘

BENEFITS:
- Multi-transfer support per connection
- Out-of-order chunk handling
- Reliable delivery via ACKs
- Progress tracking per transfer
```

### BLE Retry Mechanism

```
Chunk Timeout Monitoring (Background Task)
┌────────────────────────────────────────────────┐
│ For each transfer:                             │
│   For each sent chunk:                         │
│     if (now - sentTime) > 5 seconds:          │
│       if retryCount < 3:                       │
│         resend chunk                           │
│         retryCount++                           │
│         update timeout                         │
│       else:                                    │
│         FAIL transfer (max retries exceeded)   │
│                                                │
│ Repeat every 1 second                          │
└────────────────────────────────────────────────┘

SENDER                        RECEIVER
┌──────────┐                 ┌──────────┐
│Send Ch 10│────────────────>│ Receive  │
│Send Ch 11│──────X LOST     │          │
│Send Ch 12│────────────────>│ Receive  │
└────┬─────┘                 └────┬─────┘
     │                            │
     │ Wait 5 seconds             │
     ↓                            │
┌──────────┐                      │
│Timeout!  │                      │
│Retry 11  │                      │
│(Attempt 1)                      │
└────┬─────┘                      │
     │                            │
     │─────────────────────────────>│ Receive Ch 11│
     │      ACK: [10,11,12]       │<────────────────┤
     ↓                            │
┌──────────┐                      │
│Retry OK  │                      │
│Continue  │                      │
└──────────┘                      │
```

---

## Queue Management Flow

### Transfer Queue Processing

```
┌─────────────────────────────────────────────────────────────────┐
│                  TransferQueueManager                            │
│                                                                  │
│  LIMITS:                                                         │
│  - Max 2 concurrent sends                                        │
│  - Max 2 concurrent receives                                     │
│  - Max 1 operation per device per type                           │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ↓
         ┌──────────────────────────────────────┐
         │   enqueueOperation(operation)        │
         │   ┌────────────────────────────────┐ │
         │   │ 1. Add to queuedTransfers[]    │ │
         │   │ 2. Add to activeTransfers{}    │ │
         │   │ 3. Store execution closure     │ │
         │   │ 4. Call processQueue()         │ │
         │   └────────────────────────────────┘ │
         └────────────┬─────────────────────────┘
                      │
                      ↓
         ┌────────────────────────────────────────┐
         │        processQueue()                   │
         │                                        │
         │  ┌──────────────────────────────────┐ │
         │  │ Process SENDS:                   │ │
         │  │ while activeSendCount < 2:       │ │
         │  │   find next queued send          │ │
         │  │   if canStartOperation():        │ │
         │  │     startOperation()             │ │
         │  │   else: break                    │ │
         │  └──────────────────────────────────┘ │
         │  ┌──────────────────────────────────┐ │
         │  │ Process RECEIVES:                │ │
         │  │ while activeReceiveCount < 2:    │ │
         │  │   find next queued receive       │ │
         │  │   if canStartOperation():        │ │
         │  │     startOperation()             │ │
         │  │   else: break                    │ │
         │  └──────────────────────────────────┘ │
         └────────────┬───────────────────────────┘
                      │
                      ↓
         ┌────────────────────────────────────────┐
         │    canStartOperation(op)?               │
         │                                        │
         │  If deviceId == nil:                   │
         │    Check unknown device limits         │
         │  Else:                                 │
         │    Check if device already active for  │
         │    this transfer type (send/receive)   │
         │                                        │
         │  Return: true if can start             │
         └────────────┬───────────────────────────┘
                      │
                      ↓
         ┌────────────────────────────────────────┐
         │      startOperation(op)                 │
         │  ┌──────────────────────────────────┐ │
         │  │ 1. Update state to .active       │ │
         │  │ 2. Increment counters            │ │
         │  │    - activeSendCount++           │ │
         │  │    or activeReceiveCount++       │ │
         │  │ 3. Track device active type      │ │
         │  │ 4. Execute operation closure     │ │
         │  └──────────────────────────────────┘ │
         └────────────┬───────────────────────────┘
                      │
                      ↓
         ┌────────────────────────────────────────┐
         │    executeOperation(op) async           │
         │  ┌──────────────────────────────────┐ │
         │  │ Run stored closure:              │ │
         │  │ await closure()                  │ │
         │  │                                  │ │
         │  │ Closure contains actual transfer │ │
         │  │ logic (WiFiAware, BLE, etc.)     │ │
         │  └──────────────────────────────────┘ │
         └────────────┬───────────────────────────┘
                      │
                      ↓
         ┌────────────────────────────────────────┐
         │  completeOperation(id, success)         │
         │  ┌──────────────────────────────────┐ │
         │  │ 1. Update state (.completed/     │ │
         │  │    .failed)                      │ │
         │  │ 2. Decrement counters            │ │
         │  │ 3. Remove from device tracking   │ │
         │  │ 4. Set final progress (1.0/0.0)  │ │
         │  │ 5. Check if all done → notify    │ │
         │  │ 6. processQueue() for next ops   │ │
         │  │ 7. Schedule cleanup after 8s     │ │
         │  └──────────────────────────────────┘ │
         └────────────┬───────────────────────────┘
                      │
                      ↓
         ┌────────────────────────────────────────┐
         │   notifyCompletionIfNeeded()            │
         │  ┌──────────────────────────────────┐ │
         │  │ if all transfers done:           │ │
         │  │   Post notification:             │ │
         │  │   .allTransfersComplete          │ │
         │  │   with userInfo:                 │
         │  │   - completedCount               │ │
         │  │   - failedCount                  │ │
         │  │   - failedTransfers[]            │ │
         │  └──────────────────────────────────┘ │
         └────────────────────────────────────────┘
```

### Example: Multi-File Multi-Device Scenario

```
USER ACTION: Send file.pdf to Device A, B, C

┌────────────────────────────────────────────────────┐
│ NetworkingManager                                   │
│ .sendFileToMultipleDevices(file.pdf, [A, B, C])    │
└────────────┬───────────────────────────────────────┘
             │
             ├─────────────┬─────────────┬──────────────┐
             ↓             ↓             ↓              ↓
      ┌──────────┐  ┌──────────┐  ┌──────────┐
      │ Transfer │  │ Transfer │  │ Transfer │
      │ to A     │  │ to B     │  │ to C     │
      │ ID: T1   │  │ ID: T2   │  │ ID: T3   │
      └────┬─────┘  └────┬─────┘  └────┬─────┘
           │             │             │
           ↓             ↓             ↓
      ┌───────────────────────────────────────┐
      │ TransferQueueManager.enqueueOperation()│
      └────┬──────────────┬────────────┬───────┘
           │              │            │
           ↓              ↓            ↓
      ┌─────────┐    ┌─────────┐  ┌─────────┐
      │ Queue:  │    │ Queue:  │  │ Queue:  │
      │ T1(A)   │    │ T2(B)   │  │ T3(C)   │
      │ State:  │    │ State:  │  │ State:  │
      │ queued  │    │ queued  │  │ queued  │
      └────┬────┘    └────┬────┘  └────┬────┘
           │              │            │
           └──────────────┴────────────┘
                      ↓
           ┌──────────────────────┐
           │   processQueue()     │
           │                      │
           │ activeSendCount = 0  │
           │ Max = 2              │
           └───────┬──────────────┘
                   │
      ┌────────────┴────────────┐
      ↓                         ↓
┌──────────┐             ┌──────────┐
│ Start T1 │             │ Start T2 │
│ to A     │             │ to B     │
│ State:   │             │ State:   │
│ active   │             │ active   │
└────┬─────┘             └────┬─────┘
     │                        │
     │ activeSendCount = 2 (MAX REACHED)
     │                        │
     │  T3 waits in queue     │
     │                        │
     ↓                        ↓
WiFiAware transfer      BLE transfer
to Device A             to Device B
     │                        │
     ↓                        ↓
Progress updates        Progress updates
     │                        │
     ↓                        ↓
T1 Completes            T2 Completes
     │                        │
     ↓                        ↓
completeOperation(T1)   completeOperation(T2)
     │                        │
activeSendCount--       activeSendCount--
     │                        │
     └────────┬───────────────┘
              ↓
       processQueue()
              │
              ↓
      ┌──────────┐
      │ Start T3 │
      │ to C     │
      │ State:   │
      │ active   │
      └────┬─────┘
           │
           ↓
    Multipeer transfer
    to Device C
           │
           ↓
      T3 Completes
           │
           ↓
  completeOperation(T3)
           │
           ↓
    All Done!
    Post .allTransfersComplete
```

---

## Error Handling & Retry Flow

### Transport Fallback Sequence

```
User initiates transfer to Device X
         │
         ↓
┌────────────────────────────────────────────┐
│ NetworkingManager.sendFile()                │
│                                            │
│ selectTransport(for: device)               │
│ Priority: [device.connectionType, ...rest] │
│                                            │
│ Result: [WiFiAware, Multipeer, BLE]        │
└────────┬───────────────────────────────────┘
         │
         ↓
┌────────────────────────────────────────────┐
│ Try Transport 1: WiFiAware                  │
└────────┬───────────────────────────────────┘
         │
         ├─────────────────┐
         ↓                 ↓
    ┌─────────┐       ┌─────────┐
    │ Success │       │ Failure │
    │         │       │ (Error) │
    └────┬────┘       └────┬────┘
         │                 │
         │                 ↓
         │    ┌─────────────────────────────┐
         │    │ Log error                   │
         │    │ Try Transport 2: Multipeer  │
         │    └────────┬────────────────────┘
         │             │
         │             ├─────────────────┐
         │             ↓                 ↓
         │        ┌─────────┐       ┌─────────┐
         │        │ Success │       │ Failure │
         │        └────┬────┘       └────┬────┘
         │             │                 │
         │             │                 ↓
         │             │    ┌─────────────────────┐
         │             │    │ Log error           │
         │             │    │ Try Transport 3: BLE│
         │             │    └────────┬────────────┘
         │             │             │
         │             │             ├──────────────┐
         │             │             ↓              ↓
         │             │        ┌─────────┐    ┌─────────┐
         │             │        │ Success │    │ Failure │
         │             │        └────┬────┘    └────┬────┘
         │             │             │              │
         └─────────────┴─────────────┘              ↓
                       ↓                   ┌──────────────┐
              ┌─────────────────┐         │ All Failed   │
              │ Transfer Success│         │ Throw Error  │
              │ Complete via    │         └──────┬───────┘
              │ queue manager   │                │
              └─────────────────┘                ↓
                                        ┌──────────────────┐
                                        │ NetworkingManager│
                                        │ reports to queue │
                                        │ completeOperation│
                                        │ (success=false)  │
                                        └────────┬─────────┘
                                                 │
                                                 ↓
                                        ┌──────────────────┐
                                        │ AppCoordinator   │
                                        │ .showError()     │
                                        │ with retryAction │
                                        └────────┬─────────┘
                                                 │
                                                 ↓
                                        ┌──────────────────┐
                                        │ ErrorOverlayView │
                                        │ - Show error msg │
                                        │ - "Retry" button │
                                        │ - "Dismiss" btn  │
                                        └──────────────────┘
```

### Detailed Error Recovery Flow

```
ERROR OCCURS                         HANDLER                    UI RESPONSE
─────────────                        ───────                    ───────────

┌────────────────┐
│ WiFiAware      │
│ Connection Lost│
└────────┬───────┘
         │
         ↓
┌────────────────────────────────┐
│ WiFiAwareManager               │
│ catch ConnectionError          │
│ throw to NetworkingManager     │
└────────┬───────────────────────┘
         │
         ↓
┌────────────────────────────────┐   ┌─────────────────────┐
│ NetworkingManager              │   │ AppCoordinator      │
│ 1. Log error                   │   │                     │
│ 2. Try next transport          │   │                     │
│    (Multipeer)                 │   │                     │
│                                │   │                     │
│ If all fail:                   │   │                     │
│ 3. Report to delegate          ├──>│ showError()         │
│    .didUpdateTransferProgress  │   │ currentError = err  │
│    (progress = 0, error state) │   │ retryAction = {...} │
└────────────────────────────────┘   └────────┬────────────┘
                                              │
                                              ↓
                                     ┌─────────────────────┐
                                     │ ErrorOverlayView    │
                                     │ ┌─────────────────┐ │
                                     │ │ Error Message   │ │
                                     │ │ "Transfer failed│ │
                                     │ │  - Connection   │ │
                                     │ │    lost"        │ │
                                     │ └─────────────────┘ │
                                     │ ┌─────────────────┐ │
                                     │ │ [Retry Button]  │─┼──┐
                                     │ └─────────────────┘ │  │
                                     │ ┌─────────────────┐ │  │
                                     │ │[Dismiss Button] │ │  │
                                     │ └─────────────────┘ │  │
                                     └─────────────────────┘  │
                                                              │
                     User taps Retry ─────────────────────────┘
                                              │
                                              ↓
                                     ┌─────────────────────┐
                                     │ Execute retryAction │
                                     │ (Stored closure)    │
                                     └────────┬────────────┘
                                              │
                                              ↓
                                     ┌─────────────────────┐
                                     │ Re-attempt transfer │
                                     │ - Fresh transport   │
                                     │   selection         │
                                     │ - New transferId    │
                                     │ - Re-enqueue        │
                                     └─────────────────────┘
```

### Connection Health Monitoring

```
┌────────────────────────────────────────────────────────┐
│             ConnectionMonitor                           │
│  (Tracks connection health for all active connections) │
└───────────────────────┬────────────────────────────────┘
                        │
         ┌──────────────┴──────────────┐
         │                             │
         ↓                             ↓
┌─────────────────┐          ┌─────────────────┐
│ BLE Connection  │          │ WiFiAware Conn  │
│ Monitor         │          │ Monitor         │
└────────┬────────┘          └────────┬────────┘
         │                            │
         ↓                            ↓
┌─────────────────┐          ┌─────────────────┐
│ Health Checks:  │          │ Health Checks:  │
│ - Signal RSSI   │          │ - Path quality  │
│ - Write success │          │ - Performance   │
│ - Timeout rate  │          │ - Latency       │
└────────┬────────┘          └────────┬────────┘
         │                            │
         └──────────────┬─────────────┘
                        ↓
              ┌──────────────────┐
              │ Health Status    │
              │ ┌──────────────┐ │
              │ │ Healthy      │ │
              │ │ Degraded     │ │
              │ │ Unhealthy    │ │
              │ └──────────────┘ │
              └────────┬─────────┘
                       │
                       ↓
        ┌──────────────────────────────┐
        │ If Unhealthy:                │
        │ - Trigger reconnection       │
        │ - Switch transport if needed │
        │ - Notify user                │
        └──────────────────────────────┘
```

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-XX  
**Author**: AwareShare Team

