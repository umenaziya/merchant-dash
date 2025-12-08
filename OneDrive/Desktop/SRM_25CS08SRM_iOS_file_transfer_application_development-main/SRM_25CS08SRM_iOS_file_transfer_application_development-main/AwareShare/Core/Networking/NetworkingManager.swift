

import Foundation
import Combine
import WiFiAware
import Network
import CoreBluetooth
import MultipeerConnectivity
import UIKit
import OSLog

// MARK: - Main Networking Manager

@MainActor
class NetworkingManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var connectedDevices: [ConnectedDevice] = []
    @Published var isDiscovering = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var transferProgress: [String: Double] = [:]
    @Published var transferStatus: [String: TransferStatus] = [:]
    @Published var activeTransfers: [String: TransferOperation] = [:]
    
    // MARK: - Private Properties
    
    private let wifiAwareManager: WiFiAwareManager
    private let bleManager: BLEManager
    let airDropManager: AirDropManager
    private let multipeerManager: MultipeerManager
    private let transferQueueManager: TransferQueueManager
    private let settingsService = SettingsService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "NetworkingManager")
    weak var delegate: NetworkingManagerDelegate?
    private var fileSizeByTransferId: [String: Int64] = [:]
    
    // MARK: - Initialization
    
    override init() {
        self.wifiAwareManager = WiFiAwareManager()
        self.bleManager = BLEManager()
        self.airDropManager = AirDropManager()
        self.multipeerManager = MultipeerManager()
        self.transferQueueManager = TransferQueueManager()
        
        super.init()
        
        setupDelegates()
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupDelegates() {
        Task {
            await wifiAwareManager.setDelegate(self)
            await wifiAwareManager.setConsentDelegate(self)
        }
        bleManager.delegate = self
        bleManager.setConsentDelegate(self)
        airDropManager.setDelegate(self)
        multipeerManager.delegate = self
    }

    private func setupBindings() {
        // Mirror TransferQueueManager state as single source of truth
        transferQueueManager.$activeTransfers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transfers in
                self?.activeTransfers = transfers
            }
            .store(in: &cancellables)
        
        transferQueueManager.$transferProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.transferProgress = progress
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func startDiscovery() async {
        logger.info("Starting device discovery")
        isDiscovering = true
        
        // Start discovery methods based on enabled transports
        await withTaskGroup(of: Void.self) { group in
            if settingsService.useWiFiAware {
                group.addTask {
                    await self.wifiAwareManager.startDiscovery()
                }
            }
            
            if settingsService.useBluetooth {
                group.addTask {
                    await self.bleManager.startDiscovery()
                }
            }
            
            if settingsService.useMultipeer {
                group.addTask {
                    await self.multipeerManager.startDiscovery()
                }
            }
        }
        
        logger.info("Started discovery for enabled transports")
    }
    
    func stopDiscovery() async {
        logger.info("Stopping device discovery")
        isDiscovering = false
        
        await wifiAwareManager.stopDiscovery()
        await bleManager.stopDiscovery()
        await multipeerManager.stopDiscovery()
        
        discoveredDevices.removeAll()
    }
    
    func resetDiscovery() {
        logger.info("Resetting device discovery")
        discoveredDevices.removeAll()
    }
    
    func connectToDevice(_ device: DiscoveredDevice) async throws {
        logger.info("Connecting to device: \(device.name)")
        
        switch device.connectionType {
        case .wifiAware:
            try await wifiAwareManager.connectToDevice(device)
        case .bluetooth:
            try await bleManager.connectToDevice(device)
        case .airDrop:
            try await airDropManager.connectToDevice(device)
        case .multipeer:
            try await multipeerManager.connectToDevice(device)
        }
    }
    
    func sendFile(_ fileURL: URL, to device: ConnectedDevice) async throws {
        logger.info("Sending file: \(fileURL.lastPathComponent) to \(device.name)")
        
        // Select best transport for this device with fallback options (automatic selection)
        let selectedTransports = selectTransport(for: device)
        logger.info("Auto-selected transports for \(device.name): \(selectedTransports.map { "\($0)" }.joined(separator: ", "))")
        
        try await sendFile(fileURL, to: device, using: selectedTransports)
    }

    func sendFileToMultipleDevices(_ fileURL: URL, to devices: [ConnectedDevice]) async throws -> [String] {
        logger.info("Sending file: \(fileURL.lastPathComponent) to \(devices.count) devices")
        
        // Validate file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NSError(domain: "NetworkingManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "File not accessible"])
        }
        
        var transferIds: [String] = []
        
        // Initiate transfers to all devices (queue will manage concurrency)
        for device in devices {
            do {
                let transferId = UUID().uuidString
                
                logger.info("Queueing transfer to \(device.name) with ID: \(transferId)")
                
                // Use sendFile with explicit transferId to ensure IDs are tied to queued operations
                try await sendFile(fileURL, to: device, using: selectTransport(for: device), transferId: transferId)
                
                transferIds.append(transferId)
            } catch {
                logger.error("Failed to queue transfer to \(device.name): \(error)")
                // Continue with other devices even if one fails
            }
        }
        
        logger.info("Queued \(transferIds.count) transfers")
        return transferIds
    }
    
    func sendFile(_ fileURL: URL, to device: ConnectedDevice, using transports: [ConnectionType]) async throws {
        let transferId = UUID().uuidString
        try await sendFile(fileURL, to: device, using: transports, transferId: transferId)
    }
    
    func sendFile(_ fileURL: URL, to device: ConnectedDevice, using transports: [ConnectionType], transferId: String) async throws {
        logger.info("Sending file: \(fileURL.lastPathComponent) to \(device.name) using user-selected transports")
        
        // Validate and filter transports based on settings
        var validatedTransports = transports.filter { transport in
            let isEnabled = settingsService.isConnectionTypeEnabled(transport)
            if !isEnabled {
                logger.warning("Transport \(transport.rawValue) is disabled in settings, skipping")
            }
            return isEnabled
        }
        
        // If all selected transports are disabled, fall back to automatic selection
        if validatedTransports.isEmpty {
            logger.warning("All user-selected transports are disabled, falling back to automatic selection")
            validatedTransports = selectTransport(for: device)
        }
        
        logger.info("Using transports for \(device.name): \(validatedTransports.map { "\($0)" }.joined(separator: ", "))")
        
        // Extract file size as Int64 with proper error handling
        guard let fileSizeNumber = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber else {
            throw NSError(domain: "NetworkingManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to determine file size"])
        }
        let fileSize = fileSizeNumber.int64Value
        
        // Create transfer operation
        let operation = TransferOperation(
            id: transferId,
            type: .send,
            fileName: fileURL.lastPathComponent,
            fileSize: fileSize,
            deviceName: device.name,
            deviceId: device.id
        )
        
        // Track size for benchmarking only; TransferQueueManager owns state
        fileSizeByTransferId[transferId] = fileSize
        
        // Enqueue operation with execution closure controlled by queue
        transferQueueManager.enqueueOperation(operation) { [weak self] in
            guard let self = self else { return }
            
            var lastError: Error?
            
            // Try each transport in order until one succeeds
            for (attemptIndex, transport) in validatedTransports.enumerated() {
                // Create unique attempt ID for benchmark tracking
                let attemptId = "\(transferId)-attempt\(attemptIndex)-\(transport)"
                
                // Start benchmark tracking for this attempt
                BenchmarkService.shared.startTracking(
                    transferId: attemptId,
                    fileName: fileURL.lastPathComponent,
                    fileSize: Int64(fileSize),
                    deviceName: device.name,
                    connectionType: transport
                )
                
                do {
                    self.logger.info("Attempting send via \(String(describing: transport)) for transfer \(transferId) (attempt \(attemptIndex))")
                    
                    switch transport {
                    case .wifiAware:
                        try await self.wifiAwareManager.sendFile(fileURL, to: device, transferId: transferId)
                    case .bluetooth:
                        try await self.bleManager.sendFile(fileURL, to: device, transferId: transferId)
                    case .airDrop:
                        try await self.airDropManager.sendFile(fileURL, to: device, transferId: transferId)
                    case .multipeer:
                        try await self.multipeerManager.sendFile(fileURL, to: device, transferId: transferId)
                    }
                    
                    // Success!
                    BenchmarkService.shared.completeTransfer(transferId: attemptId, success: true)
                    await self.transferQueueManager.completeOperation(transferId, success: true)
                    self.logger.info("Successfully sent file via \(String(describing: transport))")
                    return
                    
                } catch {
                    self.logger.warning("Failed to send via \(String(describing: transport)): \(error.localizedDescription)")
                    lastError = error
                    BenchmarkService.shared.completeTransfer(transferId: attemptId, success: false, error: error.localizedDescription)
                    // Continue to next transport
                }
            }
            
            // All transports failed
            let finalError = lastError ?? NSError(domain: "NetworkingManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "All transports failed"])
            await self.transferQueueManager.completeOperation(transferId, success: false, error: finalError)
            self.logger.error("All transports failed for transfer \(transferId)")
        }
    }
    
    func receiveFile(from device: ConnectedDevice) async throws -> URL {
        logger.info("Receiving file from: \(device.name)")
        
        let transferId = UUID().uuidString
        
        // Create transfer operation (file size unknown at this point)
        let operation = TransferOperation(
            id: transferId,
            type: .receive,
            fileName: "Receiving...",
            fileSize: 0,
            deviceName: device.name,
            deviceId: device.id
        )
        
        // Add to ReceiveManager for UI tracking
        await MainActor.run {
            ReceiveManager.shared.addActiveReceive(
                ActiveReceive(
                    transferId: transferId,
                    fileName: "Receiving...",
                    deviceName: device.name
                )
            )
        }
        
        // TransferQueueManager owns state
        
        // Start benchmark tracking with estimated/unknown file size (0)
        // Will be updated as metadata arrives if possible
        BenchmarkService.shared.startTracking(
            transferId: transferId,
            fileName: "Receiving...",
            fileSize: 0,
            deviceName: device.name,
            connectionType: device.connectionType
        )
        
        // Await the reception via continuation that runs inside the queued execution
        let fileURL: URL = try await withCheckedThrowingContinuation { continuation in
            Task { [weak self] in
                guard let self = self else { return }
                self.transferQueueManager.enqueueOperation(operation) { [weak self] in
                    guard let self = self else { return }
                    do {
                        let receivedURL: URL
                        switch device.connectionType {
                        case .wifiAware:
                            receivedURL = try await self.wifiAwareManager.receiveFile(from: device, transferId: transferId)
                        case .bluetooth:
                            receivedURL = try await self.bleManager.receiveFile(from: device, transferId: transferId)
                        case .airDrop:
                            receivedURL = try await self.airDropManager.receiveFile(from: device, transferId: transferId)
                        case .multipeer:
                            receivedURL = try await self.multipeerManager.receiveFile(from: device, transferId: transferId)
                        }
                        
                        // Update ReceiveManager with completion
                        await MainActor.run {
                            ReceiveManager.shared.completeReceive(transferId, success: true)
                        }
                        
                        BenchmarkService.shared.completeTransfer(transferId: transferId, success: true)
                        await self.transferQueueManager.completeOperation(transferId, success: true)
                        continuation.resume(returning: receivedURL)
                    } catch {
                        // Update ReceiveManager with failure
                        await MainActor.run {
                            ReceiveManager.shared.completeReceive(transferId, success: false)
                        }
                        
                        BenchmarkService.shared.completeTransfer(transferId: transferId, success: false, error: error.localizedDescription)
                        await self.transferQueueManager.completeOperation(transferId, success: false, error: error)
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        return fileURL
    }
    
    func disconnectFromDevice(_ device: ConnectedDevice) async {
        logger.info("Disconnecting from device: \(device.name)")
        
        switch device.connectionType {
        case .wifiAware:
            await wifiAwareManager.disconnectFromDevice(device)
        case .bluetooth:
            await bleManager.disconnectFromDevice(device)
        case .airDrop:
            await airDropManager.disconnectFromDevice(device)
        case .multipeer:
            await multipeerManager.disconnectFromDevice(device)
        }
        
        connectedDevices.removeAll { $0.id == device.id }
    }
}

// MARK: - ConsentPrompting

extension NetworkingManager: ConsentPrompting {
    
    func didRequestFileTransfer(
        fileName: String,
        fileSize: Int64,
        from device: ConnectedDevice,
        respond: @escaping (Bool, Bool) -> Void
    ) {
        logger.info("File transfer consent requested: \(fileName) (\(fileSize) bytes) from \(device.name) [ID: \(device.id)]")
        
        // Present consent alert directly
        let alert = UIAlertController(
            title: "Incoming file",
            message: "\(fileName) (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))) from \(device.name)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Reject", style: .destructive) { _ in
            respond(false, false)
        })
        
        alert.addAction(UIAlertAction(title: "Accept", style: .default) { _ in
            respond(true, false)
        })
        
        alert.addAction(UIAlertAction(title: "Accept & Trust", style: .default) { [weak self] _ in
            respond(true, true)
            self?.logger.info("Trusted device: \(device.name) [ID: \(device.id)]")
        })
        
        // Present on main thread
        Task { @MainActor in
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
    }
}

// MARK: - NetworkingManagerDelegate

extension NetworkingManager: NetworkingManagerDelegate {
    
    func didDiscoverDevice(_ device: DiscoveredDevice) {
        logger.info("Discovered device: \(device.name)")
        
        // Filter out Android devices if disabled via capability
        if device.type == .android && !settingsService.androidDevicesEnabled {
            return
        }
        
        // Debounce duplicates within 2 seconds
        struct Recent { static var seen: [String: Date] = [:] }
        let now = Date()
        if let last = Recent.seen[device.id], now.timeIntervalSince(last) < 2.0 {
            return
        }
        Recent.seen[device.id] = now
        
        if !discoveredDevices.contains(where: { $0.id == device.id }) {
            discoveredDevices.append(device)
        }
        delegate?.didDiscoverDevice(device)
    }
    
    func didConnectToDevice(_ device: ConnectedDevice) {
        logger.info("Connected to device: \(device.name)")
        
        // Remove from discovered devices
        discoveredDevices.removeAll { $0.id == device.id }
        
        // Add to connected devices
        if !connectedDevices.contains(where: { $0.id == device.id }) {
            connectedDevices.append(device)
        }
        
        connectionStatus = .connected
        delegate?.didConnectToDevice(device)
    }
    
    func didDisconnectFromDevice(_ device: ConnectedDevice) {
        logger.info("Disconnected from device: \(device.name)")
        
        connectedDevices.removeAll { $0.id == device.id }
        
        if connectedDevices.isEmpty {
            connectionStatus = .disconnected
        }
        delegate?.didDisconnectFromDevice(device)
    }
    
    // MARK: - Transport Selection
    
    /// Select best available transports for a device based on capabilities and user settings
    func selectTransport(for device: ConnectedDevice) -> [ConnectionType] {
        // Get transport priority order from settings
        var availableTransports = settingsService.getTransportPriorityOrder()
        
        // Filter out the device's current connection type and prioritize it
        availableTransports.removeAll { $0 == device.connectionType }
        availableTransports.insert(device.connectionType, at: 0)
        
        // Only include enabled transports
        availableTransports = availableTransports.filter { transport in
            settingsService.isConnectionTypeEnabled(transport)
        }
        
        // If no transports are enabled, fall back to the device's connection type
        if availableTransports.isEmpty {
            availableTransports.append(device.connectionType)
        }
        
        logger.debug("Selected transport order for \(device.name): \(availableTransports.map { "\($0)" }.joined(separator: " → "))")
        
        return availableTransports
    }
    
    func didUpdateTransferProgress(_ progress: Double, for transferId: String) {
        Task {
            transferQueueManager.updateProgress(transferId, progress: progress)
            
            // Update ReceiveManager if this is a receive operation
            if let operation = transferQueueManager.activeTransfers[transferId],
               operation.type == .receive {
                let metrics = BenchmarkService.shared.getMetrics(for: transferId)
                await MainActor.run {
                    ReceiveManager.shared.updateReceiveProgress(
                        transferId,
                        progress: progress,
                        speed: metrics?.averageSpeed ?? 0
                    )
                }
            }
        }
        
        if let size = fileSizeByTransferId[transferId] {
            let bytesTransferred = Int64(progress * Double(size))
            BenchmarkService.shared.updateProgress(transferId: transferId, bytesTransferred: bytesTransferred)
        }
        
        // Clean up file size tracking when transfer completes
        if progress >= 1.0 {
            fileSizeByTransferId.removeValue(forKey: transferId)
        }
        
        delegate?.didUpdateTransferProgress(progress, for: transferId)
    }
    
    func didReceiveFile(_ fileURL: URL, from device: ConnectedDevice) {
        logger.info("Received file: \(fileURL.lastPathComponent) from \(device.name)")
        
        // Handle received file (save to documents directory, etc.)
        handleReceivedFile(fileURL, from: device)
        delegate?.didReceiveFile(fileURL, from: device)
    }
    
    /// Complete a transfer operation. This method can be called by managers (like MockDeviceManager) to signal transfer completion.
    func completeTransfer(_ transferId: String, success: Bool, error: Error? = nil) async {
        logger.info("Completing transfer \(transferId), success: \(success)")
        await transferQueueManager.completeOperation(transferId, success: success, error: error)
    }
    
    private func handleReceivedFile(_ fileURL: URL, from device: ConnectedDevice) {
        // Move file to documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent(fileURL.lastPathComponent)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: fileURL, to: destinationURL)
            
            logger.info("File saved to: \(destinationURL.path)")
            
        } catch {
            logger.error("Failed to save received file: \(error)")
        }
    }
}

// MARK: - Supporting Types

protocol NetworkingManagerDelegate: AnyObject {
    func didDiscoverDevice(_ device: DiscoveredDevice)
    func didConnectToDevice(_ device: ConnectedDevice)
    func didDisconnectFromDevice(_ device: ConnectedDevice)
    func didUpdateTransferProgress(_ progress: Double, for transferId: String)
    func didReceiveFile(_ fileURL: URL, from device: ConnectedDevice)
}

enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error(Error)
}

enum TransferStatus {
    case sending
    case receiving
    case completed
    case failed(Error)
}

struct ConnectedDevice: Identifiable {
    let id: String
    let name: String
    let type: DeviceType
    let connectionType: ConnectionType
    let isAvailable: Bool
    let connection: Any // Store the actual connection object
    let avatarIndex: Int? // Avatar index from remote device
}

// MARK: - Service Configuration

struct ServiceConfiguration {
    static let awareShareServiceName = "_awareshare._tcp"
    static let bleServiceUUID = CBUUID(string: NetworkingConstants.ServiceUUIDs.bleService)
    static let multipeerServiceType = "awareshare"
}
