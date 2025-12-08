import Foundation
import OSLog

// MARK: - Chunk Receiver (Receiver-Side)

public actor ChunkReceiver: Sendable {
    private let ackBatchSize: Int
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "ChunkReceiver")

    private var totalChunks: Int = 0
    private var received: Set<Int> = []
    private var storage: [Int: Data] = [:]
    
    private var pendingAck: [Int] = []
    private var protocolError: String? = nil

    public init(ackBatchSize: Int) {
        self.ackBatchSize = max(1, ackBatchSize)
    }

    // Returns an array of chunk indices to ack when batch threshold reached; otherwise nil
    public func processChunk(chunkIndex: Int, data: Data, totalChunks: Int) async -> [Int]? {
        // Check for protocol errors first
        if let existingError = protocolError {
            logger.error("ChunkReceiver is in error state, rejecting chunk: \(existingError)")
            return nil
        }
        
        // Set totalChunks on first chunk, or validate consistency on subsequent chunks
        if self.totalChunks == 0 {
            self.totalChunks = totalChunks
        } else if self.totalChunks != totalChunks {
            // Protocol error: inconsistent totalChunks value
            let errorMessage = "Protocol error: received inconsistent totalChunks value. Expected \(self.totalChunks), but received \(totalChunks) for chunkIndex \(chunkIndex)"
            protocolError = errorMessage
            logger.error("\(errorMessage)")
            return nil
        }
        
        if chunkIndex < 0 || chunkIndex >= totalChunks { return nil }
        if received.contains(chunkIndex) { return nil }

        storage[chunkIndex] = data
        received.insert(chunkIndex)
        pendingAck.append(chunkIndex)

        if pendingAck.count >= ackBatchSize {
            let toAck = pendingAck
            pendingAck.removeAll(keepingCapacity: true)
            return toAck.sorted()
        }
        return nil
    }

    /// Flushes any remaining pending acknowledgements when transfer finishes.
    /// - Returns: An array of sorted chunk indices that were pending acknowledgement, or an empty array if none were pending.
    /// - Important: Callers should invoke this after `isComplete()` returns `true` to avoid lost acknowledgements and unnecessary retransmits.
    public func flushPendingAcks() async -> [Int] {
        if pendingAck.isEmpty {
            return []
        }
        let sortedAcks = pendingAck.sorted()
        pendingAck.removeAll(keepingCapacity: true)
        return sortedAcks
    }

    public func receivedCount() async -> Int { return received.count }
    
    public func hasProtocolError() async -> Bool {
        return protocolError != nil
    }
    
    public func getProtocolError() async -> String? {
        return protocolError
    }

    public func isComplete() async -> Bool {
        guard protocolError == nil else { return false }
        guard totalChunks > 0 else { return false }
        return received.count == totalChunks
    }

    public func getMissingChunks() async -> [Int] {
        guard protocolError == nil else { return [] }
        guard totalChunks > 0 else { return [] }
        let all = Set(0..<totalChunks)
        let missing = all.subtracting(received)
        return missing.sorted()
    }

    public func getCompleteData() async -> Data? {
        guard protocolError == nil else {
            logger.error("Cannot get complete data: protocol error occurred")
            return nil
        }
        guard await isComplete() else { return nil }
        var result = Data()
        for i in 0..<totalChunks {
            guard let chunk = storage[i] else {
                logger.error("Missing chunk while assembling at index: \(i)")
                return nil
            }
            result.append(chunk)
        }
        return result
    }
}


