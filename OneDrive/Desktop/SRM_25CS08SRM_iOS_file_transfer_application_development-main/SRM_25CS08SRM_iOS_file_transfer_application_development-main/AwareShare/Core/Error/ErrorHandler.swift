import Foundation
import SwiftUI
import OSLog
import Combine

// MARK: - AwareShare Error Types

enum AwareShareError: LocalizedError, Identifiable {
    case networkUnavailable
    case deviceNotFound(deviceName: String)
    case connectionFailed(reason: String)
    case transferFailed(fileName: String, reason: String)
    case transferTimeout(fileName: String)
    case permissionDenied(type: PermissionType)
    case fileNotFound(path: String)
    case insufficientStorage(required: Int64, available: Int64)
    case invalidFileFormat(fileName: String)
    case bluetoothUnavailable
    case wifiAwareUnavailable
    case multipeerUnavailable
    case encryptionFailed
    case decryptionFailed
    case invalidConfiguration(message: String)
    case queueFull
    case deviceNotConnected(deviceName: String)
    case unsupportedOperation(operation: String)
    
    var id: String {
        switch self {
        case .networkUnavailable: return "networkUnavailable"
        case .deviceNotFound(let name): return "deviceNotFound_\(name)"
        case .connectionFailed(let reason): return "connectionFailed_\(reason)"
        case .transferFailed(let fileName, _): return "transferFailed_\(fileName)"
        case .transferTimeout(let fileName): return "transferTimeout_\(fileName)"
        case .permissionDenied(let type): return "permissionDenied_\(type.rawValue)"
        case .fileNotFound(let path): return "fileNotFound_\(path)"
        case .insufficientStorage: return "insufficientStorage"
        case .invalidFileFormat(let fileName): return "invalidFileFormat_\(fileName)"
        case .bluetoothUnavailable: return "bluetoothUnavailable"
        case .wifiAwareUnavailable: return "wifiAwareUnavailable"
        case .multipeerUnavailable: return "multipeerUnavailable"
        case .encryptionFailed: return "encryptionFailed"
        case .decryptionFailed: return "decryptionFailed"
        case .invalidConfiguration: return "invalidConfiguration"
        case .queueFull: return "queueFull"
        case .deviceNotConnected(let name): return "deviceNotConnected_\(name)"
        case .unsupportedOperation(let op): return "unsupportedOperation_\(op)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network Unavailable"
        case .deviceNotFound(let deviceName):
            return "Device '\(deviceName)' Not Found"
        case .connectionFailed(let reason):
            return "Connection Failed: \(reason)"
        case .transferFailed(let fileName, let reason):
            return "Failed to transfer '\(fileName)': \(reason)"
        case .transferTimeout(let fileName):
            return "Transfer of '\(fileName)' timed out"
        case .permissionDenied(let type):
            return "\(type.displayName) Permission Denied"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .insufficientStorage(let required, let available):
            return "Insufficient storage: need \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)), have \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file))"
        case .invalidFileFormat(let fileName):
            return "Invalid file format: \(fileName)"
        case .bluetoothUnavailable:
            return "Bluetooth Unavailable"
        case .wifiAwareUnavailable:
            return "Wi-Fi Aware Unavailable"
        case .multipeerUnavailable:
            return "Multipeer Connectivity Unavailable"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .queueFull:
            return "Transfer queue is full"
        case .deviceNotConnected(let deviceName):
            return "Device '\(deviceName)' is not connected"
        case .unsupportedOperation(let operation):
            return "Operation not supported: \(operation)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Check your network connection and try again."
        case .deviceNotFound:
            return "Make sure the device is nearby and discoverable."
        case .connectionFailed:
            return "Try reconnecting to the device."
        case .transferFailed:
            return "Check the connection and try sending the file again."
        case .transferTimeout:
            return "The transfer took too long. Try again with a smaller file or better connection."
        case .permissionDenied(let type):
            return "Enable \(type.displayName) permission in Settings to use this feature."
        case .fileNotFound:
            return "Make sure the file exists and try again."
        case .insufficientStorage:
            return "Free up some space and try again."
        case .invalidFileFormat:
            return "This file format is not supported."
        case .bluetoothUnavailable:
            return "Turn on Bluetooth in Settings and try again."
        case .wifiAwareUnavailable:
            return "Wi-Fi Aware is not available on this device or is disabled."
        case .multipeerUnavailable:
            return "Multipeer connectivity is not available. Try another connection method."
        case .encryptionFailed, .decryptionFailed:
            return "Try the operation again or contact support if the problem persists."
        case .invalidConfiguration:
            return "Check your settings and try again."
        case .queueFull:
            return "Wait for current transfers to complete before starting new ones."
        case .deviceNotConnected:
            return "Reconnect to the device and try again."
        case .unsupportedOperation:
            return "This operation is not supported on your device."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .networkUnavailable, .bluetoothUnavailable, .wifiAwareUnavailable, .permissionDenied:
            return .critical
        case .transferFailed, .transferTimeout, .connectionFailed, .deviceNotFound:
            return .high
        case .fileNotFound, .invalidFileFormat, .queueFull, .deviceNotConnected:
            return .medium
        case .insufficientStorage, .invalidConfiguration, .unsupportedOperation:
            return .low
        case .encryptionFailed, .decryptionFailed, .multipeerUnavailable:
            return .high
        }
    }
}

