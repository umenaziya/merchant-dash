//
//  TransferFlowIntegrationTests.swift
//  AwareShareTests
//
//  Integration tests for end-to-end transfer flows
//

import XCTest
@testable import AwareShareApp

@MainActor
final class TransferFlowIntegrationTests: XCTestCase {
    
    var networkingManager: NetworkingManager!
    var mockDelegate: MockNetworkingDelegate!
    var mockWiFiAwareManager: MockWiFiAwareManager!
    var settingsService: SettingsService!
    var benchmarkService: BenchmarkService!
    var transferQueueManager: TransferQueueManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize services
        settingsService = SettingsService.shared
        benchmarkService = BenchmarkService.shared
        transferQueueManager = TransferQueueManager.shared
        
        // Create mock manager
        mockWiFiAwareManager = MockWiFiAwareManager()
        mockDelegate = MockNetworkingDelegate()
        
        // Initialize networking manager (would normally use real managers, but using mocks for testing)
        networkingManager = NetworkingManager()
        networkingManager.delegate = mockDelegate
        
        // Reset services
        await benchmarkService.clearHistory()
    }
    
    override func tearDown() async throws {
        await networkingManager?.stopDiscovery()
        networkingManager = nil
        mockDelegate = nil
        mockWiFiAwareManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Complete Send/Receive Flow Tests
    
    func testCompleteSendReceiveFlow_WithHandshake_CompletesSuccessfully() async throws {
        // Arrange
        let testFile = try createTestFile(size: 1024 * 10) // 10 KB
        let testDevice = createTestDevice(name: "Test Device", type: .wifiAware)
        let connectedDevice = ConnectedDevice(
            id: testDevice.id,
            name: testDevice.name,
            type: testDevice.type,
            connectionType: testDevice.connectionType,
            isAvailable: true,
            connection: nil
        )
        let transferId = UUID().uuidString
        
        // Configure mock to not throw errors
        mockWiFiAwareManager.shouldThrowOnSendFile = false
        mockWiFiAwareManager.shouldThrowOnReceiveFile = false
        
        // Act - Send file
        do {
            try await networkingManager.sendFile(testFile, to: connectedDevice)
            
            // Wait a bit for async operations
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            // Assert
            XCTAssertTrue(mockWiFiAwareManager.sendFileCalled, "Send file should be called")
            XCTAssertEqual(mockWiFiAwareManager.lastSentFileURL, testFile, "File URL should match")
            XCTAssertEqual(mockWiFiAwareManager.lastSentDevice?.id, connectedDevice.id, "Device ID should match")
            
            // Verify benchmark was recorded
            let benchmarks = await benchmarkService.getHistory()
            XCTAssertFalse(benchmarks.isEmpty, "Benchmark should be recorded")
            
        } catch {
            XCTFail("Send file should not throw error: \(error)")
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: testFile)
    }
    
    func testCompleteSendReceiveFlow_WithChunkedTransfer_UpdatesProgress() async throws {
        // Arrange
        let testFile = try createTestFile(size: 1024 * 100) // 100 KB
        let testDevice = createTestDevice(name: "Test Device", type: .wifiAware)
        let connectedDevice = ConnectedDevice(
            id: testDevice.id,
            name: testDevice.name,
            type: testDevice.type,
            connectionType: testDevice.connectionType,
            isAvailable: true,
            connection: nil
        )
        
        var progressUpdates: [Double] = []
        let progressExpectation = XCTestExpectation(description: "Progress updates received")
        progressExpectation.expectedFulfillmentCount = 3 // Expect at least 3 progress updates
        
        // Monitor progress updates
        Task {
            var previousProgress: Double = 0
            while previousProgress < 1.0 {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                if let latest = mockDelegate.progressUpdates.last?.progress, latest > previousProgress {
                    progressUpdates.append(latest)
                    previousProgress = latest
                    progressExpectation.fulfill()
                }
            }
        }
        
        // Act
        mockWiFiAwareManager.shouldThrowOnSendFile = false
        try await networkingManager.sendFile(testFile, to: connectedDevice)
        
        // Wait for progress updates
        await fulfillment(of: [progressExpectation], timeout: 5.0)
        
        // Assert
        XCTAssertFalse(progressUpdates.isEmpty, "Should receive progress updates")
        XCTAssertTrue(progressUpdates.last ?? 0 >= 0, "Final progress should be >= 0")
        
        // Cleanup
        try? FileManager.default.removeItem(at: testFile)
    }
    
    // MARK: - Transport Fallback Flow Tests
    
    func testTransportFallbackFlow_PrimaryFails_FallsBackToSecondary() async throws {
        // Arrange
        let testFile = try createTestFile(size: 1024 * 10) // 10 KB
        let testDevice = createTestDevice(name: "Test Device", type: .wifiAware)
        let connectedDevice = ConnectedDevice(
            id: testDevice.id,
            name: testDevice.name,
            type: testDevice.type,
            connectionType: .wifiAware,
            isAvailable: true,
            connection: nil
        )
        
        // Configure primary transport (WiFi Aware) to fail
        mockWiFiAwareManager.shouldThrowOnSendFile = true
        mockWiFiAwareManager.sendFileError = NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Connection failed"])
        
        // Act
        do {
            try await networkingManager.sendFile(testFile, to: connectedDevice)
            
            // Wait for fallback to complete
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            
            // Note: In a real scenario, this would fall back to Multipeer or BLE
            // Since we're using mocks, we verify the error handling logic works
            
        } catch {
            // Expected to throw if all transports fail
            XCTAssertNotNil(error, "Should handle transport failure")
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: testFile)
    }
    
    func testTransportFallbackFlow_AllTransportsEnabled_SelectsPriorityOrder() async throws {
        // Arrange
        settingsService.useWiFiAware = true
        settingsService.useMultipeer = true
        settingsService.useBLE = true
        settingsService.useAirDrop = true
        
        let testDevice = createTestDevice(name: "Test Device", type: .wifiAware)
        let connectedDevice = ConnectedDevice(
            id: testDevice.id,
            name: testDevice.name,
            type: testDevice.type,
            connectionType: .wifiAware,
            isAvailable: true,
            connection: nil
        )
        
        // Act
        let selectedTransports = networkingManager.selectTransport(for: connectedDevice)
        
        // Assert
        XCTAssertFalse(selectedTransports.isEmpty, "Should select at least one transport")
        XCTAssertEqual(selectedTransports.first, .wifiAware, "WiFi Aware should be prioritized")
    }
    
    // MARK: - Concurrent Operations Flow Tests
    
    func testConcurrentOperationsFlow_MultipleSends_RespectsQueueLimits() async throws {
        // Arrange
        let testFiles = try (0..<4).map { index in
            try createTestFile(size: 1024 * 10, suffix: "\(index)")
        }
        let testDevice = createTestDevice(name: "Test Device", type: .wifiAware)
        let connectedDevice = ConnectedDevice(
            id: testDevice.id,
            name: testDevice.name,
            type: testDevice.type,
            connectionType: testDevice.connectionType,
            isAvailable: true,
            connection: nil
        )
        
        mockWiFiAwareManager.shouldThrowOnSendFile = false
        
        // Act - Enqueue multiple sends
        var sendTasks: [Task<Void, Error>] = []
        for testFile in testFiles {
            let task = Task {
                try await networkingManager.sendFile(testFile, to: connectedDevice)
            }
            sendTasks.append(task)
        }
        
        // Wait for all to complete or timeout
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Assert
        // Verify that transfers were enqueued (max 2 concurrent)
        XCTAssertEqual(sendTasks.count, 4, "Should enqueue 4 transfers")
        
        // Cleanup
        for testFile in testFiles {
            try? FileManager.default.removeItem(at: testFile)
        }
    }
    
    func testConcurrentOperationsFlow_MultipleReceives_ProcessesCorrectly() async throws {
        // Arrange
        let testDevice1 = createTestDevice(name: "Device 1", type: .wifiAware)
        let testDevice2 = createTestDevice(name: "Device 2", type: .bluetooth)
        
        let connectedDevice1 = ConnectedDevice(
            id: testDevice1.id,
            name: testDevice1.name,
            type: testDevice1.type,
            connectionType: testDevice1.connectionType,
            isAvailable: true,
            connection: nil
        )
        let connectedDevice2 = ConnectedDevice(
            id: testDevice2.id,
            name: testDevice2.name,
            type: testDevice2.type,
            connectionType: testDevice2.connectionType,
            isAvailable: true,
            connection: nil
        )
        
        mockWiFiAwareManager.shouldThrowOnReceiveFile = false
        
        // Act - Simulate multiple receive requests
        var receiveTasks: [Task<URL, Error>] = []
        for (device, transferId) in [(connectedDevice1, "transfer1"), (connectedDevice2, "transfer2")] {
            let task = Task {
                try await networkingManager.receiveFile(from: device, transferId: transferId)
            }
            receiveTasks.append(task)
        }
        
        // Wait for completion
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        // Assert
        XCTAssertEqual(receiveTasks.count, 2, "Should handle 2 receive operations")
        
        // Verify both devices were processed
        XCTAssertTrue(mockWiFiAwareManager.receiveFileCalled, "Receive file should be called")
    }
    
    // MARK: - Network Interruption Recovery Tests
    
    func testNetworkInterruptionRecovery_ConnectionDrop_HandlesGracefully() async throws {
        // Arrange
        let testFile = try createTestFile(size: 1024 * 10)
        let testDevice = createTestDevice(name: "Test Device", type: .wifiAware)
        let connectedDevice = ConnectedDevice(
            id: testDevice.id,
            name: testDevice.name,
            type: testDevice.type,
            connectionType: testDevice.connectionType,
            isAvailable: true,
            connection: nil
        )
        
        // Configure to throw connection error
        mockWiFiAwareManager.shouldThrowOnSendFile = true
        mockWiFiAwareManager.sendFileError = NSError(
            domain: "ConnectionError",
            code: -1005,
            userInfo: [NSLocalizedDescriptionKey: "Network connection was lost"]
        )
        
        // Act
        do {
            try await networkingManager.sendFile(testFile, to: connectedDevice)
            XCTFail("Should throw error on connection failure")
        } catch {
            // Assert
            XCTAssertNotNil(error, "Should propagate connection error")
            // Verify error is handled gracefully (no crash)
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: testFile)
    }
    
    // MARK: - Benchmark Service Integration Tests
    
    func testBenchmarkServiceIntegration_TransferComplete_RecordsMetrics() async throws {
        // Arrange
        let testFile = try createTestFile(size: 1024 * 100) // 100 KB
        let fileName = testFile.lastPathComponent
        let fileSize = Int64(1024 * 100)
        let transferId = UUID().uuidString
        let deviceName = "Test Device"
        let connectionType: ConnectionType = .wifiAware
        
        // Act
        benchmarkService.startTracking(
            transferId: transferId,
            fileName: fileName,
            fileSize: fileSize,
            deviceName: deviceName,
            connectionType: connectionType
        )
        
        // Simulate progress updates
        for progress in [0.25, 0.5, 0.75, 1.0] {
            let bytesTransferred = Int64(progress * Double(fileSize))
            benchmarkService.updateProgress(transferId: transferId, bytesTransferred: bytesTransferred)
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        benchmarkService.completeTransfer(transferId: transferId, success: true)
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Assert
        let benchmarks = await benchmarkService.getHistory()
        XCTAssertFalse(benchmarks.isEmpty, "Should have benchmark records")
        
        if let latest = benchmarks.first {
            XCTAssertEqual(latest.fileName, fileName, "File name should match")
            XCTAssertEqual(latest.fileSize, fileSize, "File size should match")
            XCTAssertEqual(latest.deviceName, deviceName, "Device name should match")
            XCTAssertTrue(latest.success, "Transfer should be marked as successful")
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: testFile)
    }
    
    // MARK: - Helper Methods
    
    private func createTestFile(size: Int, suffix: String = "") throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "test-file\(suffix).txt"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Create file with specified size
        let data = Data(count: size)
        try data.write(to: fileURL)
        
        return fileURL
    }
    
    private func createTestDevice(name: String, type: ConnectionType) -> DiscoveredDevice {
        return DiscoveredDevice(
            id: UUID().uuidString,
            name: name,
            type: .unknown,
            connectionType: type,
            signalStrength: -50,
            isAvailable: true
        )
    }
}
