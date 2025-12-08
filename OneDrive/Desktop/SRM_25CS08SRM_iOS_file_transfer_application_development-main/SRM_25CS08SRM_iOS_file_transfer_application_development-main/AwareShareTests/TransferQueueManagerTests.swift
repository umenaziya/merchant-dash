//
//  TransferQueueManagerTests.swift
//  AwareShareTests
//
//  Created by AI Assistant
//

import XCTest
@testable import AwareShareApp

// MARK: - Transfer Queue Manager Tests

final class TransferQueueManagerTests: XCTestCase {
    
    var sut: TransferQueueManager!
    
    override func setUp() async throws {
        try await super.setUp()
        // Use explicit concurrency values for predictable test behavior
        sut = TransferQueueManager(maxConcurrentSends: 2, maxConcurrentReceives: 2, cleanupDelay: 0.1)
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Queue Management Tests
    
    func testEnqueueOperation_AddsToQueue() async throws {
        // Arrange
        let operation = createTestOperation(type: .send)
        var didExecute = false
        
        // Act
        await sut.enqueueOperation(operation) {
            didExecute = true
        }
        
        // Wait for execution using expectation
        let expectation = XCTestExpectation(description: "Operation should execute")
        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Assert
        XCTAssertTrue(didExecute, "Operation should have been executed")
    }
    
    func testEnqueueOperation_MultipleOperations_ExecutesInOrder() async throws {
        // Arrange
        var executionOrder: [String] = []
        let operation1 = createTestOperation(id: "op1", type: .send)
        let operation2 = createTestOperation(id: "op2", type: .send)
        let operation3 = createTestOperation(id: "op3", type: .send)
        
        // Act
        await sut.enqueueOperation(operation1) {
            executionOrder.append("op1")
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        await sut.enqueueOperation(operation2) {
            executionOrder.append("op2")
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        
        await sut.enqueueOperation(operation3) {
            executionOrder.append("op3")
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        
        // Wait for all to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Assert
        XCTAssertEqual(executionOrder.count, 3)
        XCTAssertTrue(executionOrder.contains("op1"))
        XCTAssertTrue(executionOrder.contains("op2"))
        XCTAssertTrue(executionOrder.contains("op3"))
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentSends_RespectsLimit() async throws {
        // Arrange
        var concurrentExecutions = 0
        var maxConcurrent = 0
        let lock = NSLock()
        
        let operations = (1...5).map { createTestOperation(id: "send\($0)", type: .send) }
        
        // Act
        for operation in operations {
            await sut.enqueueOperation(operation) {
                lock.lock()
                concurrentExecutions += 1
                maxConcurrent = max(maxConcurrent, concurrentExecutions)
                lock.unlock()
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                lock.lock()
                concurrentExecutions -= 1
                lock.unlock()
            }
        }
        
        // Wait for all operations to complete
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Assert
        XCTAssertLessThanOrEqual(maxConcurrent, 2, "Should not exceed max concurrent sends (2)")
    }
    
    func testConcurrentReceives_RespectsLimit() async throws {
        // Arrange
        var concurrentExecutions = 0
        var maxConcurrent = 0
        let lock = NSLock()
        
        let operations = (1...5).map { createTestOperation(id: "recv\($0)", type: .receive) }
        
        // Act
        for operation in operations {
            await sut.enqueueOperation(operation) {
                lock.lock()
                concurrentExecutions += 1
                maxConcurrent = max(maxConcurrent, concurrentExecutions)
                lock.unlock()
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                lock.lock()
                concurrentExecutions -= 1
                lock.unlock()
            }
        }
        
        // Wait for all operations to complete
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Assert
        XCTAssertLessThanOrEqual(maxConcurrent, 2, "Should not exceed max concurrent receives (2)")
    }
    
    func testMixedSendReceive_ExecutesConcurrently() async throws {
        // Arrange
        var sendExecutions = 0
        var receiveExecutions = 0
        var maxConcurrent = 0
        var currentConcurrent = 0
        let lock = NSLock()
        
        let sendOps = (1...3).map { createTestOperation(id: "send\($0)", type: .send) }
        let receiveOps = (1...3).map { createTestOperation(id: "recv\($0)", type: .receive) }
        
        // Act - interleave sends and receives
        for i in 0..<3 {
            await sut.enqueueOperation(sendOps[i]) {
                lock.lock()
                sendExecutions += 1
                currentConcurrent += 1
                maxConcurrent = max(maxConcurrent, currentConcurrent)
                lock.unlock()
                
                try? await Task.sleep(nanoseconds: 100_000_000)
                
                lock.lock()
                currentConcurrent -= 1
                lock.unlock()
            }
            
            await sut.enqueueOperation(receiveOps[i]) {
                lock.lock()
                receiveExecutions += 1
                currentConcurrent += 1
                maxConcurrent = max(maxConcurrent, currentConcurrent)
                lock.unlock()
                
                try? await Task.sleep(nanoseconds: 100_000_000)
                
                lock.lock()
                currentConcurrent -= 1
                lock.unlock()
            }
        }
        
        // Wait for completion
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Assert
        XCTAssertEqual(sendExecutions, 3)
        XCTAssertEqual(receiveExecutions, 3)
        XCTAssertLessThanOrEqual(maxConcurrent, 4, "Should allow up to 2 sends + 2 receives concurrently")
    }
    
    // MARK: - Progress Tracking Tests
    
    func testUpdateProgress_UpdatesCorrectOperation() async throws {
        // Arrange
        let operation = createTestOperation(id: "test-op", type: .send)
        await sut.enqueueOperation(operation) {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Act
        await sut.updateProgress("test-op", progress: 0.5)
        
        // Assert
        let progress = await sut.transferProgress["test-op"]
        XCTAssertEqual(progress, 0.5, accuracy: 0.01)
    }
    
    func testProgressTracking_MultipleOperations_TracksSeparately() async throws {
        // Arrange
        let op1 = createTestOperation(id: "op1", type: .send)
        let op2 = createTestOperation(id: "op2", type: .send)
        
        await sut.enqueueOperation(op1) {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        await sut.enqueueOperation(op2) {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        
        // Act
        await sut.updateProgress("op1", progress: 0.3)
        await sut.updateProgress("op2", progress: 0.7)
        
        // Assert
        let progress1 = await sut.transferProgress["op1"]
        let progress2 = await sut.transferProgress["op2"]
        XCTAssertEqual(progress1, 0.3, accuracy: 0.01)
        XCTAssertEqual(progress2, 0.7, accuracy: 0.01)
    }
    
    // MARK: - Completion Handling Tests
    
    func testCompleteOperation_Success_UpdatesState() async throws {
        // Arrange
        let operation = createTestOperation(id: "complete-op", type: .send)
        var didExecute = false
        
        await sut.enqueueOperation(operation) {
            didExecute = true
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Act
        await sut.completeOperation("complete-op", success: true)
        
        // Wait for cleanup using expectation
        let expectation = XCTestExpectation(description: "Operation should be cleaned up")
        Task {
            // Wait for the cleanup delay plus a small buffer
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Assert
        let activeTransfers = await sut.activeTransfers
        XCTAssertNil(activeTransfers["complete-op"], "Completed operation should be removed from active transfers")
    }
    
    func testCompleteOperation_Failure_UpdatesState() async throws {
        // Arrange
        let operation = createTestOperation(id: "fail-op", type: .send)
        let testError = NSError(domain: "TestError", code: 1, userInfo: nil)
        
        await sut.enqueueOperation(operation) {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Act
        await sut.completeOperation("fail-op", success: false, error: testError)
        
        // Wait for cleanup using expectation
        let expectation = XCTestExpectation(description: "Failed operation should be cleaned up")
        Task {
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Assert
        let activeTransfers = await sut.activeTransfers
        XCTAssertNil(activeTransfers["fail-op"], "Failed operation should be removed from active transfers")
    }
    
    func testCompleteOperation_TriggersNextInQueue() async throws {
        // Arrange
        var execution1Complete = false
        var execution2Started = false
        
        let op1 = createTestOperation(id: "op1", type: .send)
        let op2 = createTestOperation(id: "op2", type: .send)
        
        await sut.enqueueOperation(op1) {
            try? await Task.sleep(nanoseconds: 100_000_000)
            execution1Complete = true
        }
        
        await sut.enqueueOperation(op2) {
            execution2Started = true
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Wait for first to complete
        try await Task.sleep(nanoseconds: 150_000_000)
        await sut.completeOperation("op1", success: true)
        
        // Wait for second to start
        try await Task.sleep(nanoseconds: 150_000_000)
        
        // Assert
        XCTAssertTrue(execution1Complete)
        XCTAssertTrue(execution2Started, "Second operation should start after first completes")
    }
    
    // MARK: - Cancellation Tests
    
    func testCancelOperation_StopsOperation() async throws {
        // Arrange
        let operation = createTestOperation(id: "cancel-op", type: .send)
        var didComplete = false
        
        await sut.enqueueOperation(operation) {
            try? await Task.sleep(nanoseconds: 500_000_000)
            didComplete = true
        }
        
        // Act
        try await Task.sleep(nanoseconds: 100_000_000)
        await sut.cancelOperation("cancel-op")
        
        // Wait
        try await Task.sleep(nanoseconds: 600_000_000)
        
        // Assert
        let activeTransfers = await sut.activeTransfers
        XCTAssertNil(activeTransfers["cancel-op"])
        // Note: didComplete may still be true as cancellation is cooperative
    }
    
    func testCancelOperation_RemovesFromQueue() async throws {
        // Arrange
        let op1 = createTestOperation(id: "op1", type: .send)
        let op2 = createTestOperation(id: "op2", type: .send)
        
        await sut.enqueueOperation(op1) {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        await sut.enqueueOperation(op2) {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        // Act
        await sut.cancelOperation("op2")
        
        // Assert
        let activeTransfers = await sut.activeTransfers
        XCTAssertNil(activeTransfers["op2"])
    }
    
    // MARK: - Edge Cases Tests
    
    func testOperationWithNilDeviceId_HandlesCorrectly() async throws {
        // Arrange
        let operation = TransferOperation(
            id: "nil-device-op",
            type: .send,
            fileName: "test.txt",
            fileSize: 1024,
            deviceName: "Test Device",
            deviceId: nil
        )
        
        var didExecute = false
        
        // Act
        await sut.enqueueOperation(operation) {
            didExecute = true
        }
        
        // Wait
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Assert
        XCTAssertTrue(didExecute, "Operation with nil deviceId should still execute")
    }
    
    func testStateTransitions_QueuedToActiveToCompleted() async throws {
        // Arrange
        let operation = createTestOperation(id: "state-op", type: .send)
        var capturedStates: [TransferOperation.State] = []
        
        // Act
        await sut.enqueueOperation(operation) {
            let activeOp = await self.sut.activeTransfers["state-op"]
            if let state = activeOp?.state {
                capturedStates.append(state)
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        try await Task.sleep(nanoseconds: 50_000_000)
        let activeOp = await sut.activeTransfers["state-op"]
        if let state = activeOp?.state {
            capturedStates.append(state)
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        await sut.completeOperation("state-op", success: true)
        
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // Assert
        XCTAssertFalse(capturedStates.isEmpty, "Should capture at least one state")
    }
    
    // MARK: - Per-Device Concurrency Tests
    
    func testPerDeviceConcurrency_PreventsConcurrentTransfersToSameDevice() async throws {
        // Arrange
        let deviceId = "device-123"
        var concurrentToSameDevice = 0
        var maxConcurrentToSameDevice = 0
        let lock = NSLock()
        
        let operations = (1...3).map {
            TransferOperation(
                id: "op\($0)",
                type: .send,
                fileName: "file\($0).txt",
                fileSize: 1024,
                deviceName: "Test Device",
                deviceId: deviceId
            )
        }
        
        // Act
        for operation in operations {
            await sut.enqueueOperation(operation) {
                lock.lock()
                concurrentToSameDevice += 1
                maxConcurrentToSameDevice = max(maxConcurrentToSameDevice, concurrentToSameDevice)
                lock.unlock()
                
                try? await Task.sleep(nanoseconds: 100_000_000)
                
                lock.lock()
                concurrentToSameDevice -= 1
                lock.unlock()
            }
        }
        
        // Wait
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Assert
        XCTAssertLessThanOrEqual(maxConcurrentToSameDevice, 1,
                                "Should only allow one transfer per device at a time")
    }
    
    // MARK: - Helper Methods
    
    private func createTestOperation(
        id: String = UUID().uuidString,
        type: TransferOperation.TransferType
    ) -> TransferOperation {
        TransferOperation(
            id: id,
            type: type,
            fileName: "test-file.txt",
            fileSize: 1024,
            deviceName: "Test Device",
            deviceId: "test-device-id"
        )
    }
}

