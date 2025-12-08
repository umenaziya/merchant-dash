import Foundation
import OSLog


public actor SlidingWindowTransferManager: Sendable {
    
    // MARK: - Configuration
    
    /// Maximum number of unacknowledged chunks that can be in flight
    /// Larger windows provide better throughput but use more memory
    private let windowSize: Int
    
    /// Time to wait before retrying an unacknowledged chunk
    /// Should be tuned based on network latency and reliability
    private let retryTimeout: TimeInterval
    
    /// Maximum number of retry attempts per chunk before giving up
    /// Prevents infinite retry loops on permanently failed chunks
    private let maxRetries: Int
    
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "SlidingWindowTransferManager")

    // MARK: - State
    
    /// Cached chunks for retransmission
    /// Indexed by chunk number, contains the actual data payload
    private var chunks: [Data] = []
    
    /// Total number of chunks in the transfer
    /// Used to determine when transfer is complete
    private var totalChunks: Int = 0
    
    /// Next chunk number to send (sliding window base)
    /// Advances as acknowledgments are received
    private var nextChunkToSend: Int = 0
    
    /// Set of chunk indices currently in flight (sent but not acknowledged)
    /// Used to track which chunks need acknowledgment
    private var inFlight: Set<Int> = []
    
    /// Set of chunk indices that have been acknowledged
    /// Used to determine which chunks can be removed from memory
    private var acknowledged: Set<Int> = []
    
    /// Timestamps when chunks were sent
    /// Used for timeout detection and retry scheduling
    private var sendTimestamps: [Int: Date] = [:]
    
    /// Number of retry attempts for each chunk
    /// Used to implement exponential backoff and max retry limits
    private var retryCounts: [Int: Int] = [:]

    // Send closure retained to allow sending on ack-driven advancement
    private var sendChunkClosure: ((Int, Int, Data) async -> Void)?
    private var provideChunkClosure: ((Int) async -> Data?)?

    // Ack stream to receive acknowledgments from external handler
    private var ackStream: AsyncStream<[Int]>?
    private var ackContinuation: AsyncStream<[Int]>.Continuation?
    private var retryTask: Task<Void, Never>?
    
    // Flag to track transfer failure from chunk provider errors
    private var transferFailed: Bool = false

    // MARK: - Init
    public init(windowSize: Int, retryTimeout: TimeInterval, maxRetries: Int) {
        self.windowSize = max(1, windowSize)
        self.retryTimeout = max(0.25, retryTimeout)
        self.maxRetries = max(0, maxRetries)

        let (stream, continuation) = AsyncStream.makeStream(of: [Int].self)
        self.ackStream = stream
        self.ackContinuation = continuation
    }

    deinit {
        ackContinuation?.finish()
        retryTask?.cancel()
    }

  
    public func startSending(data: Data, sendChunk: @escaping (Int, Int, Data) async -> Void) async throws {
        guard chunks.isEmpty else { return }
        self.sendChunkClosure = sendChunk
        guard chunks.isEmpty && totalChunks == 0 else { return }

        // Split into chunks (default 16KB; configurable later via settings)
        let chunkSize: Int = 16 * 1024
        let totalSize: Int = data.count
        let totalChunks: Int = Int(ceil(Double(totalSize) / Double(chunkSize)))
        self.totalChunks = totalChunks

        self.chunks.reserveCapacity(totalChunks)
        var offset: Int = 0
        while offset < totalSize {
            let end = min(offset + chunkSize, totalSize)
            let range = offset..<end
            self.chunks.append(data.subdata(in: range))
            offset = end
        }

        // Prime the window
        try await fillWindowAndSend()

        // Start retry monitor
        startRetryMonitor()

        // Await acknowledgments and continue sending until all acknowledged
        guard let ackStream = ackStream else { return }
        for await received in ackStream {
            try Task.checkCancellation()
            // Update acks
            for idx in received {
                if !acknowledged.contains(idx) {
                    acknowledged.insert(idx)
                    inFlight.remove(idx)
                    sendTimestamps.removeValue(forKey: idx)
                    retryCounts.removeValue(forKey: idx)
                }
            }

            // Early exit if done
            if acknowledged.count >= totalChunks { break }

            // Fill window with new chunks
            try await fillWindowAndSend()
        }

        retryTask?.cancel()
    }

    public func startSending(totalSize: Int, chunkSize: Int, provideChunk: @escaping (Int) async -> Data?, sendChunk: @escaping (Int, Int, Data) async -> Void) async throws {
        guard chunks.isEmpty && totalChunks == 0 else { return }
        self.provideChunkClosure = provideChunk
        self.sendChunkClosure = sendChunk
        
        // Calculate total chunks
        let computedTotalChunks = Int(ceil(Double(totalSize) / Double(chunkSize)))
        self.totalChunks = computedTotalChunks
        
        // Prime the window
        try await fillWindowAndSend()
        
        // Start retry monitor
        startRetryMonitor()
        
        guard let ackStream = ackStream else { return }
        for await received in ackStream {
            try Task.checkCancellation()
            // Check if transfer has failed
            if transferFailed {
                retryTask?.cancel()
                throw NSError(
                    domain: "SlidingWindowTransferManager",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Transfer failed due to chunk provider error"]
                )
            }
            
            for idx in received {
                if !acknowledged.contains(idx) {
                    acknowledged.insert(idx)
                    inFlight.remove(idx)
                    sendTimestamps.removeValue(forKey: idx)
                    retryCounts.removeValue(forKey: idx)
                }
            }
            if acknowledged.count >= totalChunks { break }
            try await fillWindowAndSend()
        }
        retryTask?.cancel()
    }
    
    private func fillWindowAndSend() async throws {
        while inFlight.count < windowSize && nextChunkToSend < totalChunks {
            let idx = nextChunkToSend
            nextChunkToSend += 1
            
            inFlight.insert(idx)
            sendTimestamps[idx] = Date()
            retryCounts[idx] = 0
            
            // Get chunk data
            let data: Data?
            if let provide = provideChunkClosure {
                data = await provide(idx)
            } else if idx < chunks.count {
                data = chunks[idx]
            } else {
                data = nil
            }
            
            if let data = data, let send = sendChunkClosure {
                await send(idx, totalChunks, data)
            } else {
                logger.error("Failed to get chunk data for index: \(idx)")
                inFlight.remove(idx)
                sendTimestamps.removeValue(forKey: idx)
                retryCounts.removeValue(forKey: idx)
                transferFailed = true
                throw NSError(
                    domain: "SlidingWindowTransferManager",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to get chunk data for index \(idx)"]
                )
            }
        }
    }


    public func getProgress() async -> Double {
        guard totalChunks > 0 else { return 0.0 }
        return Double(acknowledged.count) / Double(totalChunks)
    }

    public func isTransferComplete() async -> Bool {
        return acknowledged.count >= totalChunks || transferFailed
    }

    public func processAcknowledgment(receivedChunks: [Int]) async {
        ackContinuation?.yield(receivedChunks)
    }

    private func startRetryMonitor() {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            guard let self else { return }
            while !(await self.isTransferComplete()) {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms tick
                await self.retryTimedOutChunksIfNeeded()
            }
        }
    }

    private func retryTimedOutChunksIfNeeded() async {
        let now = Date()
        for idx in inFlight {
            guard let sentAt = sendTimestamps[idx] else { continue }
            if now.timeIntervalSince(sentAt) >= retryTimeout {
                let count = (retryCounts[idx] ?? 0) + 1
                if count > maxRetries {
                    logger.error("Chunk retry limit exceeded for index: \(idx)")
                    // Clean up failed chunk and mark transfer as failed
                    inFlight.remove(idx)
                    sendTimestamps.removeValue(forKey: idx)
                    retryCounts.removeValue(forKey: idx)
                    transferFailed = true
                    // Cancel ack stream to abort main loop
                    ackContinuation?.finish()
                    continue
                }
                retryCounts[idx] = count
                sendTimestamps[idx] = Date()
                if let provide = provideChunkClosure {
                    if let data = await provide(idx) {
                        if let send = sendChunkClosure { await send(idx, totalChunks, data) }
                    } else {
                        logger.error("Chunk provider returned nil for index: \(idx) during retry")
                        // Clean up: remove from in-flight and clear related state
                        inFlight.remove(idx)
                        sendTimestamps.removeValue(forKey: idx)
                        retryCounts.removeValue(forKey: idx)
                        transferFailed = true
                        // Cancel ack stream to abort main loop
                        ackContinuation?.finish()
                    }
                } else if let send = sendChunkClosure {
                    await send(idx, totalChunks, chunks[idx])
                }
            }
        }
    }
}


