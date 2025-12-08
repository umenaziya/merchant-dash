import SwiftUI
import UIKit
import OSLog

// MARK: - Error Display Model

struct ErrorDisplayModel: Identifiable {
    let id = UUID()
    let title: String
    let userMessage: String
    let technicalDetails: String?
    let errorCode: String
    let iconName: String
    let iconColor: Color
    let isRetryable: Bool
    let primaryAction: ErrorAction?
    
    init(
        title: String,
        userMessage: String,
        technicalDetails: String? = nil,
        errorCode: String = "UNKNOWN",
        iconName: String = "exclamationmark.triangle.fill",
        iconColor: Color = .orange,
        isRetryable: Bool = false,
        primaryAction: ErrorAction? = nil
    ) {
        self.title = title
        self.userMessage = userMessage
        self.technicalDetails = technicalDetails
        self.errorCode = errorCode
        self.iconName = iconName
        self.iconColor = iconColor
        self.isRetryable = isRetryable
        self.primaryAction = primaryAction
    }
    
    // MARK: - Factory Methods
    
    static func connectionFailed(transport: String, details: String? = nil) -> ErrorDisplayModel {
        ErrorDisplayModel(
            title: "Connection Failed",
            userMessage: "Unable to connect via \(transport). Please check your connection and try again.",
            technicalDetails: details,
            errorCode: "CONN_FAILED",
            iconName: "wifi.exclamationmark",
            iconColor: .red,
            isRetryable: true
        )
    }
    
    static func transferFailed(reason: String, details: String? = nil) -> ErrorDisplayModel {
        ErrorDisplayModel(
            title: "Transfer Failed",
            userMessage: reason,
            technicalDetails: details,
            errorCode: "TRANSFER_FAILED",
            iconName: "arrow.down.circle.fill",
            iconColor: .orange,
            isRetryable: true
        )
    }
    
    static func permissionDenied(permission: String) -> ErrorDisplayModel {
        ErrorDisplayModel(
            title: "Permission Required",
            userMessage: "\(permission) permission is required for AwareShare to work. Please enable it in Settings.",
            errorCode: "PERMISSION_DENIED",
            iconName: "lock.shield.fill",
            iconColor: .yellow,
            isRetryable: false,
            primaryAction: ErrorAction(title: "Open Settings", type: .openSettings)
        )
    }
    
    static func fileAccessError(fileName: String, details: String? = nil) -> ErrorDisplayModel {
        ErrorDisplayModel(
            title: "File Access Error",
            userMessage: "Unable to access \(fileName). The file may have been moved or deleted.",
            technicalDetails: details,
            errorCode: "FILE_ACCESS",
            iconName: "doc.fill.badge.exclamationmark",
            iconColor: .red,
            isRetryable: false
        )
    }
    
    static func timeout() -> ErrorDisplayModel {
        ErrorDisplayModel(
            title: "Connection Timeout",
            userMessage: "The operation took too long to complete. Please try again.",
            errorCode: "TIMEOUT",
            iconName: "clock.badge.exclamationmark",
            iconColor: .orange,
            isRetryable: true
        )
    }
    
    static func deviceNotFound() -> ErrorDisplayModel {
        ErrorDisplayModel(
            title: "Device Not Found",
            userMessage: "The selected device is no longer available. It may have disconnected or moved out of range.",
            errorCode: "DEVICE_NOT_FOUND",
            iconName: "antenna.radiowaves.left.and.right.slash",
            iconColor: .red,
            isRetryable: true
        )
    }
    
    static func transferCancelled() -> ErrorDisplayModel {
        ErrorDisplayModel(
            title: "Transfer Cancelled",
            userMessage: "The file transfer was cancelled.",
            errorCode: "CANCELLED",
            iconName: "xmark.circle.fill",
            iconColor: .gray,
            isRetryable: false
        )
    }
}

// MARK: - Error Action

struct ErrorAction {
    let title: String
    let type: ErrorActionType
    
    enum ErrorActionType {
        case openSettings
        case retry
        case dismiss
        case custom(() -> Void)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        ErrorOverlayView(
            error: AppError.connectionFailed(
                transport: "Wi-Fi Aware",
                details: "WiFiAwareError.sessionFailed: The session could not be established."
            ),
            onRetry: {
                print("Retry tapped")
            },
            onDismiss: {
                print("Dismissed")
            }
        )
    }
}

