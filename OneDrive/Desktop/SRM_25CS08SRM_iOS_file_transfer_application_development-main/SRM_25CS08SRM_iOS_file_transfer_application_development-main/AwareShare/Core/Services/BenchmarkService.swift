import Foundation
import SwiftUI
import OSLog
import Combine

// MARK: - Benchmark Service

@MainActor
class BenchmarkService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var activeMetrics: [String: TransferMetrics] = [:]
    @Published var history: [TransferRecord] = []
    @Published var isEnabled = true
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "BenchmarkService")
    private let maxHistoryCount = 100
    private let userDefaultsKey = "com.awareshare.benchmark.history"
    
    // MARK: - Singleton
    
    static let shared = BenchmarkService()
    
    private init() {
        loadHistory()
    }
    
    // MARK: - Public Methods
    
    func startTracking(transferId: String, fileName: String, fileSize: Int64, deviceName: String, connectionType: ConnectionType) {
        guard isEnabled else { return }
        
        let metrics = TransferMetrics(
            transferId: transferId,
            fileName: fileName,
            fileSize: fileSize,
            deviceName: deviceName,
            connectionType: connectionType,
            startTime: Date()
        )
        
        activeMetrics[transferId] = metrics
        logger.info("Started tracking transfer: \(transferId)")
    }
    
    func updateProgress(transferId: String, bytesTransferred: Int64) {
        guard isEnabled, var metrics = activeMetrics[transferId] else { return }
        
        metrics.bytesTransferred = bytesTransferred
        metrics.lastUpdateTime = Date()
        
        // Calculate speed
        let elapsed = metrics.lastUpdateTime.timeIntervalSince(metrics.startTime)
        if elapsed > 0 {
            metrics.averageSpeed = Double(bytesTransferred) / elapsed
            metrics.currentSpeed = metrics.averageSpeed // Simplified; could use moving average
        }
        
        // Calculate ETA
        if metrics.averageSpeed > 0 {
            let remainingBytes = metrics.fileSize - bytesTransferred
            metrics.estimatedTimeRemaining = Double(remainingBytes) / metrics.averageSpeed
        }
        
        activeMetrics[transferId] = metrics
    }
    
    func completeTransfer(transferId: String, success: Bool, error: String? = nil) {
        guard isEnabled, var metrics = activeMetrics[transferId] else { return }
        
        metrics.endTime = Date()
        metrics.success = success
        metrics.errorMessage = error
        
        // Calculate final metrics
        if let endTime = metrics.endTime {
            let duration = endTime.timeIntervalSince(metrics.startTime)
            metrics.duration = duration
            
            if duration > 0 {
                metrics.averageSpeed = Double(metrics.bytesTransferred) / duration
            }
        }
        
        // Create record and add to history
        let record = TransferRecord(metrics: metrics)
        history.insert(record, at: 0)
        
        // Trim history
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
        
        // Save history
        saveHistory()
        
        // Remove from active
        activeMetrics.removeValue(forKey: transferId)
        
        logger.info("Completed tracking transfer: \(transferId), success: \(success)")
    }
    
    func cancelTransfer(transferId: String) {
        guard isEnabled else { return }
        
        activeMetrics.removeValue(forKey: transferId)
        logger.info("Cancelled tracking transfer: \(transferId)")
    }
    
    func getMetrics(for transferId: String) -> TransferMetrics? {
        return activeMetrics[transferId]
    }
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
        logger.info("Cleared benchmark history")
    }
    
    func exportHistory() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(history),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        
        return json
    }
    
    func exportHistoryAsCSV() -> String {
        var csv = "Transfer ID,File Name,File Size,Device Name,Connection Type,Start Time,End Time,Duration,Bytes Transferred,Average Speed,Success,Error\n"
        
        let dateFormatter = ISO8601DateFormatter()
        
        // Helper function to escape CSV string values
        func escapeCSVValue(_ value: String) -> String {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        
        for record in history {
            let row = [
                escapeCSVValue(record.id.uuidString),
                escapeCSVValue(record.fileName),
                escapeCSVValue("\(record.fileSize)"),
                escapeCSVValue(record.deviceName),
                escapeCSVValue(record.connectionType.rawValue),
                escapeCSVValue(dateFormatter.string(from: record.startTime)),
                escapeCSVValue(record.endTime.map { dateFormatter.string(from: $0) } ?? ""),
                escapeCSVValue(String(format: "%.2f", record.duration ?? 0)),
                escapeCSVValue("\(record.bytesTransferred)"),
                escapeCSVValue(String(format: "%.2f", record.averageSpeed)),
                escapeCSVValue("\(record.success)"),
                escapeCSVValue(record.errorMessage ?? "")
            ].joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv
    }
    
    // MARK: - Statistics
    
    func getStatistics(for connectionType: ConnectionType? = nil) -> BenchmarkStatistics {
        let filteredRecords = connectionType == nil ? history : history.filter { $0.connectionType == connectionType }
        
        let successfulTransfers = filteredRecords.filter { $0.success }
        let totalTransfers = filteredRecords.count
        let successRate = totalTransfers > 0 ? Double(successfulTransfers.count) / Double(totalTransfers) : 0
        
        let speeds = successfulTransfers.compactMap { $0.averageSpeed }
        let averageSpeed = speeds.isEmpty ? 0 : speeds.reduce(0, +) / Double(speeds.count)
        let maxSpeed = speeds.max() ?? 0
        let minSpeed = speeds.isEmpty ? 0 : speeds.min() ?? 0
        
        let totalBytes = successfulTransfers.reduce(0) { $0 + $1.bytesTransferred }
        let totalDuration = successfulTransfers.compactMap { $0.duration }.reduce(0, +)
        
        return BenchmarkStatistics(
            totalTransfers: totalTransfers,
            successfulTransfers: successfulTransfers.count,
            failedTransfers: totalTransfers - successfulTransfers.count,
            successRate: successRate,
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            minSpeed: minSpeed,
            totalBytesTransferred: totalBytes,
            totalDuration: totalDuration
        )
    }
    
    // MARK: - Persistence
    
    private func saveHistory() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(history) else {
            logger.error("Failed to encode history")
            return
        }
        
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
        logger.debug("Saved benchmark history")
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            logger.debug("No saved history found")
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let loadedHistory = try? decoder.decode([TransferRecord].self, from: data) else {
            logger.error("Failed to decode history")
            return
        }
        
        history = loadedHistory
        logger.info("Loaded \(self.history.count) records from history")
    }
}

