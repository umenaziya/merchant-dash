import Foundation
import OSLog
import Combine

// MARK: - Transfer Queue Manager

@MainActor
class TransferQueueManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var activeTransfers: [String: TransferOperation] = [:]
    @Published var queuedTransfers: [TransferOperation] = []
    @Published var transferProgress: [String: Double] = [:]
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "TransferQueueManager")
    private let maxConcurrentSends: Int
    private let maxConcurrentReceives: Int
    private let cleanupDelaySeconds: Double
    
    // Track closures and per-device concurrency by type
    private var executionClosures: [String: () async -> Void] = [:]
    private var activeByDeviceIdAndType: [String: Set<TransferType>] = [:]
    
    private var activeSendCount = 0
    private var activeReceiveCount = 0
    
    // Track operations with nil deviceId separately
    private var unknownDeviceSendCount = 0
    private var unknownDeviceReceiveCount = 0
    private let maxUnknownDeviceOperations = 1 // Limit concurrent operations for unknown devices
    
    // MARK: - Initialization
    
    init(maxConcurrentSends: Int = 2, maxConcurrentReceives: Int = 2, cleanupDelay: Double = 8.0) {
        self.maxConcurrentSends = maxConcurrentSends
        self.maxConcurrentReceives = maxConcurrentReceives
        self.cleanupDelaySeconds = cleanupDelay
    }
    
    // MARK: - Enqueue Operations
    
    func enqueueOperation(_ operation: TransferOperation, execute: (@MainActor () async -> Void)? = nil) {
        logger.info("Enqueuing operation: \(operation.id) (\(operation.type.rawValue))")
        
        queuedTransfers.append(operation)
        activeTransfers[operation.id] = operation
        transferProgress[operation.id] = 0.0
        if let execute = execute { executionClosures[operation.id] = execute }
        
        processQueue()
    }
    
    // MARK: - Queue Processing
    
    private func processQueue() {
        // Process send operations
        while activeSendCount < maxConcurrentSends {
            guard let nextSend = queuedTransfers.first(where: { 
                $0.type == .send && $0.state == .queued 
            }), canStartOperation(nextSend) else {
                break
            }
            
            startOperation(nextSend)
        }
        
        // Process receive operations
        while activeReceiveCount < maxConcurrentReceives {
            guard let nextReceive = queuedTransfers.first(where: { 
                $0.type == .receive && $0.state == .queued 
            }), canStartOperation(nextReceive) else {
                break
            }
            
            startOperation(nextReceive)
        }
    }
    
    // MARK: - Operation Management
    
    private func startOperation(_ operation: TransferOperation) {
        logger.info("Starting operation: \(operation.id)")
        
        // Update state
        if let index = queuedTransfers.firstIndex(where: { $0.id == operation.id }) {
            queuedTransfers[index].state = .active
            activeTransfers[operation.id]?.state = .active
        }
        
        // Update counters
        switch operation.type {
        case .send:
            activeSendCount += 1
            if operation.deviceId == nil {
                unknownDeviceSendCount += 1
            }
        case .receive:
            activeReceiveCount += 1
            if operation.deviceId == nil {
                unknownDeviceReceiveCount += 1
            }
        }
        
        if let deviceId = activeTransfers[operation.id]?.deviceId {
            activeByDeviceIdAndType[deviceId, default: []].insert(operation.type)
        }
        
        // Execute the operation
        Task {
            await executeOperation(operation)
        }
    }
    
    private func executeOperation(_ operation: TransferOperation) async {
        logger.info("Executing operation: \(operation.id)")
        if let closure = executionClosures[operation.id] {
            await closure()
            executionClosures.removeValue(forKey: operation.id)
        }
    }
    
    func completeOperation(_ operationId: String, success: Bool, error: Error? = nil) async {
        logger.info("Completing operation: \(operationId), success: \(success)")
        
        guard let operation = activeTransfers[operationId] else {
            logger.error("Operation not found: \(operationId)")
            return
        }
        
        // Update state
        activeTransfers[operationId]?.state = success ? .completed : .failed
        
        if let index = queuedTransfers.firstIndex(where: { $0.id == operationId }) {
            queuedTransfers[index].state = success ? .completed : .failed
            if let error = error {
                queuedTransfers[index].error = error
            }
        }
        
        // Update counters
        switch operation.type {
        case .send:
            activeSendCount = max(0, activeSendCount - 1)
            if operation.deviceId == nil {
                unknownDeviceSendCount = max(0, unknownDeviceSendCount - 1)
            }
        case .receive:
            activeReceiveCount = max(0, activeReceiveCount - 1)
            if operation.deviceId == nil {
                unknownDeviceReceiveCount = max(0, unknownDeviceReceiveCount - 1)
            }
        }
        if let deviceId = activeTransfers[operationId]?.deviceId {
            activeByDeviceIdAndType[deviceId]?.remove(operation.type)
            if activeByDeviceIdAndType[deviceId]?.isEmpty == true {
                activeByDeviceIdAndType.removeValue(forKey: deviceId)
            }
        }
        
        // Set final progress
        transferProgress[operationId] = success ? 1.0 : 0.0
        
        // Notify completion callback if all transfers are done
        notifyCompletionIfNeeded()
        
        // Process next operations in queue
        processQueue()
        
        // Clean up completed operations after delay
        Task {
            try? await Task.sleep(nanoseconds: UInt64(cleanupDelaySeconds * 1_000_000_000))
            await removeCompletedOperation(operationId)
        }
    }
    
    private func notifyCompletionIfNeeded() {
        // Check if all active transfers are in completed or failed state
        let allDone = activeTransfers.values.allSatisfy { transfer in
            transfer.state == .completed || transfer.state == .failed
        }
        
        if allDone && !activeTransfers.isEmpty {
            // Collect completion info including any failures
            let completedCount = activeTransfers.values.filter { $0.state == .completed }.count
            let failedCount = activeTransfers.values.filter { $0.state == .failed }.count
            let failedTransfers = activeTransfers.values.filter { $0.state == .failed }
            
            let userInfo: [String: Any] = [
                "completedCount": completedCount,
                "failedCount": failedCount,
                "failedTransfers": failedTransfers.map { $0.id }
            ]
            
            // Notify via notification center that all transfers are complete
            NotificationCenter.default.post(name: .allTransfersComplete, object: nil, userInfo: userInfo)
        }
    }
    
    private func canStartOperation(_ operation: TransferOperation) -> Bool {
        // Handle nil deviceId operations with separate limits
        guard let deviceId = operation.deviceId else {
            // Check unknown device limits
            switch operation.type {
            case .send:
                return unknownDeviceSendCount < maxUnknownDeviceOperations
            case .receive:
                return unknownDeviceReceiveCount < maxUnknownDeviceOperations
            }
        }
        
        // Allow starting if this device is not already active for the same TransferType
        let activeTypes = activeByDeviceIdAndType[deviceId] ?? []
        return !activeTypes.contains(operation.type)
    }
    
    func updateProgress(_ operationId: String, progress: Double) {
        transferProgress[operationId] = progress
        
        if let index = queuedTransfers.firstIndex(where: { $0.id == operationId }) {
            queuedTransfers[index].progress = progress
            activeTransfers[operationId]?.progress = progress
        }
    }
    
    func cancelOperation(_ operationId: String) async {
        logger.info("Cancelling operation: \(operationId)")
        
        guard let operation = activeTransfers[operationId] else {
            return
        }
        
        // Update state
        activeTransfers[operationId]?.state = .cancelled
        
        if let index = queuedTransfers.firstIndex(where: { $0.id == operationId }) {
            queuedTransfers[index].state = .cancelled
        }
        
        // Update counters
        switch operation.type {
        case .send:
            activeSendCount = max(0, activeSendCount - 1)
        case .receive:
            activeReceiveCount = max(0, activeReceiveCount - 1)
        }
        
        // Process next operations
        processQueue()
    }
    
    private func removeCompletedOperation(_ operationId: String) async {
        queuedTransfers.removeAll { $0.id == operationId && ($0.state == .completed || $0.state == .failed) }
        
        // Keep in activeTransfers for UI display but mark as archived
        if activeTransfers[operationId]?.state == .completed || activeTransfers[operationId]?.state == .failed {
            // Remove after UI has had time to show completion
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 more seconds
            activeTransfers.removeValue(forKey: operationId)
            transferProgress.removeValue(forKey: operationId)
        }
    }
    
    // MARK: - Query Methods
    
    func getOperation(_ operationId: String) -> TransferOperation? {
        return activeTransfers[operationId]
    }
    
    func getActiveOperations() -> [TransferOperation] {
        return activeTransfers.values.filter { $0.state == .active }
    }
    
    func getQueuedOperations() -> [TransferOperation] {
        return queuedTransfers.filter { $0.state == .queued }
    }
}

// MARK: - Transfer Operation

struct TransferOperation: Identifiable, Equatable {
    let id: String
    let type: TransferType
    let fileName: String
    let fileSize: Int64
    let deviceName: String
    let deviceId: String?
    var state: TransferState
    var progress: Double
    var error: Error?
    let createdAt: Date
    
    init(id: String, type: TransferType, fileName: String, fileSize: Int64, deviceName: String, deviceId: String? = nil) {
        self.id = id
        self.type = type
        self.fileName = fileName
        self.fileSize = fileSize
        self.deviceName = deviceName
        self.deviceId = deviceId
        self.state = .queued
        self.progress = 0.0
        self.error = nil
        self.createdAt = Date()
    }
    
    static func == (lhs: TransferOperation, rhs: TransferOperation) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Supporting Types

enum TransferType: String, Hashable {
    case send
    case receive
}

enum TransferState {
    case queued
    case active
    case completed
    case failed
    case cancelled
}

// MARK: - Notification Names

extension Notification.Name {
    static let allTransfersComplete = Notification.Name("allTransfersComplete")
}
