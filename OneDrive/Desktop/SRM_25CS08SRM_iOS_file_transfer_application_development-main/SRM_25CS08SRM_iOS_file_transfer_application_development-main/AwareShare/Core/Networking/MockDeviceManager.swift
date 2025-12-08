import Foundation
import OSLog

@MainActor
final class MockDeviceManager {
    static let shared = MockDeviceManager()
    private init() {}
    
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "MockDeviceManager")
    private weak var delegate: NetworkingManagerDelegate?
    private weak var networkingManager: NetworkingManager?
    private var discoveryTimer: Timer?
    private var mockDevices: [DiscoveredDevice] = []
    private var mockConnectedDevices: [String: ConnectedDevice] = [:]
    private var isRunning = false
    private var activeTransfers: [String: Task<Bool, Never>] = [:]
    
    func attach(delegate networkingManager: NetworkingManager) {
        self.networkingManager = networkingManager
        self.delegate = networkingManager
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        logger.info("MockDeviceManager started")
        scheduleDiscovery()
    }
    
    func stop() {
        isRunning = false
        discoveryTimer?.invalidate()
        discoveryTimer = nil
        mockDevices.removeAll()
        mockConnectedDevices.removeAll()
        // Cancel all active transfers
        for (_, task) in activeTransfers {
            task.cancel()
        }
        activeTransfers.removeAll()
        logger.info("MockDeviceManager stopped")
    }
    
    private func scheduleDiscovery() {
        discoveryTimer?.invalidate()
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.emitMockDevice()
            }
        }
    }
    
    private func emitMockDevice() async {
        guard isRunning else { return }
        let id = UUID().uuidString
        let names = ["Alice's iPhone", "Bob's iPad", "Carol's Mac", "Test Device"]
        let name = names.randomElement() ?? "Mock Device"
        let types: [DeviceType] = [.iPhone, .iPad, .mac, .unknown]
        let type = types.randomElement() ?? .unknown
        let transports: [ConnectionType] = [.wifiAware, .bluetooth, .multipeer]
        let transport = transports.randomElement() ?? .wifiAware
        
        let device = DiscoveredDevice(id: id, name: name, type: type, connectionType: transport, isAvailable: true, avatarIndex: nil)
        mockDevices.append(device)
        
        logger.info("Discovered mock device: \(name)")
        networkingManager?.didDiscoverDevice(device)
    }
    
    // MARK: - Mock Connection & Transfer
    
    func connectToMockDevice(_ device: DiscoveredDevice) async {
        logger.info("Connecting to mock device: \(device.name)")
        
        // Simulate connection delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let connectedDevice = ConnectedDevice(
            id: device.id,
            name: device.name,
            type: device.type,
            connectionType: device.connectionType,
            isAvailable: true,
            connection: "mock-connection-\(device.id)",
            avatarIndex: device.avatarIndex
        )
        
        mockConnectedDevices[device.id] = connectedDevice
        delegate?.didConnectToDevice(connectedDevice)
        logger.info("Connected to mock device: \(device.name)")
    }
    
    func simulateSendFile(_ fileURL: URL, to device: ConnectedDevice, transferId: String) async {
        logger.info("Simulating file send: \(fileURL.lastPathComponent)")
        
        guard let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 else {
            logger.error("Failed to get file size")
            // Notify failure - transfer was never added to activeTransfers, so no need to remove it
            await networkingManager?.completeTransfer(transferId, success: false)
            return
        }
        
        let task = Task { @MainActor () -> Bool in
            // Simulate transfer with progress updates
            let totalSteps = 20
            var wasCancelled = false
            
            for step in 0...totalSteps {
                guard !Task.isCancelled else {
                    logger.info("Transfer cancelled: \(transferId)")
                    wasCancelled = true
                    break
                }
                
                let progress = Double(step) / Double(totalSteps)
                delegate?.didUpdateTransferProgress(progress, for: transferId)
                
                // Simulate transfer speed (adjust based on file size)
                let delayPerStep = min(100_000_000, UInt64(Double(fileSize) / Double(totalSteps) / 10000)) // nanoseconds
                try? await Task.sleep(nanoseconds: delayPerStep)
            }
            
            // Notify delegate of completion or cancellation on MainActor before removing transfer
            await networkingManager?.completeTransfer(transferId, success: !wasCancelled)
            activeTransfers.removeValue(forKey: transferId)
            
            if wasCancelled {
                logger.info("Transfer cancelled: \(transferId)")
                return false
            } else {
                logger.info("Mock file send complete: \(fileURL.lastPathComponent)")
                return true
            }
        }
        
        activeTransfers[transferId] = task
        _ = await task.value
    }
    
    func simulateReceiveFile(from device: ConnectedDevice, transferId: String, fileName: String, fileSize: Int64) async -> URL? {
        logger.info("Simulating file receive: \(fileName)")
        
        var writeSucceeded = false
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent(fileName)
        
        let task = Task { @MainActor () -> Bool in
            // Simulate transfer with progress updates
            let totalSteps = 20
            var wasCancelled = false
            
            for step in 0...totalSteps {
                guard !Task.isCancelled else {
                    logger.info("Transfer cancelled: \(transferId)")
                    wasCancelled = true
                    break
                }
                
                let progress = Double(step) / Double(totalSteps)
                delegate?.didUpdateTransferProgress(progress, for: transferId)
                
                // Simulate transfer speed
                let delayPerStep = min(100_000_000, UInt64(Double(fileSize) / Double(totalSteps) / 10000))
                try? await Task.sleep(nanoseconds: delayPerStep)
            }
            
            // Handle cancellation
            guard !wasCancelled else {
                // Notify delegate of cancellation on MainActor before removing transfer
                await networkingManager?.completeTransfer(transferId, success: false)
                activeTransfers.removeValue(forKey: transferId)
                return false
            }
            
            // Create a mock file in documents directory
            // Create mock file content
            let mockContent = "Mock file content from \(device.name)\nTransfer ID: \(transferId)\nFile size: \(fileSize) bytes"
            do {
                try mockContent.write(to: destinationURL, atomically: true, encoding: .utf8)
            } catch {
                logger.error("Failed to write mock file: \(error.localizedDescription)")
                // Notify delegate of failure on MainActor before removing transfer
                await networkingManager?.completeTransfer(transferId, success: false)
                activeTransfers.removeValue(forKey: transferId)
                return false
            }
            
            logger.info("Mock file receive complete: \(fileName)")
            delegate?.didReceiveFile(destinationURL, from: device)
            
            // Notify delegate of success on MainActor before removing transfer
            await networkingManager?.completeTransfer(transferId, success: true)
            activeTransfers.removeValue(forKey: transferId)
            
            return true
        }
        
        activeTransfers[transferId] = task
        writeSucceeded = await task.value
        
        // Return the destination URL after task completion
        return writeSucceeded ? destinationURL : nil
    }
}
