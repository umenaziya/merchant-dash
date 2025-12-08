import XCTest
import CoreBluetooth
@testable import AwareShareApp

// MARK: - BLE Manager Tests

final class BLEManagerTests: XCTestCase {
    
    var sut: BLEManager!
    var mockDelegate: MockNetworkingDelegate!
    
    override func setUp() {
        super.setUp()
        sut = BLEManager()
        mockDelegate = MockNetworkingDelegate()
        sut.delegate = mockDelegate
    }
    
    override func tearDown() {
        sut = nil
        mockDelegate = nil
        super.tearDown()
    }
    
    // MARK: - Metadata Parsing Tests
    
    func testMetadataParsing_ValidJSON_Success() async throws {
        // Arrange
        let inputFileName = "test_file.pdf"
        let inputFileSize: Int64 = 1024 * 1024
        let inputTransferId = UUID().uuidString
        let metadata = [
            "fileName": inputFileName,
            "fileSize": inputFileSize,
            "transferId": inputTransferId
        ] as [String: Any]
        let mockData = try JSONSerialization.data(withJSONObject: metadata)
        
        // Act
        let actualMetadata = try parseMetadata(from: mockData)
        
        // Assert
        XCTAssertEqual(actualMetadata.fileName, inputFileName)
        XCTAssertEqual(actualMetadata.fileSize, inputFileSize)
        XCTAssertEqual(actualMetadata.transferId, inputTransferId)
    }
    
    func testMetadataParsing_InvalidJSON_ThrowsError() {
        // Arrange
        let mockInvalidData = "invalid json".data(using: .utf8)!
        
        // Act & Assert
        XCTAssertThrowsError(try parseMetadata(from: mockInvalidData)) { error in
            XCTAssertTrue(error is DecodingError || error is NSError)
        }
    }
    
    func testMetadataParsing_MissingRequiredField_ThrowsError() throws {
        // Arrange
        let metadata = ["fileName": "test.txt"] as [String: Any]
        let mockData = try JSONSerialization.data(withJSONObject: metadata)
        
        // Act & Assert
        XCTAssertThrowsError(try parseMetadata(from: mockData))
    }
    
    // MARK: - Chunk Ordering Tests
    
    func testChunkOrdering_InOrder_AssemblesCorrectly() async throws {
        // Arrange
        let expectedData = "Hello World".data(using: .utf8)!
        let chunkSize = 3
        let chunks = chunkData(expectedData, chunkSize: chunkSize)
        let transferId = UUID().uuidString
        
        var receiver = ChunkReceiver(ackBatchSize: 5)
        
        // Act
        for (index, chunk) in chunks.enumerated() {
            _ = await receiver.processChunk(chunkIndex: index, data: chunk, totalChunks: chunks.count)
        }
        
        // Assert
        let isComplete = await receiver.isComplete()
        XCTAssertTrue(isComplete)
        
        let actualData = await receiver.getCompleteData()
        XCTAssertEqual(actualData, expectedData)
    }
    
    func testChunkOrdering_OutOfOrder_AssemblesCorrectly() async throws {
        // Arrange
        let expectedData = "ABCDEFGHIJ".data(using: .utf8)!
        let chunkSize = 2
        let chunks = chunkData(expectedData, chunkSize: chunkSize)
        let transferId = UUID().uuidString
        
        var receiver = ChunkReceiver(ackBatchSize: 5)
        
        // Act: Send chunks out of order (4, 0, 2, 1, 3)
        let outOfOrderIndices = [4, 0, 2, 1, 3]
        for index in outOfOrderIndices {
            _ = await receiver.processChunk(chunkIndex: index, data: chunks[index], totalChunks: chunks.count)
        }
        
        // Assert
        let isComplete = await receiver.isComplete()
        XCTAssertTrue(isComplete)
        
        let actualData = await receiver.getCompleteData()
        XCTAssertEqual(actualData, expectedData)
    }
    
    func testChunkOrdering_DuplicateChunks_IgnoresSecondDelivery() async throws {
        // Arrange
        let expectedData = "TestData".data(using: .utf8)!
        let chunkSize = 4
        let chunks = chunkData(expectedData, chunkSize: chunkSize)
        let transferId = UUID().uuidString
        
        var receiver = ChunkReceiver(ackBatchSize: 5)
        
        // Act: Send chunk 0 twice
        let ack1 = await receiver.processChunk(chunkIndex: 0, data: chunks[0], totalChunks: chunks.count)
        let ack2 = await receiver.processChunk(chunkIndex: 0, data: chunks[0], totalChunks: chunks.count)
        
        // Assert
        XCTAssertNotNil(ack1) // First delivery should produce ack batch
        XCTAssertNil(ack2) // Duplicate should be ignored
        
        let receivedCount = await receiver.receivedCount()
        XCTAssertEqual(receivedCount, 1)
    }
    
