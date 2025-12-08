
import Foundation


actor MockWiFiAwareManager: WiFiAwareManagerProtocol {
    
    // MARK: - Properties
    
    weak var delegate: NetworkingManagerDelegate?
    
    // MARK: - Mock State
    
    private(set) var isDiscovering = false
    private(set) var isPublishing = false
    private(set) var connectedDevices: [String: ConnectedDevice] = [:]
    private(set) var startDiscoveryCallCount = 0
    private(set) var stopDiscoveryCallCount = 0
    private(set) var sendFileCallCount = 0
    private(set) var receiveFileCallCount = 0
    
    // MARK: - Mock Configuration
    
    var shouldThrowOnConnect = false
    var shouldThrowOnSendFile = false
    var shouldThrowOnReceiveFile = false
    var mockReceivedFileURL: URL?
    var sendFileDelay: UInt64 = 0 // nanoseconds
    var receiveFileDelay: UInt64 = 0 // nanoseconds
    
    // MARK: - Delegate Management
    
    func setDelegate(_ delegate: NetworkingManagerDelegate?) {
        self.delegate = delegate
    }
    
    // MARK: - Discovery Methods
    
    func startDiscovery() async {
        isDiscovering = true
        startDiscoveryCallCount += 1
        
        // Optionally simulate device discovery
        // await simulateDeviceDiscovery()
    }
    
    func stopDiscovery() async {
        isDiscovering = false
        isPublishing = false
        stopDiscoveryCallCount += 1
        connectedDevices.removeAll()
    }
    
    func startPublishing() async throws {
        isPublishing = true
    }
    
    // MARK: - Connection Methods
    
    func connectToDevice(_ device: DiscoveredDevice) async throws {
        if shouldThrowOnConnect {
            throw NSError(
                domain: "MockWiFiAwareManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Mock connection failure"]
            )
        }
        
        // Create a mock connected device
        let connectedDevice = ConnectedDevice(
            id: device.id,
            name: device.name,
            type: device.type,
            connectionType: .wifiAware,
            isAvailable: true,
            connection: "mock-connection-\(device.id)",
            avatarIndex: device.avatarIndex
        )
        
        connectedDevices[device.id] = connectedDevice
        
        // Notify delegate
        await delegate?.didConnectToDevice(connectedDevice)
    }
    
    func disconnectFromDevice(_ device: ConnectedDevice) async {
        connectedDevices.removeValue(forKey: device.id)
        await delegate?.didDisconnectFromDevice(device)
    }
    
    // MARK: - File Transfer Methods
    
    func sendFile(_ fileURL: URL, to device: ConnectedDevice, transferId: String) async throws {
        sendFileCallCount += 1
        
        if shouldThrowOnSendFile {
            throw NSError(
                domain: "MockWiFiAwareManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Mock send file failure"]
            )
        }
        
        // Simulate transfer delay
        if sendFileDelay > 0 {
            try await Task.sleep(nanoseconds: sendFileDelay)
        }
        
        // Simulate progress updates
        await simulateTransferProgress(transferId: transferId)
    }
    
    func receiveFile(from device: ConnectedDevice, transferId: String) async throws -> URL {
        receiveFileCallCount += 1
        
        if shouldThrowOnReceiveFile {
            throw NSError(
                domain: "MockWiFiAwareManager",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Mock receive file failure"]
            )
        }
        
        // Simulate transfer delay
        if receiveFileDelay > 0 {
            try await Task.sleep(nanoseconds: receiveFileDelay)
        }
        
        // Simulate progress updates
        await simulateTransferProgress(transferId: transferId)
        
        // Return mock file URL
        if let mockURL = mockReceivedFileURL {
            return mockURL
        }
        
        // Create a temporary mock file
        let tempDir = FileManager.default.temporaryDirectory
        let mockFileURL = tempDir.appendingPathComponent("mock-received-file.txt")
        try "Mock file content".write(to: mockFileURL, atomically: true, encoding: .utf8)
        return mockFileURL
    }
    
    // MARK: - Mock Helpers
    
    /// Simulate device discovery by notifying delegate of a mock device
    func simulateDeviceDiscovery(deviceName: String = "Mock Device") async {
        let mockDevice = DiscoveredDevice(
            id: UUID().uuidString,
            name: deviceName,
            type: .iPhone,
            connectionType: .wifiAware,
            isAvailable: true,
            avatarIndex: nil
        )
        
        await delegate?.didDiscoverDevice(mockDevice)
    }
    
    /// Simulate transfer progress updates
    private func simulateTransferProgress(transferId: String) async {
        let progressSteps: [Double] = [0.25, 0.5, 0.75, 1.0]
        
        for progress in progressSteps {
            await delegate?.didUpdateTransferProgress(progress, for: transferId)
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms between updates
        }
    }
    
    /// Reset mock state for new test
    func reset() {
        isDiscovering = false
        isPublishing = false
        connectedDevices.removeAll()
        startDiscoveryCallCount = 0
        stopDiscoveryCallCount = 0
        sendFileCallCount = 0
        receiveFileCallCount = 0
        shouldThrowOnConnect = false
        shouldThrowOnSendFile = false
        shouldThrowOnReceiveFile = false
        mockReceivedFileURL = nil
        sendFileDelay = 0
        receiveFileDelay = 0
    }
}
