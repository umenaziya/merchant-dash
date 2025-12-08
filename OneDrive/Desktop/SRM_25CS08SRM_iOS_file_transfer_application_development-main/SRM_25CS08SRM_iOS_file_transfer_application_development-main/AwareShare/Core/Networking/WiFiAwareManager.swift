

import Foundation
import WiFiAware
import Network
import OSLog

// MARK: - Wi-Fi Aware Manager
// Note: This manager uses WiFiAware framework which requires iOS 26.0+, 
// so Wi-Fi Aware features will only be available on iOS 26.0 and later.

actor WiFiAwareManager: WiFiAwareManagerProtocol, Sendable {
    
    // MARK: - Properties
    
    weak var delegate: NetworkingManagerDelegate?
    weak var consentDelegate: ConsentPrompting?
    
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "WiFiAwareManager")
    private let settingsService = SettingsService.shared
    
    // MARK: - Delegate Management
    
    func setDelegate(_ delegate: NetworkingManagerDelegate?) {
        self.delegate = delegate
    }
    
    func setConsentDelegate(_ consentDelegate: ConsentPrompting?) {
        self.consentDelegate = consentDelegate
    }
    
    private var networkManager: NetworkManager?
    private var connectionManager: ConnectionManager?
    private var endpointRegistry: [String: WAEndpoint] = [:]
    private var isDiscovering = false
    private var isPublishing = false
    
    // File transfer tracking
    private var fileReceptionContinuations: [String: CheckedContinuation<URL, Error>] = [:]
    private var receivedFileMetadata: [String: (fileName: String, totalChunks: Int)] = [:]
    private var handshakeContinuations: [String: CheckedContinuation<Bool, Never>] = [:]
    private var handshakeTimeoutTasks: [String: Task<Void, Never>] = [:]
    private var handshakeResumed: [String: Bool] = [:]
    private var connectionsByDeviceId: [String: WiFiAwareConnection] = [:]
    private var transferIdToConnection: [String: WiFiAwareConnection] = [:]
    private var receiveTimeoutTasks: [String: Task<Void, Error>] = [:]
    
    // Sliding window components
    private var slidingWindowManagers: [String: SlidingWindowTransferManager] = [:]
    private var chunkReceivers: [String: ChunkReceiver] = [:]
    
    // Event monitoring tasks for cleanup
    private var eventMonitoringTasks: [Task<Void, Never>] = []
    
    // MARK: - Initialization
    
    init() {
        // Initialize managers
    }

    func startDiscovery() async {
        logger.info("Starting Wi-Fi Aware discovery")
        
        guard !isDiscovering else { return }
        isDiscovering = true
        
        do {
            // Start browsing for services
            try await startBrowsing()
        } catch {
            logger.error("Failed to start Wi-Fi Aware discovery: \(error)")
            isDiscovering = false
        }
    }
    
    func stopDiscovery() async {
        logger.info("Stopping Wi-Fi Aware discovery")
        
        isDiscovering = false
        isPublishing = false
        
        // Cancel all event monitoring tasks
        for task in eventMonitoringTasks {
            task.cancel()
        }
        eventMonitoringTasks.removeAll()
        
        // Stop network manager
        networkManager = nil
        connectionManager = nil
    }
    
    private func startBrowsing() async throws {
        let connectionManager = ConnectionManager()
        let networkManager = NetworkManager(connectionManager: connectionManager)
        
        self.connectionManager = connectionManager
        self.networkManager = networkManager
        
        // Start browsing for AwareShare services
        try await networkManager.browse()
        
        // Listen for incoming connections
        try await networkManager.listen()
        
        // Monitor network events with connection context
        let networkTask = Task {
            for await (event, connection) in connectionManager.networkEventsWithConnection {
                if Task.isCancelled { break }
                await handleNetworkEvent(event, from: connection)
            }
        }
        eventMonitoringTasks.append(networkTask)
        
        // Monitor local events
        let localTask = Task {
            for await event in connectionManager.localEvents {
                if Task.isCancelled { break }
                await handleLocalEvent(event)
            }
        }
        eventMonitoringTasks.append(localTask)

        // Also listen to NetworkManager.localEvents to consume browser discovery events
        let browserTask = Task {
            guard let networkManager = self.networkManager else { return }
            for await event in networkManager.localEvents {
                if Task.isCancelled { break }
                await self.handleLocalEvent(event)
            }
        }
        eventMonitoringTasks.append(browserTask)
    }
    
    func startPublishing() async throws {
        logger.info("Starting Wi-Fi Aware publishing")
        
        guard !isPublishing else { return }
        isPublishing = true
        
        let connectionManager = ConnectionManager()
        let networkManager = NetworkManager(connectionManager: connectionManager)
        
        self.connectionManager = connectionManager
        self.networkManager = networkManager
        
        // Start listening for connections
        try await networkManager.listen()
        
        // Monitor network events with connection context
        let task1 = Task { [weak self, connectionManager] in
            guard let self = self else { return }
            for await (event, connection) in connectionManager.networkEventsWithConnection {
                await self.handleNetworkEvent(event, from: connection)
            }
        }
        eventMonitoringTasks.append(task1)
        
        // Monitor local events
        let task2 = Task { [weak self, connectionManager] in
            guard let self = self else { return }
            for await event in connectionManager.localEvents {
                await self.handleLocalEvent(event)
            }
        }
        eventMonitoringTasks.append(task2)

        // Also listen to NetworkManager.localEvents to consume browser discovery events
        let task3 = Task { [weak self, weak networkManager] in
            guard let self = self, let networkManager = networkManager else { return }
            for await event in networkManager.localEvents {
                await self.handleLocalEvent(event)
            }
        }
        eventMonitoringTasks.append(task3)
    }
    
    // MARK: - Connection Methods
    
    func connectToDevice(_ device: DiscoveredDevice) async throws {
        logger.info("Connecting to Wi-Fi Aware device: \(device.name)")
        
        guard let connectionManager = connectionManager else {
            throw NSError(domain: "WiFiAwareManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Connection manager not initialized"])
        }
        
        // Look up the endpoint from the registry
        guard let endpoint = endpointRegistry[device.id] else {
            throw NSError(domain: "WiFiAwareManager", code: 7, userInfo: [NSLocalizedDescriptionKey: "Endpoint not found for device \(device.id)"])
        }
        
        // Establish targeted connection to the selected endpoint
        await connectionManager.setupConnection(to: endpoint)
        logger.info("Initiated connection to endpoint for device: \(device.name)")
    }
    
    func disconnectFromDevice(_ device: ConnectedDevice) async {
        logger.info("Disconnecting from Wi-Fi Aware device: \(device.name)")
        
        // Cleanup device state
        await cleanupDeviceState(deviceId: device.id)
        
        // Notify delegate of disconnection
        if let delegate = delegate {
            await MainActor.run {
                delegate.didDisconnectFromDevice(device)
            }
        }
    }
    
    // MARK: - Cleanup Helper
    
    /// Consolidates cleanup logic for disconnect and error scenarios
    private func cleanupDeviceState(deviceId: String) async {
        logger.info("Cleaning up device state for: \(deviceId)")
        
        // Look up connection
        guard let connection = connectionsByDeviceId[deviceId] else {
            logger.warning("No connection found for device: \(deviceId)")
            return
        }
        
        // Cancel active transfers for this device
        let transfersToCancel = transferIdToConnection.compactMap { (transferId, transferConnection) in
            transferConnection.id == connection.id ? transferId : nil
        }
        
        for transferId in transfersToCancel {
            // Cancel sliding window managers
            slidingWindowManagers.removeValue(forKey: transferId)
            
            // Cancel chunk receivers
            chunkReceivers.removeValue(forKey: transferId)
            
            // Cancel handshake continuations
            if handshakeResumed[transferId] == false {
                handshakeTimeoutTasks[transferId]?.cancel()
                handshakeTimeoutTasks.removeValue(forKey: transferId)
                handshakeResumed[transferId] = true
                if let cont = handshakeContinuations.removeValue(forKey: transferId) {
                    cont.resume(returning: false)
                }
                handshakeResumed.removeValue(forKey: transferId)
            }
            
            // Clean up transfer tracking
            transferIdToConnection.removeValue(forKey: transferId)
            receivedFileMetadata.removeValue(forKey: transferId)
        }
        
        // Teardown connection via connection manager
        if let connectionManager = connectionManager {
            await connectionManager.stop(connection)
            logger.info("Stopped connection for device: \(deviceId)")
        }
        
        // Close network manager if this was the last connection
        let remainingConnections = connectionsByDeviceId.filter { $0.key != deviceId }
        if remainingConnections.isEmpty, let networkManager = networkManager {
            // Network manager will be cleaned up when discovery stops
            logger.info("No remaining connections, network manager will be cleaned up on next discovery stop")
        }
        
        // Remove from connections dictionary
        connectionsByDeviceId.removeValue(forKey: deviceId)
        
        logger.info("Cleanup complete for device: \(deviceId)")
    }
    
    // MARK: - File Transfer Methods
    
    func sendFile(_ fileURL: URL, to device: ConnectedDevice, transferId: String) async throws {
        logger.info("Sending file via Wi-Fi Aware: \(fileURL.lastPathComponent)")
        
        guard let networkManager = networkManager else {
            throw NSError(domain: "WiFiAwareManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network manager not initialized"])
        }
        
        // Prepare file streaming and metadata
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let totalSize = (fileAttributes[.size] as? NSNumber)?.intValue ?? 0
        let fileName = fileURL.lastPathComponent
        
        // Determine transfer method based on file size
        let shouldUseDataPath = shouldUseDataPathForFile(size: totalSize)
        logger.info("File size: \(totalSize) bytes, using data path: \(shouldUseDataPath)")
        
        // Get target connection
        guard let connection = connectionsByDeviceId[device.id] else {
            throw NSError(domain: "WiFiAwareManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No connection found for device"])
        }
        
        // Setup data path for large files if needed
        if shouldUseDataPath {
            try await setupDataPathForTransfer(connection: connection, transferId: transferId)
        }
        
        // Handshake: request (targeted)
        await networkManager.send(.fileTransferRequest(fileName: fileName, fileSize: totalSize, transferId: transferId, useDataPath: shouldUseDataPath), to: connection)
        
        // Wait for accept or reject via continuation with proper timeout handling
        let accepted: Bool = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            handshakeContinuations[transferId] = continuation
            handshakeResumed[transferId] = false
            
            // Create timeout task
            let timeoutTask = Task { 
                try? await Task.sleep(nanoseconds: UInt64(settingsService.handshakeTimeoutSeconds * 1_000_000_000)) // Use settings
                
                // Check if already resumed
                guard self.handshakeResumed[transferId] == false else { return }
                
                // Mark as resumed and clean up
                self.handshakeResumed[transferId] = true
                if let c = self.handshakeContinuations.removeValue(forKey: transferId) { 
                    c.resume(returning: false)
                }
                self.handshakeTimeoutTasks.removeValue(forKey: transferId)
            }
            
            handshakeTimeoutTasks[transferId] = timeoutTask
        }
        
        guard accepted else {
            await networkManager.send(.fileTransferError(transferId: transferId, error: "Receiver rejected or timed out"), to: connection)
            throw NSError(domain: "WiFiAwareManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Receiver rejected or timed out"])
        }
        
        // Get settings values on main actor to avoid isolation issues
        let windowSize = await MainActor.run { settingsService.slidingWindowSize }
        let handshakeTimeout = await MainActor.run { settingsService.handshakeTimeoutSeconds }
        let preferredChunkSize = await MainActor.run { settingsService.preferredChunkSize }
        
        // Initialize sliding window manager for this transfer
        let slidingWindowManager = SlidingWindowTransferManager(
            windowSize: windowSize, 
            retryTimeout: handshakeTimeout, 
            maxRetries: 3
        )
        slidingWindowManagers[transferId] = slidingWindowManager
        
        // Send file using sliding window protocol with streaming
        do {
            // Chunk size configurable via SettingsService; clamp to 8-16KB
            let preferred = max(8 * 1024, min(preferredChunkSize, 16 * 1024))
            guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else { throw NSError(domain: "WiFiAwareManager", code: 8, userInfo: [NSLocalizedDescriptionKey: "Unable to open file"]) }
            defer { try? fileHandle.close() }

            func provideChunk(_ index: Int) async -> Data? {
                let offset = Int64(index * preferred)
                do {
                    try fileHandle.seek(toOffset: UInt64(offset))
                    let remaining = totalSize - index * preferred
                    let size = max(0, min(preferred, remaining))
                    if size <= 0 { return Data() }
                    return try fileHandle.read(upToCount: size)
                } catch {
                    return nil
                }
            }

            try await slidingWindowManager.startSending(totalSize: totalSize, chunkSize: preferred, provideChunk: { idx in
                await provideChunk(idx)
            }, sendChunk: { [weak self] chunkIndex, totalChunks, chunkData in
                guard let self = self else { return }
                await self.networkManager?.send(
                    .fileChunk(transferId: transferId, chunkIndex: chunkIndex, totalChunks: totalChunks, data: chunkData),
                    to: connection
                )
                let progress = await slidingWindowManager.getProgress()
                if let delegate = await self.delegate {
                    await MainActor.run { delegate.didUpdateTransferProgress(progress, for: transferId) }
                }
            })
            
            // Wait for transfer to complete
            while !(await slidingWindowManager.isTransferComplete()) {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            
            // Send completion message
            await networkManager.send(.fileTransferComplete(transferId: transferId), to: connection)
            logger.info("File sent successfully via Wi-Fi Aware with sliding window")
            
            // Clean up
            slidingWindowManagers.removeValue(forKey: transferId)
            
        } catch {
            await networkManager.send(.fileTransferError(transferId: transferId, error: error.localizedDescription), to: connection)
            slidingWindowManagers.removeValue(forKey: transferId)
            throw error
        }
    }
    

    private func removeFileReceptionContinuation(transferId: String) -> CheckedContinuation<URL, Error>? {
        return fileReceptionContinuations.removeValue(forKey: transferId)
    }

    private func removeReceiveTimeoutTask(transferId: String) {
        receiveTimeoutTasks.removeValue(forKey: transferId)
    }
    
    func receiveFile(from device: ConnectedDevice, transferId: String) async throws -> URL {
        logger.info("Receiving file via Wi-Fi Aware from: \(device.name)")
        
        // Get configurable timeout from settings
        let timeoutSeconds = await MainActor.run { settingsService.receiveTimeoutSeconds }
        

        return try await withCheckedThrowingContinuation { continuation in
            // Store continuation for when file is received
            fileReceptionContinuations[transferId] = continuation
            
            // Set timeout for file reception (configurable via SettingsService)
            let timeoutTask = Task<Void, Error> {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                if Task.isCancelled { return }
                
                let storedContinuation = await removeFileReceptionContinuation(transferId: transferId)
                if let storedContinuation = storedContinuation {
                    storedContinuation.resume(throwing: NSError(domain: "WiFiAwareManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "File transfer timed out"]))
                    await removeReceiveTimeoutTask(transferId: transferId)
                    logger.warning("File transfer timed out: \(transferId)")
                }
            }
            receiveTimeoutTasks[transferId] = timeoutTask
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleNetworkEvent(_ event: NetworkEvent, from connection: WiFiAwareConnection?) async {
        switch event {
        case .startStreaming:
            break
        case .satelliteMovedTo:
            break
        case .fileTransferRequest(let fileName, let fileSize, let transferId, let useDataPath):
            // Consent: auto-accept if setting enabled or device trusted; otherwise ask delegate
            let autoAccept = await MainActor.run { settingsService.autoAcceptTransfers }
            var shouldAccept = autoAccept
            if let connection = connection {
                let senderId = connection.id
                let isTrusted = await MainActor.run { settingsService.isTrustedDevice(senderId) }
                if isTrusted { shouldAccept = true }
            }
            if !shouldAccept, let consentDelegate = consentDelegate, let connection = connection {
                // Create a ConnectedDevice shim for prompt
                let device = ConnectedDevice(
                    id: connection.id,
                    name: "Wi-Fi Aware Device",
                    type: .unknown,
                    connectionType: .wifiAware,
                    isAvailable: true,
                    connection: connection,
                    avatarIndex: nil
                )
                // Ask UI (on main)
                let accepted: Bool = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                    Task { @MainActor in
                        consentDelegate.didRequestFileTransfer(fileName: fileName, fileSize: Int64(fileSize), from: device, respond: { decision, trust in
                            cont.resume(returning: decision)
                            if trust { Task { await self.addTrusted(deviceId: device.id) } }
                        })
                    }
                }
                shouldAccept = accepted
            }
            if let connection = connection {
                if shouldAccept {
                    // Setup data path for large files if requested
                    if useDataPath {
                        do {
                            try await setupDataPathForTransfer(connection: connection, transferId: transferId)
                            logger.info("Data path configured for incoming transfer: \(transferId)")
                        } catch {
                            logger.error("Failed to setup data path for transfer \(transferId): \(error)")
                            await networkManager?.send(.fileTransferReject(transferId: transferId, reason: "Data path setup failed"), to: connection)
                            return
                        }
                    }
                    
                    await networkManager?.send(.fileTransferAccept(transferId: transferId), to: connection)
                    transferIdToConnection[transferId] = connection
                } else {
                    await networkManager?.send(.fileTransferReject(transferId: transferId, reason: "User rejected"), to: connection)
                    return
                }
            } else {
                await networkManager?.sendToAll(.fileTransferReject(transferId: transferId, reason: "No connection context"))
                return
            }
            // Initialize chunk receiver
            let ackBatchSize = await MainActor.run { settingsService.ackBatchSize }
            let chunkReceiver = ChunkReceiver(ackBatchSize: ackBatchSize)
            chunkReceivers[transferId] = chunkReceiver
            receivedFileMetadata[transferId] = (fileName: fileName, totalChunks: 0)
            logger.info("Accepted transfer \(fileName) (\(fileSize) bytes) id=\(transferId)")
        case .fileChunk(let transferId, let chunkIndex, let totalChunks, let data):
            guard let chunkReceiver = chunkReceivers[transferId] else {
                logger.error("No chunk receiver for transfer \(transferId)")
                return
            }
            
            // Process once and send ack if needed
            let ackSet = await chunkReceiver.processChunk(chunkIndex: chunkIndex, data: data, totalChunks: totalChunks)
            if let receivedChunks = ackSet {
                // Send acknowledgment using the native chunkAck case
                let ackMessage = NetworkEvent.chunkAck(transferId: transferId, received: receivedChunks)
                if let connection = connection {
                    await networkManager?.send(ackMessage, to: connection)
                } else {
                    await networkManager?.sendToAll(ackMessage)
                }
                logger.debug("Sent ack for transfer \(transferId): chunks \(receivedChunks)")
            }
            
            // Update metadata with total chunks
            if var metadata = receivedFileMetadata[transferId] {
                metadata.totalChunks = totalChunks
                receivedFileMetadata[transferId] = metadata
            }
            
            // Update progress using receiver status
            let isComplete = await chunkReceiver.isComplete()
            let receivedCount = await chunkReceiver.receivedCount()
            let progress: Double
            if isComplete {
                progress = 1.0
            } else if totalChunks == 0 {
                progress = 0.0
            } else {
                progress = Double(receivedCount) / Double(totalChunks)
            }
            if let delegate = delegate {
                await MainActor.run { delegate.didUpdateTransferProgress(progress, for: transferId) }
            }
        case .fileTransferComplete(let transferId):
            guard let chunkReceiver = chunkReceivers[transferId] else {
                logger.error("No chunk receiver for transfer \(transferId)")
                return
            }
            guard let metadata = receivedFileMetadata[transferId] else { return }
            
            // Validate: check if we received all chunks
            let isComplete = await chunkReceiver.isComplete()
            
            if !isComplete {
                let missingChunks = await chunkReceiver.getMissingChunks()
                logger.error("Incomplete transfer: missing chunks \(missingChunks)")
                if let senderConnection = transferIdToConnection[transferId] {
                    await networkManager?.send(.fileTransferError(transferId: transferId, error: "Incomplete transfer: missing chunks \(missingChunks)"), to: senderConnection)
                } else {
                    await networkManager?.sendToAll(.fileTransferError(transferId: transferId, error: "Incomplete transfer: missing chunks \(missingChunks)"))
                }
                // Cancel timeout task
                receiveTimeoutTasks[transferId]?.cancel()
                receiveTimeoutTasks.removeValue(forKey: transferId)
                
                if let continuation = fileReceptionContinuations.removeValue(forKey: transferId) {
                    continuation.resume(throwing: NSError(domain: "WiFiAwareManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Incomplete file transfer"]))
                }
                chunkReceivers.removeValue(forKey: transferId)
                receivedFileMetadata.removeValue(forKey: transferId)
                transferIdToConnection.removeValue(forKey: transferId)
                return
            }
            
            // Get complete data
            guard let completeData = await chunkReceiver.getCompleteData() else {
                logger.error("Failed to reconstruct file data")
                
                // Cancel timeout task
                receiveTimeoutTasks[transferId]?.cancel()
                receiveTimeoutTasks.removeValue(forKey: transferId)
                
                if let continuation = fileReceptionContinuations.removeValue(forKey: transferId) {
                    continuation.resume(throwing: NSError(domain: "WiFiAwareManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to reconstruct file"]))
                }
                chunkReceivers.removeValue(forKey: transferId)
                receivedFileMetadata.removeValue(forKey: transferId)
                transferIdToConnection.removeValue(forKey: transferId)
                return
            }
            
            let fileName = metadata.fileName
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            var destinationURL = documentsPath.appendingPathComponent(fileName)
            // Collision-safe save if file exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                let overwriteExisting = await MainActor.run { settingsService.overwriteExisting }
                if overwriteExisting {
                    // overwrite
                } else {
                    let fileBase = destinationURL.deletingPathExtension().lastPathComponent
                    let fileExt = destinationURL.pathExtension
                    var counter = 1
                    while FileManager.default.fileExists(atPath: destinationURL.path) {
                        let newName = fileExt.isEmpty ? "\(fileBase) (\(counter))" : "\(fileBase) (\(counter)).\(fileExt)"
                        destinationURL = documentsPath.appendingPathComponent(newName)
                        counter += 1
                    }
                }
            }
            do {
                try completeData.write(to: destinationURL)
                logger.info("File saved to: \(destinationURL.path)")
                
                // Cancel timeout task to avoid racing completions
                receiveTimeoutTasks[transferId]?.cancel()
                receiveTimeoutTasks.removeValue(forKey: transferId)
                
                // Resume continuation
                if let continuation = fileReceptionContinuations.removeValue(forKey: transferId) {
                    continuation.resume(returning: destinationURL)
                }
                
                // Notify delegate of received file
                if let delegate = delegate, let senderConnection = transferIdToConnection[transferId] {
                    // Create a connected device from the connection
                    let connectedDevice = ConnectedDevice(
                        id: senderConnection.id,
                        name: "Wi-Fi Aware Device",
                        type: .unknown,
                        connectionType: .wifiAware,
                        isAvailable: true,
                        connection: senderConnection,
                        avatarIndex: nil
                    )
                    
                    await MainActor.run {
                        delegate.didReceiveFile(destinationURL, from: connectedDevice)
                    }
                }
                
                // Clean up
                chunkReceivers.removeValue(forKey: transferId)
                receivedFileMetadata.removeValue(forKey: transferId)
                transferIdToConnection.removeValue(forKey: transferId)
            } catch {
                logger.error("Failed to save received file: \(error.localizedDescription)")
                
                // Cancel timeout task
                receiveTimeoutTasks[transferId]?.cancel()
                receiveTimeoutTasks.removeValue(forKey: transferId)
                
                if let continuation = fileReceptionContinuations.removeValue(forKey: transferId) { 
                    continuation.resume(throwing: error) 
                }
                if let senderConnection = transferIdToConnection[transferId] {
                    await networkManager?.send(.fileTransferError(transferId: transferId, error: error.localizedDescription), to: senderConnection)
                } else {
                    await networkManager?.sendToAll(.fileTransferError(transferId: transferId, error: error.localizedDescription))
                }
            }
        case .fileTransferError(let transferId, let errorMessage):
            logger.error("Transfer error id=\(transferId): \(errorMessage)")
            
            // Cancel timeout task
            receiveTimeoutTasks[transferId]?.cancel()
            receiveTimeoutTasks.removeValue(forKey: transferId)
            
            if let continuation = fileReceptionContinuations.removeValue(forKey: transferId) {
                continuation.resume(throwing: NSError(domain: "WiFiAwareManager", code: 4, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
            }
            chunkReceivers.removeValue(forKey: transferId)
            receivedFileMetadata.removeValue(forKey: transferId)
            transferIdToConnection.removeValue(forKey: transferId)
        case .chunkAck(let transferId, let received):
            // Process acknowledgment in sliding window manager
            if let slidingWindowManager = slidingWindowManagers[transferId] {
                await slidingWindowManager.processAcknowledgment(receivedChunks: received)
                logger.debug("Processed ack for transfer \(transferId): chunks \(received)")
            }
        case .fileTransferAccept(let transferId):
            // Check if already resumed
            guard handshakeResumed[transferId] == false else { break }
            
            // Cancel timeout task
            handshakeTimeoutTasks[transferId]?.cancel()
            handshakeTimeoutTasks.removeValue(forKey: transferId)
            
            // Mark as resumed and resume continuation
            handshakeResumed[transferId] = true
            if let cont = handshakeContinuations.removeValue(forKey: transferId) { 
                cont.resume(returning: true)
            }
            handshakeResumed.removeValue(forKey: transferId)
            
        case .fileTransferReject(let transferId, _):
            // Check if already resumed
            guard handshakeResumed[transferId] == false else { break }
            
            // Cancel timeout task
            handshakeTimeoutTasks[transferId]?.cancel()
            handshakeTimeoutTasks.removeValue(forKey: transferId)
            
            // Mark as resumed and resume continuation
            handshakeResumed[transferId] = true
            if let cont = handshakeContinuations.removeValue(forKey: transferId) { 
                cont.resume(returning: false)
            }
            handshakeResumed.removeValue(forKey: transferId)
        }
    }
    
    // MARK: - Trusted Helpers
    private func addTrusted(deviceId: String) async {
        await MainActor.run {
            SettingsService.shared.addTrustedDevice(deviceId)
        }
    }
    
    private func handleLocalEvent(_ event: LocalEvent) async {
        switch event {
        case .listenerRunning:
            logger.info("Wi-Fi Aware listener is running")
        case .browserRunning:
            logger.info("Wi-Fi Aware browser is running")
        case .endpointDiscovered(let endpoint):
            await handleEndpointDiscovered(endpoint)
        case .connecting:
            logger.info("Wi-Fi Aware connecting...")
            // Endpoint discovery handled via endpoint events when available
        case .connection(let connectionEvent):
            await handleConnectionEvent(connectionEvent)
        case .listenerStopped(let error):
            logger.error("Wi-Fi Aware listener stopped: \(error?.localizedDescription ?? "Unknown error")")
        case .browserStopped(let error):
            logger.error("Wi-Fi Aware browser stopped: \(error?.localizedDescription ?? "Unknown error")")
        case .satelliteMovedTo:
            // Handle satellite movement (from sample) - not used in file transfer
            break
        }
    }
    
    // MARK: - Endpoint Discovery Handling
    
    func handleEndpointDiscovered(_ endpoint: WAEndpoint) async {
        logger.info("Discovered Wi-Fi Aware endpoint")
        
        // Get device info
        let deviceName = await endpoint.device.displayName
        let deviceId = String(endpoint.device.id)
        
        // Register endpoint
        endpointRegistry[deviceId] = endpoint
        
        // Create DiscoveredDevice
        let discoveredDevice = DiscoveredDevice(
            id: deviceId,
            name: deviceName,
            type: .unknown, // Could be determined from device info if available
            connectionType: .wifiAware,
            isAvailable: true,
            avatarIndex: nil // Wi-Fi Aware doesn't support discoveryInfo, would need custom protocol
        )
        
        // Notify delegate
        if let delegate = delegate {
            await MainActor.run {
                delegate.didDiscoverDevice(discoveredDevice)
            }
        }
        
        logger.info("Notified delegate of discovered device: \(deviceName)")
    }
    
    func connectToEndpoint(deviceId: String) async throws {
        guard let endpoint = endpointRegistry[deviceId] else {
            throw NSError(domain: "WiFiAwareManager", code: 7, userInfo: [NSLocalizedDescriptionKey: "Endpoint not found for device"])
        }
        
        guard let connectionManager = connectionManager else {
            throw NSError(domain: "WiFiAwareManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Connection manager not initialized"])
        }
        
        await connectionManager.setupConnection(to: endpoint)
    }
    
    private func handleConnectionEvent(_ event: LocalEvent.ConnectionEvent) async {
        switch event {
        case .ready(let device, let detail):
            let deviceName = await device.displayName
            logger.info("Wi-Fi Aware connection ready to: \(deviceName)")
            
            let connectedDevice = ConnectedDevice(
                id: String(device.id),
                name: deviceName,
                type: .unknown, // Could be determined from device info
                connectionType: .wifiAware,
                isAvailable: true,
                connection: detail.connection,
                avatarIndex: nil
            )
            connectionsByDeviceId[connectedDevice.id] = detail.connection
            
            if let delegate = delegate {
                await MainActor.run {
                    delegate.didConnectToDevice(connectedDevice)
                }
            }
            
        case .stopped(let device, let connectionId, let _):
            let deviceName = await device.displayName
            logger.info("Wi-Fi Aware connection stopped: \(deviceName)")
            
            let deviceId = String(device.id)
            let connectedDevice = ConnectedDevice(
                id: deviceId,
                name: deviceName,
                type: .unknown,
                connectionType: .wifiAware,
                isAvailable: false,
                connection: connectionId,
                avatarIndex: nil
            )
            connectionsByDeviceId.removeValue(forKey: deviceId)
            
            // Cancel any pending handshakes for this device
            for (transferId, _) in transferIdToConnection where transferIdToConnection[transferId]?.id == connectionId {
                if handshakeResumed[transferId] == false {
                    handshakeTimeoutTasks[transferId]?.cancel()
                    handshakeTimeoutTasks.removeValue(forKey: transferId)
                    handshakeResumed[transferId] = true
                    if let cont = handshakeContinuations.removeValue(forKey: transferId) {
                        cont.resume(returning: false)
                    }
                    handshakeResumed.removeValue(forKey: transferId)
                }
            }
            
            if let delegate = delegate {
                await MainActor.run {
                    delegate.didDisconnectFromDevice(connectedDevice)
                }
            }
            
        case .performance(let device, let _):
            // Handle performance updates
            let deviceName = await device.displayName
            logger.debug("Wi-Fi Aware performance update: \(deviceName)")
        }
    }
    
    // MARK: - Data Path Optimization
    
    /// Determines whether to use data path based on file size
    /// Files larger than 10MB benefit from data path setup
    private func shouldUseDataPathForFile(size: Int) -> Bool {
        return size > NetworkingConstants.WiFiAware.dataPathThreshold
    }
    
  
    private func setupDataPathForTransfer(connection: WiFiAwareConnection, transferId: String) async throws {
        logger.error("Data path setup requested but not implemented for transfer: \(transferId). Connection ID: \(connection.id)")
        
        // Fail fast with descriptive error
        throw AppError.dataPathNotImplemented(transferId: transferId)
    }
    
}