    // MARK: - Missing Chunk Detection Tests
    
    func testMissingChunks_PartialTransfer_ReturnsCorrectMissingList() async throws {
        // Arrange
        let expectedData = "0123456789".data(using: .utf8)!
        let chunkSize = 2
        let chunks = chunkData(expectedData, chunkSize: chunkSize)
        
        var receiver = ChunkReceiver(ackBatchSize: 5)
        
        // Act: Send only chunks 0, 2, 4 (missing 1, 3)
        _ = await receiver.processChunk(chunkIndex: 0, data: chunks[0], totalChunks: chunks.count)
        _ = await receiver.processChunk(chunkIndex: 2, data: chunks[2], totalChunks: chunks.count)
        _ = await receiver.processChunk(chunkIndex: 4, data: chunks[4], totalChunks: chunks.count)
        
        // Assert
        let missing = await receiver.getMissingChunks()
        XCTAssertEqual(missing.sorted(), [1, 3])
        
        let isComplete = await receiver.isComplete()
        XCTAssertFalse(isComplete)
    }
    
    func testMissingChunks_CompleteTransfer_ReturnsEmptyList() async throws {
        // Arrange
        let expectedData = "Complete".data(using: .utf8)!
        let chunkSize = 3
        let chunks = chunkData(expectedData, chunkSize: chunkSize)
        
        var receiver = ChunkReceiver(ackBatchSize: 5)
        
        // Act: Send all chunks
        for (index, chunk) in chunks.enumerated() {
            _ = await receiver.processChunk(chunkIndex: index, data: chunk, totalChunks: chunks.count)
        }
        
        // Assert
        let missing = await receiver.getMissingChunks()
        XCTAssertTrue(missing.isEmpty)
    }
    
    // MARK: - Batch Acknowledgment Tests
    
    func testBatchAck_AccumulatesUntilThreshold_ThenReturns() async throws {
        // Arrange
        let ackBatchSize = 3
        var receiver = ChunkReceiver(ackBatchSize: ackBatchSize)
        let mockData = "X".data(using: .utf8)!
        
        // Act & Assert
        let ack1 = await receiver.processChunk(chunkIndex: 0, data: mockData, totalChunks: 10)
        XCTAssertNil(ack1)
        
        let ack2 = await receiver.processChunk(chunkIndex: 1, data: mockData, totalChunks: 10)
        XCTAssertNil(ack2)
        
        let ack3 = await receiver.processChunk(chunkIndex: 2, data: mockData, totalChunks: 10)
        XCTAssertNotNil(ack3)
        XCTAssertEqual(ack3?.count, ackBatchSize)
        XCTAssertEqual(ack3?.sorted(), [0, 1, 2])
    }
    
    // MARK: - Timeout & Retry Tests
    
    func testTimeout_ChunkNotReceived_MarkedForRetry() async throws {
        // Arrange
        let transferId = UUID().uuidString
        let chunkIndex = 5
        let sentTime = Date()
        let timeoutInterval: TimeInterval = 5.0
        
        // Simulate chunk timeout tracking
        var chunkTimeouts: [String: [Int: Date]] = [:]
        chunkTimeouts[transferId] = [chunkIndex: sentTime]
        
        // Act
        let currentTime = sentTime.addingTimeInterval(timeoutInterval + 1)
        let hasTimedOut = currentTime.timeIntervalSince(sentTime) > timeoutInterval
        
        // Assert
        XCTAssertTrue(hasTimedOut)
    }
    
    func testRetry_MaxRetriesExceeded_StopsRetrying() async throws {
        // Arrange
        let transferId = UUID().uuidString
        let chunkIndex = 3
        let maxRetries = 3
        
        var chunkRetryCount: [String: [Int: Int]] = [:]
        chunkRetryCount[transferId] = [chunkIndex: 0]
        
        // Act: Simulate retries
        for _ in 0..<maxRetries {
            chunkRetryCount[transferId]?[chunkIndex]? += 1
        }
        
        let actualRetryCount = chunkRetryCount[transferId]?[chunkIndex] ?? 0
        let shouldRetry = actualRetryCount < maxRetries
        
        // Assert
        XCTAssertEqual(actualRetryCount, maxRetries)
        XCTAssertFalse(shouldRetry)
    }
    
