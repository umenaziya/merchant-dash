import Foundation

// MARK: - App Error Types
enum AppError: Error, Equatable {
    case connectionFailed(transport: String, details: String)
    case transferFailed(reason: String)
    case invalidState(String)
    case permissionDenied(String)
    case deviceNotFound
    case deviceNotConnected
    case fileOperationFailed(details: String)
    case dataPathNotImplemented(transferId: String)
    
    var localizedDescription: String {
        switch self {
        case .connectionFailed(let transport, let details):
            return "Connection failed via \(transport): \(details)"
        case .transferFailed(let reason):
            return "Transfer failed: \(reason)"
        case .invalidState(let message):
            return "Invalid state: \(message)"
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        case .deviceNotFound:
            return "Device not found"
        case .deviceNotConnected:
            return "Device not connected"
        case .fileOperationFailed(let details):
            return "File operation failed: \(details)"
        case .dataPathNotImplemented(let transferId):
            return "Data path setup not implemented for transfer: \(transferId)"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .connectionFailed, .transferFailed, .deviceNotConnected:
            return true
        case .invalidState, .permissionDenied, .deviceNotFound, .fileOperationFailed, .dataPathNotImplemented:
            return false
        }
    }
}