// MARK: - Supporting Types

enum PermissionType: String {
    case bluetooth = "Bluetooth"
    case wifiAware = "Wi-Fi Aware"
    case localNetwork = "Local Network"
    case nearbyInteraction = "Nearby Interaction"
    case photos = "Photos"
    case files = "Files"
    
    var displayName: String {
        return rawValue
    }
}

enum ErrorSeverity {
    case low
    case medium
    case high
    case critical
    
    var color: Color {
        switch self {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        case .critical: return Color(red: 0.8, green: 0.0, blue: 0.0)
        }
    }
}

// MARK: - Error Handler

@MainActor
class ErrorHandler: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentError: AwareShareError?
    @Published var showAlert = false
    @Published var errorHistory: [ErrorRecord] = []
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "ErrorHandler")
    private let maxHistoryCount = 50
    
    // MARK: - Singleton
    
    static let shared = ErrorHandler()
    
    private init() {}
    
    // MARK: - Public Methods
    
    func handle(_ error: Error, context: String? = nil) {
        logger.error("Error occurred: \(error.localizedDescription)")
        
        let awareShareError = convertToAwareShareError(error)
        
        // Record error
        let record = ErrorRecord(
            error: awareShareError,
            context: context,
            timestamp: Date()
        )
        errorHistory.insert(record, at: 0)
        
        // Trim history
        if errorHistory.count > maxHistoryCount {
            errorHistory = Array(errorHistory.prefix(maxHistoryCount))
        }
        
        // Show alert for high severity errors
        if awareShareError.severity == .high || awareShareError.severity == .critical {
            currentError = awareShareError
            showAlert = true
        }
    }
    
    func handle(_ awareShareError: AwareShareError, context: String? = nil) {
        logger.error("AwareShare error: \(awareShareError.errorDescription ?? "Unknown")")
        
        // Record error
        let record = ErrorRecord(
            error: awareShareError,
            context: context,
            timestamp: Date()
        )
        errorHistory.insert(record, at: 0)
        
        // Trim history
        if errorHistory.count > maxHistoryCount {
            errorHistory = Array(errorHistory.prefix(maxHistoryCount))
        }
        
        // Show alert
        currentError = awareShareError
        showAlert = true
    }
    
    func dismissCurrentError() {
        currentError = nil
        showAlert = false
    }
    
    func clearHistory() {
        errorHistory.removeAll()
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Private Methods
    
    private func convertToAwareShareError(_ error: Error) -> AwareShareError {
        // Check if already AwareShareError
        if let awareShareError = error as? AwareShareError {
            return awareShareError
        }
        
        // Convert NSError
        if let nsError = error as NSError? {
            switch nsError.domain {
            case "WiFiAwareManager":
                return .wifiAwareUnavailable
            case "BLEManager":
                return .bluetoothUnavailable
            case NSURLErrorDomain:
                return .networkUnavailable
            case NSCocoaErrorDomain:
                if nsError.code == NSFileReadNoSuchFileError {
                    return .fileNotFound(path: nsError.userInfo[NSFilePathErrorKey] as? String ?? "unknown")
                }
            default:
                break
            }
        }
        
        // Default conversion
        return .invalidConfiguration(message: error.localizedDescription)
    }
}

// MARK: - Error Record

struct ErrorRecord: Identifiable {
    let id = UUID()
    let error: AwareShareError
    let context: String?
    let timestamp: Date
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - Error Alert View

struct ErrorAlertView: ViewModifier {
    @ObservedObject var errorHandler: ErrorHandler
    
    func body(content: Content) -> some View {
        content
            .alert(
                errorHandler.currentError?.errorDescription ?? "Error",
                isPresented: $errorHandler.showAlert,
                presenting: errorHandler.currentError
            ) { error in
                // Primary action based on error type
                if case .permissionDenied = error {
                    Button("Open Settings") {
                        errorHandler.openSettings()
                        errorHandler.dismissCurrentError()
                    }
                    Button("Cancel", role: .cancel) {
                        errorHandler.dismissCurrentError()
                    }
                } else {
                    Button("OK") {
                        errorHandler.dismissCurrentError()
                    }
                }
            } message: { error in
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                }
            }
    }
}

extension View {
    func handleErrors(with errorHandler: ErrorHandler = .shared) -> some View {
        modifier(ErrorAlertView(errorHandler: errorHandler))
    }
}