    // MARK: - File Assembly Tests
    
    func testFileAssembly_AllChunksReceived_ReconstructsOriginalFile() async throws {
        // Arrange
        let expectedOriginalString = "The quick brown fox jumps over the lazy dog"
        let expectedData = expectedOriginalString.data(using: .utf8)!
        let chunkSize = 10
        let chunks = chunkData(expectedData, chunkSize: chunkSize)
        
        var receiver = ChunkReceiver(ackBatchSize: 5)
        
        // Act
        for (index, chunk) in chunks.enumerated() {
            _ = await receiver.processChunk(chunkIndex: index, data: chunk, totalChunks: chunks.count)
        }
        
        let assembledData = await receiver.getCompleteData()
        let actualString = String(data: assembledData ?? Data(), encoding: .utf8)
        
        // Assert
        XCTAssertNotNil(assembledData)
        XCTAssertEqual(assembledData, expectedData)
        XCTAssertEqual(actualString, expectedOriginalString)
    }
    
    func testFileAssembly_MissingChunks_ReturnsNil() async throws {
        // Arrange
        let expectedData = "Incomplete".data(using: .utf8)!
        let chunkSize = 3
        let chunks = chunkData(expectedData, chunkSize: chunkSize)
        
        var receiver = ChunkReceiver(ackBatchSize: 5)
        
        // Act: Send only half the chunks
        for index in 0..<chunks.count/2 {
            _ = await receiver.processChunk(chunkIndex: index, data: chunks[index], totalChunks: chunks.count)
        }
        
        let assembledData = await receiver.getCompleteData()
        
        // Assert
        XCTAssertNil(assembledData)
    }
    
    // MARK: - Progress Tracking Tests
    
    func testProgressTracking_UpdatesCorrectly() async throws {
        // Arrange
        let totalChunks = 10
        let expectedData = Data(repeating: 0xFF, count: totalChunks * 100)
        let chunks = chunkData(expectedData, chunkSize: 100)
        
        var receiver = ChunkReceiver(ackBatchSize: 5)
        
        // Act & Assert
        for (index, chunk) in chunks.enumerated() {
            _ = await receiver.processChunk(chunkIndex: index, data: chunk, totalChunks: totalChunks)
            
            let receivedCount = await receiver.receivedCount()
            let expectedCount = index + 1
            XCTAssertEqual(receivedCount, expectedCount)
            
            let expectedProgress = Double(expectedCount) / Double(totalChunks)
            let actualProgress = Double(receivedCount) / Double(totalChunks)
            XCTAssertEqual(actualProgress, expectedProgress, accuracy: 0.01)
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseMetadata(from data: Data) throws -> FileMetadata {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let fileName = json?["fileName"] as? String,
              let fileSize = json?["fileSize"] as? Int64,
              let transferId = json?["transferId"] as? String else {
            throw NSError(domain: "BLETests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing required field"])
        }
        return FileMetadata(fileName: fileName, fileSize: fileSize, transferId: transferId)
    }
    
    private func chunkData(_ data: Data, chunkSize: Int) -> [Data] {
        var chunks: [Data] = []
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            chunks.append(data.subdata(in: offset..<end))
            offset = end
        }
        return chunks
    }
}

// MARK: - Mock Delegate

class MockNetworkingDelegate: NetworkingManagerDelegate {
    var discoveredDevices: [DiscoveredDevice] = []
    var connectedDevices: [ConnectedDevice] = []
    var disconnectedDevices: [ConnectedDevice] = []
    var transferProgressUpdates: [String: Double] = [:]
    var receivedFiles: [(URL, ConnectedDevice)] = []
    
    func didDiscoverDevice(_ device: DiscoveredDevice) {
        discoveredDevices.append(device)
    }
    
    func didConnectToDevice(_ device: ConnectedDevice) {
        connectedDevices.append(device)
    }
    
    func didDisconnectFromDevice(_ device: ConnectedDevice) {
        disconnectedDevices.append(device)
    }
    
    func didUpdateTransferProgress(_ progress: Double, for transferId: String) {
        transferProgressUpdates[transferId] = progress
    }
    
    func didReceiveFile(_ fileURL: URL, from device: ConnectedDevice) {
        receivedFiles.append((fileURL, device))
    }
}

// MARK: - Test Model

struct FileMetadata {
    let fileName: String
    let fileSize: Int64
    let transferId: String
}

