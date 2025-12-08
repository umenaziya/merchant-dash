//
//  ConcurrencyIntegrationTests.swift
//  AwareShareTests
//
//  Created by AI Assistant
//

import XCTest
@testable import AwareShareApp

// MARK: - Send/Receive Concurrency Integration Tests

final class ConcurrencyIntegrationTests: XCTestCase {
    
    var coordinator: AppCoordinator!
    var mockNetworkingManager: MockNetworkingManager!
    
    override func setUp() async throws {
        try await super.setUp()
        coordinator = AppCoordinator()
        mockNetworkingManager = MockNetworkingManager()
        coordinator.networkingManager = mockNetworkingManager
    }
    
    override func tearDown() async throws {
        coordinator = nil
        mockNetworkingManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Send/Receive Concurrency Tests
    
    func testConcurrentSendReceiveOperations_AreListedInActiveTransfers() async throws {
        // Arrange
        let device1 = createMockDevice(id: "device1", name: "Device 1")
        let device2 = createMockDevice(id: "device2", name: "Device 2")
        
        // Act - Start a receive session
        coordinator.selectedDevice = device1
        coordinator.transferMode = .receive
        coordinator.selectedFiles = [createMockSelectedFile(name: "received_file.txt")]
        
        // Simulate starting receive operation
        let receiveOperation = TransferOperation(
            id: "receive-op-1",
            type: .receive,
            fileName: "received_file.txt",
            fileSize: 1024,
            deviceName: device1.name,
            deviceId: device1.id
        )
        
        await mockNetworkingManager.simulateActiveTransfer(receiveOperation)
        
        // Start a send operation to a second device
        coordinator.selectedDevice = device2
        coordinator.transferMode = .send
        coordinator.selectedFiles = [createMockSelectedFile(name: "send_file.txt")]
        
        let sendOperation = TransferOperation(
            id: "send-op-1",
            type: .send,
            fileName: "send_file.txt",
            fileSize: 2048,
            deviceName: device2.name,
            deviceId: device2.id
        )
        
        await mockNetworkingManager.simulateActiveTransfer(sendOperation)
        
        // Wait for state updates
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Assert
        let activeTransfers = coordinator.getActiveTransfersList()
        XCTAssertEqual(activeTransfers.count, 2, "Should have 2 active transfers")
        
        let receiveOps = activeTransfers.filter { $0.type == .receive }
        let sendOps = activeTransfers.filter { $0.type == .send }
        
        XCTAssertEqual(receiveOps.count, 1, "Should have 1 receive operation")
        XCTAssertEqual(sendOps.count, 1, "Should have 1 send operation")
        
        XCTAssertEqual(receiveOps.first?.deviceId, device1.id, "Receive operation should be for device1")
        XCTAssertEqual(sendOps.first?.deviceId, device2.id, "Send operation should be for device2")
    }
    
    func testConcurrentOperations_ProgressTrackingWorksIndependently() async throws {
        // Arrange
        let device1 = createMockDevice(id: "device1", name: "Device 1")
        let device2 = createMockDevice(id: "device2", name: "Device 2")
        
        let receiveOperation = TransferOperation(
            id: "receive-op-1",
            type: .receive,
            fileName: "received_file.txt",
            fileSize: 1024,
            deviceName: device1.name,
            deviceId: device1.id
        )
        
        let sendOperation = TransferOperation(
            id: "send-op-1",
            type: .send,
            fileName: "send_file.txt",
            fileSize: 2048,
            deviceName: device2.name,
            deviceId: device2.id
        )
        
        // Act - Start both operations
        await mockNetworkingManager.simulateActiveTransfer(receiveOperation)
        await mockNetworkingManager.simulateActiveTransfer(sendOperation)
        
        // Update progress independently
        await mockNetworkingManager.simulateProgressUpdate("receive-op-1", progress: 0.3)
        await mockNetworkingManager.simulateProgressUpdate("send-op-1", progress: 0.7)
        
        // Wait for state updates
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Assert
        XCTAssertEqual(coordinator.transferProgress["receive-op-1"], 0.3, accuracy: 0.01)
        XCTAssertEqual(coordinator.transferProgress["send-op-1"], 0.7, accuracy: 0.01)
        
        // Update progress again
        await mockNetworkingManager.simulateProgressUpdate("receive-op-1", progress: 0.8)
        await mockNetworkingManager.simulateProgressUpdate("send-op-1", progress: 0.9)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(coordinator.transferProgress["receive-op-1"], 0.8, accuracy: 0.01)
        XCTAssertEqual(coordinator.transferProgress["send-op-1"], 0.9, accuracy: 0.01)
    }
    
    func testConcurrentOperations_CompletionHandlingWorksIndependently() async throws {
        // Arrange
        let device1 = createMockDevice(id: "device1", name: "Device 1")
        let device2 = createMockDevice(id: "device2", name: "Device 2")
        
        let receiveOperation = TransferOperation(
            id: "receive-op-1",
            type: .receive,
            fileName: "received_file.txt",
            fileSize: 1024,
            deviceName: device1.name,
            deviceId: device1.id
        )
        
        let sendOperation = TransferOperation(
            id: "send-op-1",
            type: .send,
            fileName: "send_file.txt",
            fileSize: 2048,
            deviceName: device2.name,
            deviceId: device2.id
        )
        
        // Act - Start both operations
        await mockNetworkingManager.simulateActiveTransfer(receiveOperation)
        await mockNetworkingManager.simulateActiveTransfer(sendOperation)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Complete receive operation first
        await mockNetworkingManager.simulateTransferCompletion("receive-op-1", success: true)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Assert - send operation should still be active
        let activeTransfers = coordinator.getActiveTransfersList()
        XCTAssertEqual(activeTransfers.count, 1, "Should have 1 active transfer after receive completes")
        XCTAssertEqual(activeTransfers.first?.id, "send-op-1", "Send operation should still be active")
        
        // Complete send operation
        await mockNetworkingManager.simulateTransferCompletion("send-op-1", success: true)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Assert - no active transfers
        let finalActiveTransfers = coordinator.getActiveTransfersList()
        XCTAssertEqual(finalActiveTransfers.count, 0, "Should have no active transfers after both complete")
    }
    
    func testConcurrentOperations_ErrorHandlingWorksIndependently() async throws {
        // Arrange
        let device1 = createMockDevice(id: "device1", name: "Device 1")
        let device2 = createMockDevice(id: "device2", name: "Device 2")
        
        let receiveOperation = TransferOperation(
            id: "receive-op-1",
            type: .receive,
            fileName: "received_file.txt",
            fileSize: 1024,
            deviceName: device1.name,
            deviceId: device1.id
        )
        
        let sendOperation = TransferOperation(
            id: "send-op-1",
            type: .send,
            fileName: "send_file.txt",
            fileSize: 2048,
            deviceName: device2.name,
            deviceId: device2.id
        )
        
        // Act - Start both operations
        await mockNetworkingManager.simulateActiveTransfer(receiveOperation)
        await mockNetworkingManager.simulateActiveTransfer(sendOperation)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Fail receive operation
        await mockNetworkingManager.simulateTransferCompletion("receive-op-1", success: false)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Assert - send operation should still be active
        let activeTransfers = coordinator.getActiveTransfersList()
        XCTAssertEqual(activeTransfers.count, 1, "Should have 1 active transfer after receive fails")
        XCTAssertEqual(activeTransfers.first?.id, "send-op-1", "Send operation should still be active")
        
        // Complete send operation successfully
        await mockNetworkingManager.simulateTransferCompletion("send-op-1", success: true)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Assert - no active transfers
        let finalActiveTransfers = coordinator.getActiveTransfersList()
        XCTAssertEqual(finalActiveTransfers.count, 0, "Should have no active transfers after send completes")
    }
    
    func testConcurrentOperations_TransferProgressViewShowsBothOperations() async throws {
        // Arrange
        let device1 = createMockDevice(id: "device1", name: "Device 1")
        let device2 = createMockDevice(id: "device2", name: "Device 2")
        
        let receiveOperation = TransferOperation(
            id: "receive-op-1",
            type: .receive,
            fileName: "received_file.txt",
            fileSize: 1024,
            deviceName: device1.name,
            deviceId: device1.id
        )
        
        let sendOperation = TransferOperation(
            id: "send-op-1",
            type: .send,
            fileName: "send_file.txt",
            fileSize: 2048,
            deviceName: device2.name,
            deviceId: device2.id
        )
        
        // Act - Start both operations
        await mockNetworkingManager.simulateActiveTransfer(receiveOperation)
        await mockNetworkingManager.simulateActiveTransfer(sendOperation)
        
        // Update progress
        await mockNetworkingManager.simulateProgressUpdate("receive-op-1", progress: 0.4)
        await mockNetworkingManager.simulateProgressUpdate("send-op-1", progress: 0.6)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Assert - Both operations should be visible in active transfers
        let activeTransfers = coordinator.getActiveTransfersList()
        XCTAssertEqual(activeTransfers.count, 2, "TransferProgressView should show both operations")
        
        // Verify both operations have correct progress
        XCTAssertEqual(coordinator.transferProgress["receive-op-1"], 0.4, accuracy: 0.01)
        XCTAssertEqual(coordinator.transferProgress["send-op-1"], 0.6, accuracy: 0.01)
        
        // Verify operations are sorted by creation time (newest first)
        XCTAssertEqual(activeTransfers[0].id, "send-op-1", "Newer operation should be first")
        XCTAssertEqual(activeTransfers[1].id, "receive-op-1", "Older operation should be second")
    }
    
    // MARK: - Helper Methods
    
    private func createMockDevice(id: String, name: String) -> DiscoveredDevice {
        DiscoveredDevice(
            id: id,
            name: name,
            type: .iPhone,
            connectionType: .wifiAware,
            isAvailable: true
        )
    }
    
    private func createMockSelectedFile(name: String) -> SelectedFile {
        SelectedFile(
            name: name,
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            size: 1024,
            type: .document
        )
    }
}

// MARK: - Mock Networking Manager

class MockNetworkingManager: NetworkingManager {
    private var mockActiveTransfers: [String: TransferOperation] = [:]
    private var mockTransferProgress: [String: Double] = [:]
    
    override var activeTransfers: [String: TransferOperation] {
        get { mockActiveTransfers }
        set { mockActiveTransfers = newValue }
    }
    
    override var transferProgress: [String: Double] {
        get { mockTransferProgress }
        set { mockTransferProgress = newValue }
    }
    
    func simulateActiveTransfer(_ operation: TransferOperation) async {
        mockActiveTransfers[operation.id] = operation
        // Trigger the @Published update
        objectWillChange.send()
    }
    
    func simulateProgressUpdate(_ transferId: String, progress: Double) async {
        mockTransferProgress[transferId] = progress
        // Trigger the @Published update
        objectWillChange.send()
    }
    
    func simulateTransferCompletion(_ transferId: String, success: Bool) async {
        mockActiveTransfers.removeValue(forKey: transferId)
        if success {
            mockTransferProgress[transferId] = 1.0
        } else {
            mockTransferProgress.removeValue(forKey: transferId)
        }
        // Trigger the @Published update
        objectWillChange.send()
    }
}
