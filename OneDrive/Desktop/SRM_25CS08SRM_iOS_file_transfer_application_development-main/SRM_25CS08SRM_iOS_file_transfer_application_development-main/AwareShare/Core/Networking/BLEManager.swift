
import Foundation
import CoreBluetooth
import UIKit
import Combine
import OSLog

// MARK: - BLE Manager

@MainActor
class BLEManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    weak var delegate: NetworkingManagerDelegate?
    weak var consentDelegate: ConsentPrompting?
    
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "BLEManager")
    
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    
    private var discoveredPeripherals: [CBPeripheral] = []
    private var connectedPeripherals: [CBPeripheral] = []
    private var discoveredCentrals: [CBCentral] = []
    
    private var isDiscovering = false
    private var isAdvertising = false
    
    // BLE Service and Characteristics
    private let serviceUUID = CBUUID(string: NetworkingConstants.ServiceUUIDs.bleService)
    private let characteristicUUID = CBUUID(string: NetworkingConstants.ServiceUUIDs.characteristic)
    private let fileTransferCharacteristicUUID = CBUUID(string: NetworkingConstants.ServiceUUIDs.fileTransferCharacteristic)
    private let ackCharacteristicUUID = CBUUID(string: NetworkingConstants.ServiceUUIDs.ackCharacteristic)
    
    // Retained service and characteristics for peripheral manager
    private var mutableService: CBMutableService?
    private var mutableCharacteristic: CBMutableCharacteristic?
    private var fileTransferMutableCharacteristic: CBMutableCharacteristic?
    private var ackMutableCharacteristic: CBMutableCharacteristic?
    
    // File transfer tracking
    private var fileReceptionContinuations: [String: CheckedContinuation<URL, Error>] = [:]
    private var fileReceptionTimeouts: [String: Task<Void, Never>] = [:]
    private var receivedFileData: [String: Data] = [:]
    private var metadataByTransferId: [String: FileMetadata] = [:]
    private var currentTransferIdByPeripheralId: [UUID: String] = [:]
    
    // NEW: Multi-transfer support per peripheral
    private var peripheralTransfers: [UUID: [String: PeripheralTransferState]] = [:]
    
    // Transfer ID to device UUID mapping (for tracking originating peripheral/central)
    private var transferIdToDeviceId: [String: UUID] = [:]
    
    // Write queue and flow control
    private var writeQueues: [UUID: [(data: Data, characteristic: CBCharacteristic)]] = [:]
    private var isWriting: [UUID: Bool] = [:]
    private var chunkAckTracking: [String: Set<Int>] = [:]
    private var chunkTimeouts: [String: [Int: Date]] = [:]
    private let chunkTimeout: TimeInterval = 5.0
    private let maxRetries = 3
    private var chunkRetryCount: [String: [Int: Int]] = [:]
    
    // Chunk tracking for sender
    private var sentChunks: [String: [Int: Data]] = [:]
    private var acknowledgedChunks: [String: Set<Int>] = [:]
    
    // Retry monitor task tracking
    private var retryMonitorTasks: [String: Task<Void, Never>] = [:]
    
    // Chunk tracking for receiver (legacy, kept for compatibility)
    private var receivedChunksByTransfer: [String: [Int: Data]] = [:]
    private var totalChunksByTransfer: [String: Int] = [:]
    
    // Characteristic discovery cache
    private var characteristicCache: [UUID: [CBUUID: CBCharacteristic]] = [:]
    private var characteristicDiscoveryContinuations: [UUID: CheckedContinuation<Void, Error>] = [:]
    
    // MTU negotiation tracking
    private var negotiatedMTUs: [UUID: Int] = [:]
    private var mtuNegotiationContinuations: [UUID: CheckedContinuation<Int, Error>] = [:]
    
    // Write error continuation tracking
    private var writeErrorContinuations: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var writeRetryCount: [UUID: Int] = [:]
    
    // Connection monitoring
    private let connectionMonitor = ConnectionMonitor()
    
    // Dedicated serial queue for BLE operations
    private let bleQueue = DispatchQueue(label: "com.srmist.AwareShare.BLE", qos: .userInitiated)
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: bleQueue)
        peripheralManager = CBPeripheralManager(delegate: self, queue: bleQueue)
    }
    
    // MARK: - Consent Delegate
    
    func setConsentDelegate(_ consentDelegate: ConsentPrompting?) {
        self.consentDelegate = consentDelegate
    }
    
    // MARK: - Discovery Methods
    
    func startDiscovery() async {
        logger.info("Starting BLE discovery")
        
        guard let centralManager = centralManager else { return }
        
        isDiscovering = true
        discoveredPeripherals.removeAll()
        
        // Start scanning for peripherals
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        // Also start advertising as peripheral
        await startAdvertising()
    }
    
    func stopDiscovery() async {
        logger.info("Stopping BLE discovery")
        
        isDiscovering = false
        
        centralManager?.stopScan()
        await stopAdvertising()
    }
    
    private func startAdvertising() async {
        logger.info("Starting BLE advertising")
        
        guard let peripheralManager = peripheralManager else { return }
        
        // Create service and characteristics
        let service = CBMutableService(type: serviceUUID, primary: true)
        
        let characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        let fileTransferCharacteristic = CBMutableCharacteristic(
            type: fileTransferCharacteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        let ackCharacteristic = CBMutableCharacteristic(
            type: ackCharacteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        service.characteristics = [characteristic, fileTransferCharacteristic, ackCharacteristic]
        
        // Retain references for later use
        self.mutableService = service
        self.mutableCharacteristic = characteristic
        self.fileTransferMutableCharacteristic = fileTransferCharacteristic
        self.ackMutableCharacteristic = ackCharacteristic
        
        // Add service
        peripheralManager.add(service)
        
        // Start advertising
        // Create advertisement data with device name and avatar index
        let deviceName = SettingsService.shared.deviceName
        let avatarIndex = SettingsService.shared.selectedAvatarIndex
        // Encode avatar index as Data in service data (CoreBluetooth only supports Apple-defined keys)
        // Convert Int to Data (using variable-length encoding, but for simplicity using UInt8 if fits, else UInt16)
        var avatarIndexData = Data()
        if avatarIndex >= 0 && avatarIndex <= 255 {
            avatarIndexData.append(UInt8(avatarIndex))
        } else {
            // For values > 255, use 2 bytes (little-endian)
            let index16 = UInt16(avatarIndex)
            avatarIndexData.append(UInt8(index16 & 0xFF))
            avatarIndexData.append(UInt8((index16 >> 8) & 0xFF))
        }
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: deviceName,
            CBAdvertisementDataServiceDataKey: [serviceUUID: avatarIndexData]
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
    }
    
    private func stopAdvertising() async {
        logger.info("Stopping BLE advertising")
        
        peripheralManager?.stopAdvertising()
        isAdvertising = false
    }
    
    // MARK: - Connection Methods
    
    func connectToDevice(_ device: DiscoveredDevice) async throws {
        logger.info("Connecting to BLE device: \(device.name)")
        
        // Find the peripheral
        guard let peripheral = discoveredPeripherals.first(where: { $0.identifier.uuidString == device.id }) else {
            throw BLEError.peripheralNotFound
        }
        
        centralManager?.connect(peripheral, options: nil)
    }
    
    func disconnectFromDevice(_ device: ConnectedDevice) async {
        logger.info("Disconnecting from BLE device: \(device.name)")
        
        // Find and disconnect the peripheral
        if let peripheral = connectedPeripherals.first(where: { $0.identifier.uuidString == device.id }) {
            // Cancel retry monitor tasks for any transfers on this peripheral
            if let transferId = currentTransferIdByPeripheralId[peripheral.identifier] {
                retryMonitorTasks[transferId]?.cancel()
                retryMonitorTasks.removeValue(forKey: transferId)
            }
            
            // Clean up all transfer ID to device UUID mappings for this peripheral
            if let transfers = peripheralTransfers[peripheral.identifier] {
                for transferId in transfers.keys {
                    transferIdToDeviceId.removeValue(forKey: transferId)
                }
            }
            
            centralManager?.cancelPeripheralConnection(peripheral)
        }
    }
    
    // MARK: - File Transfer Methods
    
    func sendFile(_ fileURL: URL, to device: ConnectedDevice, transferId: String) async throws {
        logger.info("Sending file via BLE: \(fileURL.lastPathComponent)")
        
        // Find the peripheral
        guard let peripheral = connectedPeripherals.first(where: { $0.identifier.uuidString == device.id }) else {
            throw BLEError.peripheralNotConnected
        }
        
        // Read file data
        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        
        // Use optimized chunk size based on negotiated MTU
        let maxChunkSize = getOptimalChunkSize(for: peripheral)
        logger.info("Using optimized chunk size: \(maxChunkSize) bytes for peripheral: \(peripheral.identifier)")
        
        // Send file metadata first
        let metadata = FileMetadata(
            fileName: fileName,
            fileSize: fileData.count,
            transferId: transferId,
            chunkSize: maxChunkSize
        )
        
        guard let metadataData = try? JSONEncoder().encode(metadata) else {
            throw BLEError.encodingFailed
        }
        
        // Send metadata in chunks
        try await sendDataInChunks(metadataData, to: peripheral, using: characteristicUUID)
        
        // Send file data in chunks with retry support
        try await sendDataInChunks(fileData, to: peripheral, using: fileTransferCharacteristicUUID, transferId: transferId)
        
        logger.info("File sent successfully via BLE")
    }
    
    func receiveFile(from device: ConnectedDevice, transferId: String) async throws -> URL {
        logger.info("Receiving file via BLE from: \(device.name)")
        
        // File reception is handled by the peripheral manager delegate
        // This method sets up the reception and waits for completion
        return try await withCheckedThrowingContinuation { continuation in
            // Store continuation for when file is received
            fileReceptionContinuations[transferId] = continuation
            
            // Set timeout for file reception
            let timeoutTask = Task<Void, Never> {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds timeout
                
                // Check if task was cancelled before resuming
                guard !Task.isCancelled else { return }
                
                if let storedContinuation = fileReceptionContinuations.removeValue(forKey: transferId) {
                    storedContinuation.resume(throwing: BLEError.transferTimeout)
                }
                // Clean up mapping on timeout
                transferIdToDeviceId.removeValue(forKey: transferId)
                // Clean up timeout task reference
                fileReceptionTimeouts.removeValue(forKey: transferId)
            }
            
            // Store timeout task so it can be cancelled on successful completion
            fileReceptionTimeouts[transferId] = timeoutTask
        }
    }
    
    private func sendDataInChunks(_ data: Data, to peripheral: CBPeripheral, using characteristicUUID: CBUUID, transferId: String? = nil) async throws {
        // Use optimized chunk size based on negotiated MTU
        let isFileTransfer = (characteristicUUID == fileTransferCharacteristicUUID)
        let negotiatedMTU = getNegotiatedMTU(for: peripheral)
        let maxPayloadSize = isFileTransfer ? getOptimalChunkSize(for: peripheral) : min(20, negotiatedMTU - 3)
        
        let totalChunks: Int
        var chunksToSend: [(chunkIndex: Int, data: Data)] = []
        
        if isFileTransfer, let transferId = transferId {
            // Calculate chunks with header overhead
            totalChunks = (data.count + maxPayloadSize - 1) / maxPayloadSize
            
            // Create chunks with headers
            for chunkIndex in 0..<totalChunks {
                let startIndex = chunkIndex * maxPayloadSize
                let endIndex = min(startIndex + maxPayloadSize, data.count)
                let payload = data.subdata(in: startIndex..<endIndex)
                
                // Create header
                let header = ChunkHeader(
                    transferId: transferId,
                    chunkIndex: chunkIndex,
                    totalChunks: totalChunks
                )
                
                // Combine header + payload
                guard let chunkData = ChunkHeader.createChunkData(header: header, payload: payload) else {
                    throw BLEError.encodingFailed
                }
                
                chunksToSend.append((chunkIndex, chunkData))
            }
        } else {
            // Legacy chunking without headers (for metadata)
            totalChunks = (data.count + maxPayloadSize - 1) / maxPayloadSize
            for chunkIndex in 0..<totalChunks {
                let startIndex = chunkIndex * maxPayloadSize
                let endIndex = min(startIndex + maxPayloadSize, data.count)
                let chunk = data.subdata(in: startIndex..<endIndex)
                chunksToSend.append((chunkIndex, chunk))
            }
        }
        
        // Check if characteristics are discovered, if not wait
        if characteristicCache[peripheral.identifier]?[characteristicUUID] == nil {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                characteristicDiscoveryContinuations[peripheral.identifier] = continuation
                
                // Set timeout
                Task {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    if let cont = characteristicDiscoveryContinuations.removeValue(forKey: peripheral.identifier) {
                        cont.resume(throwing: BLEError.characteristicNotFound)
                    }
                }
            }
        }
        
        // Get characteristic from cache
        guard let characteristic = characteristicCache[peripheral.identifier]?[characteristicUUID] else {
            throw BLEError.characteristicNotFound
        }
        
        // Initialize write queue for this peripheral
        if writeQueues[peripheral.identifier] == nil {
            writeQueues[peripheral.identifier] = []
            isWriting[peripheral.identifier] = false
        }
        
        // If this is a file transfer, initialize retry tracking
        if let transferId = transferId {
            sentChunks[transferId] = [:]
            acknowledgedChunks[transferId] = Set<Int>()
            chunkTimeouts[transferId] = [:]
            chunkRetryCount[transferId] = [:]
            
            // Store chunks for retry
            for (chunkIndex, chunkData) in chunksToSend {
                sentChunks[transferId]?[chunkIndex] = chunkData
                chunkTimeouts[transferId]?[chunkIndex] = Date()
            }
            
            // Start retry monitor task
            startRetryMonitor(for: transferId, peripheral: peripheral, characteristic: characteristic)
        }
        
        // Enqueue all chunks
        for (_, chunkData) in chunksToSend {
            writeQueues[peripheral.identifier]?.append((data: chunkData, characteristic: characteristic))
        }
        
        // Start processing queue
        await processWriteQueue(for: peripheral)
        
        // Wait for all chunks to be sent
        while !(writeQueues[peripheral.identifier]?.isEmpty ?? true) || (isWriting[peripheral.identifier] ?? false) {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }
    
    private func processWriteQueue(for peripheral: CBPeripheral) async {
        guard let isCurrentlyWriting = isWriting[peripheral.identifier], !isCurrentlyWriting else {
            return
        }
        
        guard let nextWrite = writeQueues[peripheral.identifier]?.first else {
            return
        }
        
        isWriting[peripheral.identifier] = true
        
        // Create continuation for this write operation and await its completion
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                writeErrorContinuations[peripheral.identifier] = continuation
                writeRetryCount[peripheral.identifier] = 0
                
                // Write with response to ensure delivery
                peripheral.writeValue(nextWrite.data, for: nextWrite.characteristic, type: .withResponse)
            }
            
            // Write succeeded, continue processing queue
            // handleWriteComplete will be called from didWriteValueFor after continuation resumes
        } catch {
            // Write failed, stop queue processing
            logger.error("Write failed for peripheral \(peripheral.identifier): \(error)")
            // Clean up state (already done in didWriteValueFor, but ensure it's cleaned here too)
            cleanupWriteState(for: peripheral)
            // Don't call handleWriteComplete - queue halts
        }
    }
    
    private func handleWriteComplete(for peripheral: CBPeripheral) {
        // Remove completed write from queue
        if writeQueues[peripheral.identifier]?.isEmpty == false {
            writeQueues[peripheral.identifier]?.removeFirst()
        }
        
        isWriting[peripheral.identifier] = false
        
        // Process next item in queue
        Task {
            await processWriteQueue(for: peripheral)
        }
    }
    
    private func cleanupWriteState(for peripheral: CBPeripheral) {
        // Clean up write-related state for this peripheral
        isWriting[peripheral.identifier] = false
        writeRetryCount.removeValue(forKey: peripheral.identifier)
        writeErrorContinuations.removeValue(forKey: peripheral.identifier)
        
        // Clear the write queue to stop processing
        writeQueues[peripheral.identifier] = nil
        
        // Also clean up any related transfer tracking state if needed
        // Note: We don't clean up chunk tracking here as that's managed separately
        // and might be needed for retry logic from the retry monitor
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.info("Central manager state updated: \(central.state.rawValue)")
        
        switch central.state {
        case .poweredOn:
            logger.info("BLE central manager is powered on")
        case .poweredOff:
            logger.error("BLE central manager is powered off")
        case .resetting:
            logger.info("BLE central manager is resetting")
        case .unauthorized:
            logger.error("BLE central manager is unauthorized")
        case .unsupported:
            logger.warning("BLE is not supported on this device (likely running in simulator)")
        case .unknown:
            logger.info("BLE central manager state is unknown")
        @unknown default:
            logger.info("BLE central manager state is unknown")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        logger.info("Discovered BLE peripheral: \(peripheral.name ?? "Unknown")")
        
        // Extract avatar index from service data (encoded as Data in CBAdvertisementDataServiceDataKey)
        var avatarIndex: Int? = nil
        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
           let avatarIndexData = serviceData[serviceUUID] {
            if avatarIndexData.count == 1 {
                // Single byte encoding
                avatarIndex = Int(avatarIndexData[0])
            } else if avatarIndexData.count >= 2 {
                // Two byte encoding (little-endian)
                let lowByte = UInt16(avatarIndexData[0])
                let highByte = UInt16(avatarIndexData[1])
                avatarIndex = Int(highByte << 8 | lowByte)
            }
        }
        
        // Avoid duplicates
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
            
            let device = DiscoveredDevice(
                id: peripheral.identifier.uuidString,
                name: peripheral.name ?? "Unknown Device",
                type: .unknown,
                connectionType: .bluetooth,
                isAvailable: true,
                avatarIndex: avatarIndex
            )
            
            // Dispatch delegate callback to main actor for UI updates
            Task { @MainActor in
                delegate?.didDiscoverDevice(device)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Connected to BLE peripheral: \(peripheral.name ?? "Unknown")")
        
        connectedPeripherals.append(peripheral)
        peripheral.delegate = self
        
        // Request MTU negotiation for BLE 5.0 devices
        requestMTUNegotiation(for: peripheral)
        
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("Failed to connect to BLE peripheral: \(error?.localizedDescription ?? "Unknown error")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("Disconnected from BLE peripheral: \(peripheral.name ?? "Unknown")")
        
        // Cancel retry monitor tasks for any transfers on this peripheral
        if let transferId = currentTransferIdByPeripheralId[peripheral.identifier] {
            retryMonitorTasks[transferId]?.cancel()
            retryMonitorTasks.removeValue(forKey: transferId)
        }
        
        // Clean up transfer tracking for this peripheral
        currentTransferIdByPeripheralId.removeValue(forKey: peripheral.identifier)
        
        // Clean up all transfer ID to device UUID mappings for this peripheral
        if let transfers = peripheralTransfers[peripheral.identifier] {
            for transferId in transfers.keys {
                transferIdToDeviceId.removeValue(forKey: transferId)
            }
        }
        
        // Report connection health issue
        Task {
            await connectionMonitor.reportConnectionHealth(
                connectionId: peripheral.identifier.uuidString,
                isHealthy: false
            )
        }
        
        connectedPeripherals.removeAll { $0.identifier == peripheral.identifier }
        
        // Stop monitoring this connection
        Task {
            await connectionMonitor.stopMonitoring(connectionId: peripheral.identifier.uuidString)
        }
        
            let device = ConnectedDevice(
                id: peripheral.identifier.uuidString,
                name: peripheral.name ?? "Unknown Device",
                type: .unknown,
                connectionType: .bluetooth,
                isAvailable: false,
                connection: peripheral,
                avatarIndex: nil
            )
        
        // Dispatch delegate callback to main actor for UI updates
        Task { @MainActor in
            delegate?.didDisconnectFromDevice(device)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            logger.error("Failed to discover services: \(error)")
            return
        }
        
        logger.info("Discovered services for peripheral: \(peripheral.name ?? "Unknown")")
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID, fileTransferCharacteristicUUID, ackCharacteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            logger.error("Failed to discover characteristics: \(error)")
            characteristicDiscoveryContinuations[peripheral.identifier]?.resume(throwing: error)
            characteristicDiscoveryContinuations.removeValue(forKey: peripheral.identifier)
            return
        }
        
        logger.info("Discovered characteristics for service: \(service.uuid)")
        
        guard let characteristics = service.characteristics else { return }
        
        // Cache characteristics
        var cache = characteristicCache[peripheral.identifier] ?? [:]
        for characteristic in characteristics {
            cache[characteristic.uuid] = characteristic
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        characteristicCache[peripheral.identifier] = cache
        
        // Resume any waiting continuations
        characteristicDiscoveryContinuations[peripheral.identifier]?.resume()
        characteristicDiscoveryContinuations.removeValue(forKey: peripheral.identifier)
        
        // Start connection monitoring
        Task {
            await connectionMonitor.startMonitoring(
                connectionId: peripheral.identifier.uuidString,
                connection: peripheral,
                connectionType: .bluetooth
            )
        }
        
        // Notify that device is connected
            let device = ConnectedDevice(
                id: peripheral.identifier.uuidString,
                name: peripheral.name ?? "Unknown Device",
                type: .unknown,
                connectionType: .bluetooth,
                isAvailable: true,
                connection: peripheral,
                avatarIndex: nil
            )
        
        // Dispatch delegate callback to main actor for UI updates
        Task { @MainActor in
            delegate?.didConnectToDevice(device)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Failed to update value for characteristic: \(error)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        // Handle received data
        handleReceivedData(data, from: peripheral, characteristic: characteristic)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let continuation = writeErrorContinuations.removeValue(forKey: peripheral.identifier) else {
            // No continuation waiting, this might be from retry logic or ACK - handle separately
            if let error = error {
                logger.error("Write failed but no continuation found: \(error)")
            } else {
                // This might be an ACK write, handle it normally
                handleWriteComplete(for: peripheral)
            }
            return
        }
        
        if let error = error {
            logger.error("Failed to write value for characteristic: \(error)")
            
            // Check retry count
            let currentRetryCount = writeRetryCount[peripheral.identifier] ?? 0
            if currentRetryCount < self.maxRetries {
                // Retry the write
                writeRetryCount[peripheral.identifier] = currentRetryCount + 1
                logger.info("Retrying write for peripheral \(peripheral.identifier) (attempt \(currentRetryCount + 1)/\(self.maxRetries))")
                
                // Store continuation back for retry
                writeErrorContinuations[peripheral.identifier] = continuation
                
                // Get the current write from queue and retry
                if let nextWrite = writeQueues[peripheral.identifier]?.first {
                    peripheral.writeValue(nextWrite.data, for: nextWrite.characteristic, type: .withResponse)
                } else {
                    // No write to retry, resume with error
                    continuation.resume(throwing: error)
                    cleanupWriteState(for: peripheral)
                }
            } else {
                // Max retries exceeded, propagate error and stop queue
                logger.error("Write failed after \(self.maxRetries) retries for peripheral \(peripheral.identifier)")
                continuation.resume(throwing: error)
                cleanupWriteState(for: peripheral)
                // Don't call handleWriteComplete - queue halts
            }
        } else {
            // Write successful
            writeRetryCount.removeValue(forKey: peripheral.identifier)
            continuation.resume()
            // Continue processing queue after successful write
            handleWriteComplete(for: peripheral)
        }
    }
    
    private func handleReceivedData(_ data: Data, from peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        // Differentiate between metadata, file chunk, and ACK by characteristic UUID
        if characteristic.uuid == characteristicUUID {
            // Metadata path
            do {
                let metadata = try JSONDecoder().decode(FileMetadata.self, from: data)
                
                // Request consent before accepting file
                let device = ConnectedDevice(
                    id: peripheral.identifier.uuidString,
                    name: peripheral.name ?? "BLE Device",
                    type: .unknown,
                    connectionType: .bluetooth,
                    isAvailable: true,
                    connection: peripheral,
                    avatarIndex: nil
                )
                
                // Check if we have a consent delegate
                if let consentDelegate = consentDelegate {
                    Task { @MainActor in
                        consentDelegate.didRequestFileTransfer(
                            fileName: metadata.fileName,
                            fileSize: Int64(metadata.fileSize),
                            from: device
                        ) { [weak self] accepted, trust in
                            guard let self = self else { return }
                            
                            if accepted {
                                // Initialize reception
                                self.receivedFileData[metadata.transferId] = Data()
                                self.metadataByTransferId[metadata.transferId] = metadata
                                self.currentTransferIdByPeripheralId[peripheral.identifier] = metadata.transferId
                                
                                // Track originating peripheral UUID for this transfer
                                self.transferIdToDeviceId[metadata.transferId] = peripheral.identifier
                                
                                // Initialize transfer state for this peripheral
                                if self.peripheralTransfers[peripheral.identifier] == nil {
                                    self.peripheralTransfers[peripheral.identifier] = [:]
                                }
                                var state = PeripheralTransferState()
                                state.metadata = metadata
                                self.peripheralTransfers[peripheral.identifier]?[metadata.transferId] = state
                                
                                self.logger.info("BLE metadata accepted for \(metadata.fileName), size=\(metadata.fileSize) id=\(metadata.transferId)")
                            } else {
                                self.logger.info("BLE file transfer rejected by user for \(metadata.fileName)")
                                // Reject the transfer - complete with error
                                
                                // Cancel timeout task before resuming continuation
                                self.fileReceptionTimeouts.removeValue(forKey: metadata.transferId)?.cancel()
                                
                                // Resume continuation (remove before resuming to avoid double-resume races)
                                if let cont = self.fileReceptionContinuations.removeValue(forKey: metadata.transferId) {
                                    cont.resume(throwing: BLEError.transferTimeout)
                                }
                                // Clean up mapping for rejected transfer
                                self.transferIdToDeviceId.removeValue(forKey: metadata.transferId)
                            }
                        }
                    }
                } else {
                    // No consent delegate - auto-accept (fallback for backward compatibility)
                    receivedFileData[metadata.transferId] = Data()
                    metadataByTransferId[metadata.transferId] = metadata
                    currentTransferIdByPeripheralId[peripheral.identifier] = metadata.transferId
                    
                    // Track originating peripheral UUID for this transfer
                    transferIdToDeviceId[metadata.transferId] = peripheral.identifier
                    
                    // Initialize transfer state for this peripheral
                    if peripheralTransfers[peripheral.identifier] == nil {
                        peripheralTransfers[peripheral.identifier] = [:]
                    }
                    var state = PeripheralTransferState()
                    state.metadata = metadata
                    peripheralTransfers[peripheral.identifier]?[metadata.transferId] = state
                    
                    logger.info("BLE metadata received for \(metadata.fileName), size=\(metadata.fileSize) id=\(metadata.transferId)")
                }
            } catch {
                logger.error("BLE failed to decode metadata: \(error.localizedDescription)")
            }
            return
        }
        if characteristic.uuid == ackCharacteristicUUID {
            // ACK message from receiver (for sender/central)
            do {
                let ackMessage = try JSONDecoder().decode(AckMessage.self, from: data)
                handleAckMessage(ackMessage)
            } catch {
                logger.error("BLE failed to decode ACK message: \(error.localizedDescription)")
            }
            return
        }
        if characteristic.uuid == fileTransferCharacteristicUUID {
            // Try to decode chunk header
            if let (header, payload) = ChunkHeader.decode(from: data) {
                // NEW: Header-based chunk handling (supports multiple simultaneous transfers)
                let transferId = header.transferId
                let chunkIndex = header.chunkIndex
                let totalChunks = header.totalChunks
                
                // Ensure transfer state exists
                if peripheralTransfers[peripheral.identifier] == nil {
                    peripheralTransfers[peripheral.identifier] = [:]
                }
                if peripheralTransfers[peripheral.identifier]?[transferId] == nil {
                    var state = PeripheralTransferState()
                    state.totalChunks = totalChunks
                    peripheralTransfers[peripheral.identifier]?[transferId] = state
                }
                
                // Add chunk to transfer state
                peripheralTransfers[peripheral.identifier]?[transferId]?.addChunk(chunkIndex, data: payload, totalChunks: totalChunks)
                
                // Update progress
                if let state = peripheralTransfers[peripheral.identifier]?[transferId] {
                    let progress = state.progress
                    if let delegate = delegate {
                        Task { @MainActor in
                            delegate.didUpdateTransferProgress(progress, for: transferId)
                        }
                    }
                    
                    // Send ACK every 5 chunks or when complete
                    let receivedCount = state.receivedChunks.count
                    if receivedCount % 5 == 0 || state.isComplete {
                        let receivedIndices = Array(state.receivedChunks.keys).sorted()
                        sendAckMessage(transferId: transferId, receivedChunks: receivedIndices, toPeripheral: peripheral)
                    }
                    
                    // Complete transfer if all chunks received
                    if state.isComplete {
                        completeFileReceptionWithHeader(for: transferId, peripheral: peripheral)
                    }
                }
                
                logger.debug("BLE received chunk \(chunkIndex)/\(totalChunks) for transfer \(transferId)")
                
            } else {
                // LEGACY: Fallback to old behavior without headers
                guard let currentTransferId = currentTransferIdByPeripheralId[peripheral.identifier] else {
                    logger.error("BLE received chunk without prior metadata or header")
                    return
                }
                var buffer = receivedFileData[currentTransferId] ?? Data()
                buffer.append(data)
                receivedFileData[currentTransferId] = buffer
                if let metadata = metadataByTransferId[currentTransferId] {
                    let progress = Double(buffer.count) / Double(metadata.fileSize)
                    if let delegate = delegate {
                        Task { @MainActor in
                            delegate.didUpdateTransferProgress(progress, for: currentTransferId)
                        }
                    }
                    if buffer.count >= metadata.fileSize {
                        completeFileReception(for: currentTransferId)
                    }
                }
            }
        }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLEManager: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        logger.info("Peripheral manager state updated: \(peripheral.state.rawValue)")
        
        switch peripheral.state {
        case .poweredOn:
            logger.info("BLE peripheral manager is powered on")
        case .poweredOff:
            logger.error("BLE peripheral manager is powered off")
        case .resetting:
            logger.info("BLE peripheral manager is resetting")
        case .unauthorized:
            logger.error("BLE peripheral manager is unauthorized")
        case .unsupported:
            logger.warning("BLE is not supported on this device (likely running in simulator)")
        case .unknown:
            logger.info("BLE peripheral manager state is unknown")
        @unknown default:
            logger.info("BLE peripheral manager state is unknown")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            logger.error("Failed to add service: \(error)")
        } else {
            logger.info("Added service: \(service.uuid)")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            logger.error("Failed to start advertising: \(error)")
        } else {
            logger.info("Started advertising")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        logger.info("Received read request for characteristic: \(request.characteristic.uuid)")
        
        // Handle read request
        request.value = "AwareShare".data(using: .utf8)
        peripheral.respond(to: request, withResult: .success)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        logger.info("Received write requests: \(requests.count)")
        
        for request in requests {
            // Handle write request
            if let data = request.value {
                // Treat writes to metadata vs file transfer characteristic accordingly
                if request.characteristic.uuid == characteristicUUID {
                    // Metadata arrived from central
                    do {
                        let metadata = try JSONDecoder().decode(FileMetadata.self, from: data)
                        
                        // Request consent before accepting file
                        let device = ConnectedDevice(
                            id: request.central.identifier.uuidString,
                            name: "BLE Central",
                            type: .unknown,
                            connectionType: .bluetooth,
                            isAvailable: true,
                            connection: request.central,
                            avatarIndex: nil
                        )
                        
                        // Check if we have a consent delegate
                        if let consentDelegate = consentDelegate {
                            Task { @MainActor in
                                consentDelegate.didRequestFileTransfer(
                                    fileName: metadata.fileName,
                                    fileSize: Int64(metadata.fileSize),
                                    from: device
                                ) { [weak self] accepted, trust in
                                    guard let self = self else { return }
                                    
                                    if accepted {
                                        // Initialize reception
                                        self.receivedFileData[metadata.transferId] = Data()
                                        self.metadataByTransferId[metadata.transferId] = metadata
                                        let centralId = request.central.identifier
                                        self.currentTransferIdByPeripheralId[centralId] = metadata.transferId
                                        
                                        // Track originating central UUID for this transfer
                                        self.transferIdToDeviceId[metadata.transferId] = centralId
                                        
                                        self.logger.info("BLE (peripheral) metadata accepted for \(metadata.fileName) id=\(metadata.transferId)")
                                    } else {
                                        self.logger.info("BLE (peripheral) file transfer rejected by user for \(metadata.fileName)")
                                        // Reject the transfer
                                        
                                        // Cancel timeout task before resuming continuation
                                        self.fileReceptionTimeouts.removeValue(forKey: metadata.transferId)?.cancel()
                                        
                                        // Resume continuation (remove before resuming to avoid double-resume races)
                                        if let cont = self.fileReceptionContinuations.removeValue(forKey: metadata.transferId) {
                                            cont.resume(throwing: BLEError.transferTimeout)
                                        }
                                        // Clean up mapping for rejected transfer
                                        self.transferIdToDeviceId.removeValue(forKey: metadata.transferId)
                                    }
                                }
                            }
                        } else {
                            // No consent delegate - auto-accept
                            receivedFileData[metadata.transferId] = Data()
                            metadataByTransferId[metadata.transferId] = metadata
                            let centralId = request.central.identifier
                            currentTransferIdByPeripheralId[centralId] = metadata.transferId
                            
                            // Track originating central UUID for this transfer
                            transferIdToDeviceId[metadata.transferId] = centralId
                            
                            logger.info("BLE (peripheral) metadata received for \(metadata.fileName) id=\(metadata.transferId)")
                        }
                    } catch {
                        logger.error("BLE (peripheral) failed to decode metadata: \(error.localizedDescription)")
                    }
                } else if request.characteristic.uuid == fileTransferCharacteristicUUID {
                    // Try to decode chunk header first (preferred path)
                    if let (header, payload) = ChunkHeader.decode(from: data) {
                        // Header-based chunk handling (supports multiple simultaneous transfers)
                        let transferId = header.transferId
                        let chunkIndex = header.chunkIndex
                        let totalChunks = header.totalChunks
                        
                        // Ensure transfer state exists
                        if peripheralTransfers[request.central.identifier] == nil {
                            peripheralTransfers[request.central.identifier] = [:]
                        }
                        if peripheralTransfers[request.central.identifier]?[transferId] == nil {
                            var state = PeripheralTransferState()
                            state.totalChunks = totalChunks
                            // Set metadata if available
                            if let metadata = metadataByTransferId[transferId] {
                                state.metadata = metadata
                            }
                            peripheralTransfers[request.central.identifier]?[transferId] = state
                        }
                        
                        // Add chunk to transfer state
                        peripheralTransfers[request.central.identifier]?[transferId]?.addChunk(chunkIndex, data: payload, totalChunks: totalChunks)
                        
                        // Update progress
                        if let state = peripheralTransfers[request.central.identifier]?[transferId] {
                            let progress = state.progress
                            if let delegate = delegate {
                                Task { @MainActor in
                                    delegate.didUpdateTransferProgress(progress, for: transferId)
                                }
                            }
                            
                            // Send ACK every 5 chunks or when complete
                            let receivedCount = state.receivedChunks.count
                            if receivedCount % 5 == 0 || state.isComplete {
                                let receivedIndices = Array(state.receivedChunks.keys).sorted()
                                sendAckMessage(transferId: transferId, receivedChunks: receivedIndices, to: request.central)
                            }
                            
                            // Complete transfer if all chunks received
                            if state.isComplete {
                                completeFileReceptionWithHeader(for: transferId, peripheral: nil, central: request.central)
                            }
                        }
                        
                        logger.debug("BLE (peripheral) received chunk \(chunkIndex)/\(totalChunks) for transfer \(transferId)")
                        
                    } else {
                        // LEGACY: Fallback to old behavior without headers
                        let keyId: String? = {
                            let centralId = request.central.identifier
                            if let transferId = currentTransferIdByPeripheralId[centralId] { return transferId }
                            return receivedFileData.keys.first
                        }()
                        
                        guard let transferId = keyId, let metadata = metadataByTransferId[transferId] else {
                            logger.error("BLE (peripheral) received file chunk without metadata or header")
                            peripheral.respond(to: request, withResult: .success)
                            continue
                        }
                        
                        // Use chunkSize from metadata, fallback to 20 for backward compatibility
                        let chunkSize = metadata.chunkSize ?? 20
                        var buffer = receivedFileData[transferId] ?? Data()
                        let chunkIndex = buffer.count / chunkSize
                        buffer.append(data)
                        receivedFileData[transferId] = buffer
                        
                        // Track received chunks
                        var chunks = receivedChunksByTransfer[transferId] ?? [:]
                        chunks[chunkIndex] = data
                        receivedChunksByTransfer[transferId] = chunks
                        
                        // Calculate total chunks using dynamic chunk size
                        let totalChunks = (metadata.fileSize + chunkSize - 1) / chunkSize
                        totalChunksByTransfer[transferId] = totalChunks
                        
                        let progress = Double(buffer.count) / Double(metadata.fileSize)
                        if let delegate = delegate {
                            Task { @MainActor in
                                delegate.didUpdateTransferProgress(progress, for: transferId)
                            }
                        }
                        
                        // Send ACK periodically (every 5 chunks) or when complete
                        if chunks.count % 5 == 0 || buffer.count >= metadata.fileSize {
                            let central = request.central
                            let receivedIndices = Array(chunks.keys).sorted()
                            sendAckMessage(transferId: transferId, receivedChunks: receivedIndices, to: central)
                        }
                        
                        if buffer.count >= metadata.fileSize {
                            completeFileReception(for: transferId)
                            // Clean up chunk tracking
                            receivedChunksByTransfer.removeValue(forKey: transferId)
                            totalChunksByTransfer.removeValue(forKey: transferId)
                        }
                    }
                }
            }
            
            peripheral.respond(to: request, withResult: .success)
        }
    }
}

// MARK: - Supporting Types

enum BLEError: Error, LocalizedError {
    case peripheralNotFound
    case peripheralNotConnected
    case characteristicNotFound
    case encodingFailed
    case decodingFailed
    case transferTimeout
    
    var errorDescription: String? {
        switch self {
        case .peripheralNotFound:
            return "Peripheral not found"
        case .peripheralNotConnected:
            return "Peripheral not connected"
        case .characteristicNotFound:
            return "Characteristic not found"
        case .encodingFailed:
            return "Failed to encode data"
        case .decodingFailed:
            return "Failed to decode data"
        case .transferTimeout:
            return "File transfer timed out"
        }
    }
}

struct FileMetadata: Codable {
    let fileName: String
    let fileSize: Int
    let transferId: String
    let chunkSize: Int? // Optional for backward compatibility; used by receiver for legacy path
    
    init(fileName: String, fileSize: Int, transferId: String, chunkSize: Int? = nil) {
        self.fileName = fileName
        self.fileSize = fileSize
        self.transferId = transferId
        self.chunkSize = chunkSize
    }
}

struct AckMessage: Codable {
    let transferId: String
    let received: [Int]
}

// MARK: - Chunk Header

/// Header prepended to each file transfer chunk for better tracking
struct ChunkHeader: Codable {
    let transferId: String
    let chunkIndex: Int
    let totalChunks: Int
    
    /// Encode header to Data (compact format)
    func encode() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    /// Decode header from Data
    static func decode(from data: Data) -> (header: ChunkHeader, remainingData: Data)? {
        // Try to find the header delimiter (we'll use first 2 bytes for length)
        guard data.count >= 2 else { return nil }
        
        let headerLength = Int(data[0]) << 8 | Int(data[1])
        guard data.count >= 2 + headerLength else { return nil }
        
        let headerData = data.subdata(in: 2..<(2 + headerLength))
        let remainingData = data.subdata(in: (2 + headerLength)..<data.count)
        
        guard let header = try? JSONDecoder().decode(ChunkHeader.self, from: headerData) else {
            return nil
        }
        
        return (header, remainingData)
    }
    
    /// Create data with header prepended
    static func createChunkData(header: ChunkHeader, payload: Data) -> Data? {
        guard let headerData = header.encode() else { return nil }
        
        // Prepend 2-byte length field
        let headerLength = headerData.count
        guard headerLength < 65536 else { return nil } // Max 2-byte length
        
        var result = Data()
        result.append(UInt8((headerLength >> 8) & 0xFF))
        result.append(UInt8(headerLength & 0xFF))
        result.append(headerData)
        result.append(payload)
        
        return result
    }
}

// MARK: - Per-Peripheral Transfer State

/// Tracks state for a single transfer on a specific peripheral
struct PeripheralTransferState {
    var receivedChunks: [Int: Data] = [:]
    var totalChunks: Int = 0
    var metadata: FileMetadata?
    var lastUpdateTime: Date = Date()
    
    var isComplete: Bool {
        guard totalChunks > 0 else { return false }
        return receivedChunks.count == totalChunks
    }
    
    var progress: Double {
        guard totalChunks > 0 else { return 0.0 }
        return Double(receivedChunks.count) / Double(totalChunks)
    }
    
    mutating func addChunk(_ chunkIndex: Int, data: Data, totalChunks: Int) {
        receivedChunks[chunkIndex] = data
        self.totalChunks = totalChunks
        lastUpdateTime = Date()
    }
    
    func getCompleteData() -> Data? {
        guard isComplete else { return nil }
        
        var completeData = Data()
        for chunkIndex in 0..<totalChunks {
            guard let chunkData = receivedChunks[chunkIndex] else {
                return nil
            }
            completeData.append(chunkData)
        }
        return completeData
    }
}

// MARK: - ACK Protocol

extension BLEManager {
    /// Handle ACK message received from receiver (sender side)
    private func handleAckMessage(_ ackMessage: AckMessage) {
        logger.info("Received ACK for transfer \(ackMessage.transferId): \(ackMessage.received.count) chunks")
        
        // Update acknowledged chunks
        var acked = acknowledgedChunks[ackMessage.transferId] ?? Set<Int>()
        for chunkIndex in ackMessage.received {
            acked.insert(chunkIndex)
        }
        acknowledgedChunks[ackMessage.transferId] = acked
        
        // Remove acknowledged chunks from sent chunks (no need to retry)
        if var sent = sentChunks[ackMessage.transferId] {
            for chunkIndex in ackMessage.received {
                sent.removeValue(forKey: chunkIndex)
            }
            sentChunks[ackMessage.transferId] = sent
        }
        
        // Clear timeouts for acknowledged chunks
        if var timeouts = chunkTimeouts[ackMessage.transferId] {
            for chunkIndex in ackMessage.received {
                timeouts.removeValue(forKey: chunkIndex)
            }
            chunkTimeouts[ackMessage.transferId] = timeouts
        }
    }
    
    /// Start retry monitor for a transfer
    private func startRetryMonitor(for transferId: String, peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        // Cancel any existing retry monitor task for this transfer
        retryMonitorTasks[transferId]?.cancel()
        
        // Create and store the new retry monitor task
        let task = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                // Check if transfer is complete or cancelled
                guard let timeouts = self.chunkTimeouts[transferId], !timeouts.isEmpty else {
                    break
                }
                
                // Cooperative cancellation check
                if Task.isCancelled {
                    break
                }
                
                let now = Date()
                var chunksToRetry: [Int] = []
                
                // Find chunks that have timed out
                for (chunkIndex, sentTime) in timeouts {
                    // Cooperative cancellation check
                    if Task.isCancelled {
                        break
                    }
                    
                    // Skip if already acknowledged
                    if self.acknowledgedChunks[transferId]?.contains(chunkIndex) == true {
                        continue
                    }
                    
                    // Check if timeout exceeded
                    if now.timeIntervalSince(sentTime) > self.chunkTimeout {
                        chunksToRetry.append(chunkIndex)
                    }
                }
                
                // Retry timed-out chunks
                for chunkIndex in chunksToRetry {
                    // Cooperative cancellation check
                    if Task.isCancelled {
                        break
                    }
                    
                    let retryCount = self.chunkRetryCount[transferId]?[chunkIndex] ?? 0
                    
                    if retryCount >= self.maxRetries {
                        self.logger.error("Max retries exceeded for chunk \(chunkIndex) in transfer \(transferId)")
                        // Clean up and fail transfer
                        self.chunkTimeouts.removeValue(forKey: transferId)
                        self.sentChunks.removeValue(forKey: transferId)
                        self.acknowledgedChunks.removeValue(forKey: transferId)
                        self.chunkRetryCount.removeValue(forKey: transferId)
                        self.retryMonitorTasks.removeValue(forKey: transferId)
                        return
                    }
                    
                    // Resend chunk
                    if let chunkData = self.sentChunks[transferId]?[chunkIndex] {
                        self.logger.info("Retrying chunk \(chunkIndex) for transfer \(transferId) (attempt \(retryCount + 1))")
                        peripheral.writeValue(chunkData, for: characteristic, type: .withResponse)
                        
                        // Update retry count and timeout
                        var retries = self.chunkRetryCount[transferId] ?? [:]
                        retries[chunkIndex] = retryCount + 1
                        self.chunkRetryCount[transferId] = retries
                        
                        var timeouts = self.chunkTimeouts[transferId] ?? [:]
                        timeouts[chunkIndex] = Date()
                        self.chunkTimeouts[transferId] = timeouts
                    }
                }
                
                // Wait before next check (with cancellation support)
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // Check every 1 second
                } catch {
                    // Task was cancelled during sleep
                    break
                }
            }
            
            // Clean up when complete
            self.chunkTimeouts.removeValue(forKey: transferId)
            self.sentChunks.removeValue(forKey: transferId)
            self.acknowledgedChunks.removeValue(forKey: transferId)
            self.chunkRetryCount.removeValue(forKey: transferId)
            self.retryMonitorTasks.removeValue(forKey: transferId)
        }
        
        retryMonitorTasks[transferId] = task
    }
    
    /// Send ACK message to sender (receiver side) - for peripheral manager
    private func sendAckMessage(transferId: String, receivedChunks: [Int], to central: CBCentral) {
        let ackMessage = AckMessage(transferId: transferId, received: receivedChunks)
        
        guard let ackData = try? JSONEncoder().encode(ackMessage) else {
            logger.error("Failed to encode ACK message")
            return
        }
        
        // Use retained ACK characteristic
        guard let peripheralManager = peripheralManager,
              let ackCharacteristic = ackMutableCharacteristic else {
            logger.error("ACK characteristic not found or not initialized")
            return
        }
        
        // Update the characteristic value and notify the central
        peripheralManager.updateValue(ackData, for: ackCharacteristic, onSubscribedCentrals: [central])
        logger.debug("Sent ACK for transfer \(transferId): \(receivedChunks.count) chunks")
    }
    
    /// Send ACK message to sender (receiver side) - for central manager
    private func sendAckMessage(transferId: String, receivedChunks: [Int], toPeripheral peripheral: CBPeripheral) {
        let ackMessage = AckMessage(transferId: transferId, received: receivedChunks)
        
        guard let ackData = try? JSONEncoder().encode(ackMessage) else {
            logger.error("Failed to encode ACK message")
            return
        }
        
        // Write to ACK characteristic on peripheral
        guard let ackCharacteristic = characteristicCache[peripheral.identifier]?[ackCharacteristicUUID] else {
            logger.error("ACK characteristic not found for peripheral")
            return
        }
        
        peripheral.writeValue(ackData, for: ackCharacteristic, type: .withResponse)
        logger.debug("Sent ACK to peripheral for transfer \(transferId): \(receivedChunks.count) chunks")
    }
}

// MARK: - File reception completion

extension BLEManager {
    /// Complete file reception using header-based multi-transfer tracking
    private func completeFileReceptionWithHeader(for transferId: String, peripheral: CBPeripheral? = nil, central: CBCentral? = nil) {
        // Determine the identifier based on which parameter is provided
        let identifier: UUID
        if let peripheral = peripheral {
            identifier = peripheral.identifier
        } else if let central = central {
            identifier = central.identifier
        } else {
            logger.error("Cannot complete transfer \(transferId): neither peripheral nor central provided")
            return
        }
        
        guard let state = peripheralTransfers[identifier]?[transferId],
              state.isComplete,
              let completeData = state.getCompleteData(),
              let metadata = state.metadata else {
            logger.error("Cannot complete transfer \(transferId): incomplete or missing data")
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent(metadata.fileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try completeData.write(to: destinationURL)
            logger.info("File saved to: \(destinationURL.path) (\(completeData.count) bytes)")
            
            // Cancel timeout task before resuming continuation
            fileReceptionTimeouts.removeValue(forKey: transferId)?.cancel()
            
            // Resume continuation (remove before resuming to avoid double-resume races)
            if let cont = fileReceptionContinuations.removeValue(forKey: transferId) {
                cont.resume(returning: destinationURL)
            }
            
            // Notify delegate
            if let delegate = delegate {
                let connectedDevice = ConnectedDevice(
                    id: identifier.uuidString,
                    name: peripheral?.name ?? "BLE Device",
                    type: .unknown,
                    connectionType: .bluetooth,
                    isAvailable: true,
                    connection: peripheral ?? (central as Any),
                    avatarIndex: nil
                )
                
                Task { @MainActor in
                    delegate.didReceiveFile(destinationURL, from: connectedDevice)
                }
            }
            
            // Clean up
            peripheralTransfers[identifier]?.removeValue(forKey: transferId)
            metadataByTransferId.removeValue(forKey: transferId)
            transferIdToDeviceId.removeValue(forKey: transferId)
            
        } catch {
            logger.error("Failed to save received file: \(error.localizedDescription)")
            
            // Cancel timeout task before resuming continuation
            fileReceptionTimeouts.removeValue(forKey: transferId)?.cancel()
            
            // Resume continuation (remove before resuming to avoid double-resume races)
            if let cont = fileReceptionContinuations.removeValue(forKey: transferId) {
                cont.resume(throwing: error)
            }
            // Clean up mapping on error
            transferIdToDeviceId.removeValue(forKey: transferId)
        }
    }
    
    /// Legacy completion method for backward compatibility
    private func completeFileReception(for transferId: String) {
        guard let buffer = receivedFileData[transferId], let metadata = metadataByTransferId[transferId] else { return }
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent(metadata.fileName)
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try buffer.write(to: destinationURL)
            logger.info("File saved to: \(destinationURL.path)")
            
            // Cancel timeout task before resuming continuation
            fileReceptionTimeouts.removeValue(forKey: transferId)?.cancel()
            
            // Resume continuation (remove before resuming to avoid double-resume races)
            if let cont = fileReceptionContinuations.removeValue(forKey: transferId) {
                cont.resume(returning: destinationURL)
            }
            
            // Find the connected device for this transfer using the mapping
            if let delegate = delegate {
                // Look up the device UUID from the transfer mapping
                var deviceId = transferId // Fallback to transferId
                var deviceName = "BLE Device"
                var connection: Any = transferId // Fallback to transferId
                
                if let deviceUUID = transferIdToDeviceId[transferId] {
                    // Try to find the peripheral in connected peripherals first
                    if let peripheral = connectedPeripherals.first(where: { $0.identifier == deviceUUID }) {
                        deviceId = peripheral.identifier.uuidString
                        deviceName = peripheral.name ?? "BLE Device"
                        connection = peripheral
                    }
                    // Try discovered peripherals if not found in connected
                    else if let peripheral = discoveredPeripherals.first(where: { $0.identifier == deviceUUID }) {
                        deviceId = peripheral.identifier.uuidString
                        deviceName = peripheral.name ?? "BLE Device"
                        connection = peripheral
                    }
                    // Try discovered centrals if it's a central
                    else if let central = discoveredCentrals.first(where: { $0.identifier == deviceUUID }) {
                        deviceId = central.identifier.uuidString
                        deviceName = "BLE Central"
                        connection = central
                    } else {
                        // UUID found but device object not found - use UUID as identifier
                        deviceId = deviceUUID.uuidString
                        logger.warning("Device UUID \(deviceUUID.uuidString) found for transfer \(transferId) but device object not found")
                    }
                } else {
                    logger.warning("No device UUID mapping found for transfer \(transferId), using transferId as fallback")
                }
                
                // Create a connected device with the real identifier
                let connectedDevice = ConnectedDevice(
                    id: deviceId,
                    name: deviceName,
                    type: .unknown,
                    connectionType: .bluetooth,
                    isAvailable: true,
                    connection: connection,
                    avatarIndex: nil
                )
                
                Task { @MainActor in
                    delegate.didReceiveFile(destinationURL, from: connectedDevice)
                }
            }
            
            // Clean up
            receivedFileData.removeValue(forKey: transferId)
            metadataByTransferId.removeValue(forKey: transferId)
            transferIdToDeviceId.removeValue(forKey: transferId)
        } catch {
            logger.error("Failed to save received file: \(error.localizedDescription)")
            
            // Cancel timeout task before resuming continuation
            fileReceptionTimeouts.removeValue(forKey: transferId)?.cancel()
            
            // Resume continuation (remove before resuming to avoid double-resume races)
            if let cont = fileReceptionContinuations.removeValue(forKey: transferId) {
                cont.resume(throwing: error)
            }
            // Clean up mapping on error
            transferIdToDeviceId.removeValue(forKey: transferId)
        }
    }
    
    // MARK: - MTU Negotiation
    
    /// Requests MTU negotiation for BLE 5.0 devices
    private func requestMTUNegotiation(for peripheral: CBPeripheral) {
        logger.info("Requesting MTU negotiation for peripheral: \(peripheral.identifier)")
        
        // Request maximum MTU size for BLE 5.0 devices
        peripheral.readRSSI()
        
        // For iOS, we can request MTU negotiation through the peripheral
        if #available(iOS 11.0, *) {
            // Note: iOS doesn't expose direct MTU negotiation APIs
            // The system handles this automatically, but we can track the effective MTU
            logger.info("MTU negotiation will be handled by the system for BLE 5.0 devices")
            
            // Set a reasonable default based on device capabilities
            let estimatedMTU = estimateOptimalMTU(for: peripheral)
            negotiatedMTUs[peripheral.identifier] = estimatedMTU
            logger.info("Estimated optimal MTU for \(peripheral.identifier): \(estimatedMTU)")
        } else {
            // Fallback to default MTU for older iOS versions
            negotiatedMTUs[peripheral.identifier] = NetworkingConstants.BLE.defaultMTUSize
            logger.info("Using default MTU for older iOS: \(NetworkingConstants.BLE.defaultMTUSize)")
        }
    }
    
    /// Estimates optimal MTU based on device capabilities
    private func estimateOptimalMTU(for peripheral: CBPeripheral) -> Int {
        // BLE 5.0 devices can support up to 512 bytes MTU
        // We'll use a conservative estimate that works well for file transfers
        return NetworkingConstants.BLE.conservativeMTUSize
    }
    
    /// Gets the negotiated MTU for a peripheral
    func getNegotiatedMTU(for peripheral: CBPeripheral) -> Int {
        return negotiatedMTUs[peripheral.identifier] ?? NetworkingConstants.BLE.defaultMTUSize
    }
    
    /// Calculates optimal chunk size based on negotiated MTU
    func getOptimalChunkSize(for peripheral: CBPeripheral) -> Int {
        let mtu = getNegotiatedMTU(for: peripheral)
        // Reserve 3 bytes for ATT header, use 80% of available space for data
        return max(NetworkingConstants.BLE.maxChunkSize, Int(Double(mtu - 3) * NetworkingConstants.Performance.chunkSizeMultiplier))
    }
    
    /// Updates MTU when system reports changes
    func updateMTU(for peripheral: CBPeripheral, newMTU: Int) {
        logger.info("MTU updated for \(peripheral.identifier): \(newMTU)")
        negotiatedMTUs[peripheral.identifier] = newMTU
        
        // Resume any waiting MTU negotiation continuations
        if let continuation = mtuNegotiationContinuations.removeValue(forKey: peripheral.identifier) {
            continuation.resume(returning: newMTU)
        }
    }
    
    /// Report connection health for monitoring
    func reportConnectionHealth(for peripheral: CBPeripheral, isHealthy: Bool) {
        Task {
            await connectionMonitor.reportConnectionHealth(
                connectionId: peripheral.identifier.uuidString,
                isHealthy: isHealthy
            )
        }
    }
    
    /// Get connection health status
    func getConnectionHealth(for peripheral: CBPeripheral) async -> ConnectionHealth? {
        return await connectionMonitor.getConnectionHealth(connectionId: peripheral.identifier.uuidString)
    }
}
