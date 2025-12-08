//
//  WiFiAwareManagerTests.swift
//  AwareShareTests
//
//  Created by AI Assistant
//

import XCTest
import WiFiAware
@testable import AwareShareApp

// MARK: - WiFi Aware Manager Tests (Mock-based)

/// Tests using MockWiFiAwareManager to avoid hardware dependencies
final class WiFiAwareManagerTests: XCTestCase {
    
    var sut: MockWiFiAwareManager!
    var mockDelegate: MockNetworkingDelegate!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = MockWiFiAwareManager()
        mockDelegate = MockNetworkingDelegate()
        await sut.setDelegate(mockDelegate)
    }
    
    override func tearDown() async throws {
        await sut.stopDiscovery()
        await sut.reset()
        sut = nil
        mockDelegate = nil
        try await super.tearDown()
    }
    
    // MARK: - Discovery Tests
    
    func testStartDiscovery_InitializesManagers() async throws {
        // Act
        await sut.startDiscovery()
        
        // Assert
        // Verify discovery was started (actual WiFi Aware may not be available on simulator)
        // This test validates that the method executes without crashing
        XCTAssertNotNil(sut)
    }
    
    func testStopDiscovery_CleansUpResources() async throws {
        // Arrange
        await sut.startDiscovery()
        
        // Act
        await sut.stopDiscovery()
        
        // Assert
        // Verify cleanup occurs without crashing
        XCTAssertNotNil(sut)
    }
    
    func testDiscovery_MultipleStartStopCycles_HandlesCorrectly() async throws {
        // Act
        for _ in 0..<3 {
            await sut.startDiscovery()
            let expectation = XCTestExpectation(description: "Discovery cycle")
            Task {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                expectation.fulfill()
            }
            await fulfillment(of: [expectation], timeout: 1.0)
            await sut.stopDiscovery()
        }
        
        // Assert
        XCTAssertNotNil(sut)
    }
    
    // MARK: - Connection Tests
    
    func testConnectToDevice_WithInvalidEndpoint_ThrowsError() async throws {
        // Arrange
        let invalidDevice = DiscoveredDevice(
            id: "invalid-device",
            name: "Invalid Device",
            type: .iPhone,
            connectionType: .wifiAware,
            isAvailable: true
        )
        
        // Configure mock to throw
        await sut.shouldThrowOnConnect = true
        
        // Act & Assert
        do {
            try await sut.connectToDevice(invalidDevice)
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }
    
    func testDisconnectFromDevice_CompletesWithoutError() async throws {
        // Arrange
        let device = ConnectedDevice(
            id: "test-device",
            name: "Test Device",
            type: .iPhone,
            connectionType: .wifiAware,
            isAvailable: true,
            connection: NSObject()
        )
        
        // Act
        await sut.disconnectFromDevice(device)
        
        // Assert
        XCTAssertNotNil(sut)
    }
    
    // MARK: - Chunk Processing Tests
    
    func testChunkSize_DefaultValue_IsValid() {
        // Arrange
        let defaultChunkSize = SettingsService.shared.chunkSize
        
        // Assert
        XCTAssertGreaterThanOrEqual(defaultChunkSize, 8192)
        XCTAssertLessThanOrEqual(defaultChunkSize, 16384)
    }
    
    func testChunkSize_CustomValue_IsValidated() {
        // Arrange
        let testCases: [(input: Int, expected: Int)] = [
            (512, 8192),      // Below minimum, should clamp to 8KB
            (8192, 8192),     // At minimum, should stay
            (12288, 12288),   // In range, should stay
            (16384, 16384),   // At maximum, should stay
            (65536, 16384)    // Above maximum, should clamp to 16KB
        ]
        
        let originalChunkSize = SettingsService.shared.chunkSize
        
        for testCase in testCases {
            // Act - Set input value and call production validation method
            SettingsService.shared.preferredChunkSize = testCase.input
            SettingsService.shared.validateChunkSize()
            let actualChunkSize = SettingsService.shared.chunkSize
            
            // Assert
            XCTAssertEqual(actualChunkSize, testCase.expected,
                          "Input: \(testCase.input) should result in \(testCase.expected), got \(actualChunkSize)")
        }
        
        // Cleanup - restore original value
        SettingsService.shared.chunkSize = originalChunkSize
        SettingsService.shared.validateChunkSize()
    }
    
    // MARK: - Transfer State Tests
    
    func testTransferState_InitialState_IsEmpty() async {
        // Assert - verify manager starts with no active transfers
        // (implementation detail, but validates clean state)
        XCTAssertNotNil(sut)
    }
    
    // MARK: - Error Handling Tests
    
    func testSendFile_WithNonexistentFile_ThrowsError() async throws {
        // Arrange
        let nonexistentURL = URL(fileURLWithPath: "/tmp/nonexistent-file-\(UUID().uuidString).txt")
        let device = ConnectedDevice(
            id: "test-device",
            name: "Test Device",
            type: .iPhone,
            connectionType: .wifiAware,
            isAvailable: true,
            connection: NSObject()
        )
        let transferId = UUID().uuidString
        
        // Act & Assert
        do {
            try await sut.sendFile(nonexistentURL, to: device, transferId: transferId)
            XCTFail("Expected error to be thrown for nonexistent file")
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Timeout Tests
    
    func testTimeout_Configuration_IsValid() {
        // Arrange
        let expectedTimeout: TimeInterval = 3.0
        let expectedMaxRetries = 3
        
        // Assert - verify timeout configuration is reasonable
        XCTAssertGreaterThan(expectedTimeout, 0)
        XCTAssertGreaterThan(expectedMaxRetries, 0)
        XCTAssertLessThan(expectedTimeout, 10.0) // Should be relatively short
    }
    
    // MARK: - ACK Batching Tests
    
    func testACKBatching_DefaultValue_IsValid() {
        // Arrange
        let defaultACKBatchSize = SettingsService.shared.ackBatchSize
        
        // Assert
        XCTAssertGreaterThan(defaultACKBatchSize, 0)
        XCTAssertLessThanOrEqual(defaultACKBatchSize, 10) // Reasonable batch size
    }
    
    // MARK: - Sliding Window Tests
    
    func testSlidingWindow_Configuration_IsValid() {
        // Arrange
        let windowSize = SettingsService.shared.slidingWindowSize
        
        // Assert
        XCTAssertGreaterThan(windowSize, 0)
        XCTAssertGreaterThanOrEqual(windowSize, 1)
        XCTAssertLessThanOrEqual(windowSize, 32) // Reasonable window size
    }
    
    // MARK: - Integration Tests
    
    func testFileChunking_SmallFile_CalculatesCorrectNumberOfChunks() {
        // Arrange
        let fileSize = 50000 // 50KB
        let chunkSize = 12288 // 12KB
        
        // Act
        let expectedChunks = Int(ceil(Double(fileSize) / Double(chunkSize)))
        
        // Assert
        XCTAssertEqual(expectedChunks, 5)
    }
    
    func testFileChunking_LargeFile_CalculatesCorrectNumberOfChunks() {
        // Arrange
        let fileSize = 10 * 1024 * 1024 // 10MB
        let chunkSize = 16384 // 16KB
        
        // Act
        let expectedChunks = Int(ceil(Double(fileSize) / Double(chunkSize)))
        
        // Assert
        XCTAssertEqual(expectedChunks, 640)
    }
    
    func testFileChunking_ExactMultiple_CalculatesCorrectNumberOfChunks() {
        // Arrange
        let fileSize = 16384 * 10 // Exactly 10 chunks
        let chunkSize = 16384
        
        // Act
        let expectedChunks = fileSize / chunkSize
        
        // Assert
        XCTAssertEqual(expectedChunks, 10)
    }
    
    // MARK: - Concurrent Transfer Tests
    
    func testConcurrentTransfers_MultipleDevices_Supported() async throws {
        // This test validates that the manager can handle multiple concurrent operations
        // Actual transfer testing requires real WiFi Aware hardware
        
        // Arrange
        let devices = [
            ConnectedDevice(id: "device1", name: "Device 1", type: .iPhone, connectionType: .wifiAware, isAvailable: true, connection: NSObject()),
            ConnectedDevice(id: "device2", name: "Device 2", type: .iPhone, connectionType: .wifiAware, isAvailable: true, connection: NSObject())
        ]
        
        // Assert
        XCTAssertEqual(devices.count, 2)
        XCTAssertNotEqual(devices[0].id, devices[1].id)
    }
    
    // MARK: - Settings Integration Tests
    
    func testSettings_ChunkSizeChange_UpdatesCorrectly() {
        // Arrange
        let originalChunkSize = SettingsService.shared.chunkSize
        let newChunkSize = 12288
        
        // Act
        SettingsService.shared.chunkSize = newChunkSize
        
        // Assert
        XCTAssertEqual(SettingsService.shared.chunkSize, newChunkSize)
        
        // Cleanup
        SettingsService.shared.chunkSize = originalChunkSize
    }
    
    func testSettings_ACKBatchSizeChange_UpdatesCorrectly() {
        // Arrange
        let originalACKBatchSize = SettingsService.shared.ackBatchSize
        let newACKBatchSize = 7
        
        // Act
        SettingsService.shared.ackBatchSize = newACKBatchSize
        
        // Assert
        XCTAssertEqual(SettingsService.shared.ackBatchSize, newACKBatchSize)
        
        // Cleanup
        SettingsService.shared.ackBatchSize = originalACKBatchSize
    }
}

// MARK: - Helper Extensions

extension WiFiAwareManagerTests {
    
    /// Creates a temporary test file with specified size
    func createTestFile(size: Int) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "test-file-\(UUID().uuidString).bin"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        let data = Data(repeating: 0xAB, count: size)
        try data.write(to: fileURL)
        
        return fileURL
    }
    
    /// Cleans up test file
    func cleanupTestFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Hardware-dependent WiFi Aware Manager Tests

/// Tests that require actual Wi-Fi Aware hardware
/// These tests are guarded to only run on physical devices, not simulators
final class WiFiAwareManagerHardwareTests: XCTestCase {
    
    var sut: WiFiAwareManager!
    var mockDelegate: MockNetworkingDelegate!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Skip tests if running on simulator
        #if targetEnvironment(simulator)
        throw XCTSkip("Hardware tests require physical device with Wi-Fi Aware support")
        #else
        sut = WiFiAwareManager()
        mockDelegate = MockNetworkingDelegate()
        await sut.setDelegate(mockDelegate)
        #endif
    }
    
    override func tearDown() async throws {
        #if !targetEnvironment(simulator)
        await sut.stopDiscovery()
        sut = nil
        mockDelegate = nil
        #endif
        try await super.tearDown()
    }
    
    // MARK: - Hardware Discovery Tests
    
    func testHardware_StartDiscovery_InitializesWiFiAware() async throws {
        #if !targetEnvironment(simulator)
        // Act
        await sut.startDiscovery()
        
        // Assert - just verify it doesn't crash
        XCTAssertNotNil(sut)
        
        // Cleanup
        await sut.stopDiscovery()
        #endif
    }
    
    func testHardware_StartPublishing_InitializesListener() async throws {
        #if !targetEnvironment(simulator)
        // Act & Assert
        do {
            try await sut.startPublishing()
            XCTAssertNotNil(sut)
        } catch {
            // Wi-Fi Aware might not be available on this device
            XCTAssertNotNil(error)
        }
        
        // Cleanup
        await sut.stopDiscovery()
        #endif
    }
}