// MARK: - Transfer Metrics

struct TransferMetrics {
    let transferId: String
    let fileName: String
    let fileSize: Int64
    let deviceName: String
    let connectionType: ConnectionType
    let startTime: Date
    
    var endTime: Date?
    var duration: TimeInterval?
    var bytesTransferred: Int64 = 0
    var averageSpeed: Double = 0 // bytes per second
    var currentSpeed: Double = 0 // bytes per second
    var estimatedTimeRemaining: TimeInterval?
    var success: Bool = false
    var errorMessage: String?
    var lastUpdateTime: Date
    
    init(transferId: String, fileName: String, fileSize: Int64, deviceName: String, connectionType: ConnectionType, startTime: Date) {
        self.transferId = transferId
        self.fileName = fileName
        self.fileSize = fileSize
        self.deviceName = deviceName
        self.connectionType = connectionType
        self.startTime = startTime
        self.lastUpdateTime = startTime
    }
    
    var progress: Double {
        guard fileSize > 0 else { return 0 }
        return Double(bytesTransferred) / Double(fileSize)
    }
    
    var formattedSpeed: String {
        return ByteCountFormatter.string(fromByteCount: Int64(averageSpeed), countStyle: .file) + "/s"
    }
    
    var formattedETA: String {
        guard let eta = estimatedTimeRemaining, eta > 0 else { return "Calculating..." }
        
        if eta < 60 {
            return String(format: "%.0fs", eta)
        } else if eta < 3600 {
            return String(format: "%.0fm", eta / 60)
        } else {
            return String(format: "%.1fh", eta / 3600)
        }
    }
}

// MARK: - Transfer Record

struct TransferRecord: Identifiable, Codable {
    let id: UUID
    let transferId: String
    let fileName: String
    let fileSize: Int64
    let deviceName: String
    let connectionType: ConnectionType
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval?
    let bytesTransferred: Int64
    let averageSpeed: Double
    let success: Bool
    let errorMessage: String?
    
    init(metrics: TransferMetrics) {
        self.id = UUID()
        self.transferId = metrics.transferId
        self.fileName = metrics.fileName
        self.fileSize = metrics.fileSize
        self.deviceName = metrics.deviceName
        self.connectionType = metrics.connectionType
        self.startTime = metrics.startTime
        self.endTime = metrics.endTime
        self.duration = metrics.duration
        self.bytesTransferred = metrics.bytesTransferred
        self.averageSpeed = metrics.averageSpeed
        self.success = metrics.success
        self.errorMessage = metrics.errorMessage
    }
    
    var formattedDuration: String {
        guard let duration = duration else { return "N/A" }
        
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else if duration < 3600 {
            return String(format: "%.1fm", duration / 60)
        } else {
            return String(format: "%.1fh", duration / 3600)
        }
    }
    
    var formattedSpeed: String {
        return ByteCountFormatter.string(fromByteCount: Int64(averageSpeed), countStyle: .file) + "/s"
    }
    
    var formattedFileSize: String {
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

// MARK: - Benchmark Statistics

struct BenchmarkStatistics {
    let totalTransfers: Int
    let successfulTransfers: Int
    let failedTransfers: Int
    let successRate: Double
    let averageSpeed: Double
    let maxSpeed: Double
    let minSpeed: Double
    let totalBytesTransferred: Int64
    let totalDuration: TimeInterval
    
    var formattedAverageSpeed: String {
        return ByteCountFormatter.string(fromByteCount: Int64(averageSpeed), countStyle: .file) + "/s"
    }
    
    var formattedMaxSpeed: String {
        return ByteCountFormatter.string(fromByteCount: Int64(maxSpeed), countStyle: .file) + "/s"
    }
    
    var formattedMinSpeed: String {
        return ByteCountFormatter.string(fromByteCount: Int64(minSpeed), countStyle: .file) + "/s"
    }
    
    var formattedTotalBytes: String {
        return ByteCountFormatter.string(fromByteCount: totalBytesTransferred, countStyle: .file)
    }
    
    var formattedSuccessRate: String {
        return String(format: "%.1f%%", successRate * 100)
    }
}
