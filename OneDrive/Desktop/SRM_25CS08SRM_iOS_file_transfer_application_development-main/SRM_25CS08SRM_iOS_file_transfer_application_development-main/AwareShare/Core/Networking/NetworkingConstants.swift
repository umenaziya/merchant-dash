import Foundation

// MARK: - Networking Constants

/// Centralized constants for networking components
struct NetworkingConstants {
    
    // MARK: - BLE Constants
    
    struct BLE {
        static let defaultMTUSize = 23
        static let maxMTUSize = 512
        static let conservativeMTUSize = 185
        static let maxChunkSize = 20
        static let chunkTimeout: TimeInterval = 5.0
        static let maxRetries = 3
        static let healthCheckInterval: TimeInterval = 30.0
        static let reconnectDelay: TimeInterval = 5.0
        static let maxReconnectAttempts = 3
    }
    
    // MARK: - Wi-Fi Aware Constants
    
    struct WiFiAware {
        static let dataPathThreshold = 10 * 1024 * 1024 // 10MB
        static let defaultBufferSize = 64 * 1024 // 64KB
        static let windowSize = 10
        static let ackBatchSize = 5
        static let handshakeTimeout: TimeInterval = 30.0
        static let chunkTimeout: TimeInterval = 5.0
        static let maxRetries = 3
    }
    
    // MARK: - AirDrop Constants
    
    struct AirDrop {
        static let maxFileSize: Int64 = 1_000_000_000 // 1GB
        static let supportedFileTypes = [
            "public.image",
            "public.movie",
            "public.audio",
            "public.data",
            "public.text",
            "public.plain-text",
            "public.rtf",
            "public.html",
            "public.xml",
            "public.pdf",
            "com.adobe.pdf",
            "public.composite-content",
            "public.archive",
            "public.zip-archive",
            "public.tar-archive",
            "public.gzip-archive",
            "public.bzip2-archive",
            "public.7z-archive",
            "public.rar-archive"
        ]
    }
    
    // MARK: - Multipeer Constants
    
    struct Multipeer {
        static let serviceType = "awareshare"
        static let maxChunkSize = 1024 * 1024 // 1MB
        static let discoveryTimeout: TimeInterval = 30.0
        static let connectionTimeout: TimeInterval = 10.0
    }
    
    // MARK: - Transfer Constants
    
    struct Transfer {
        static let defaultChunkSize = 8 * 1024 // 8KB
        static let maxChunkSize = 16 * 1024 // 16KB
        static let progressUpdateInterval: TimeInterval = 0.1 // 100ms
        static let transferTimeout: TimeInterval = 300.0 // 5 minutes
    }
    
    // MARK: - Connection Constants
    
    struct Connection {
        static let healthCheckInterval: TimeInterval = 30.0
        static let maxReconnectAttempts = 3
        static let reconnectDelay: TimeInterval = 5.0
        static let connectionTimeout: TimeInterval = 10.0
    }
    
    // MARK: - Service UUIDs
    
    struct ServiceUUIDs {
        static let bleService = "52D6E035-6071-4C7A-A758-82AC28CB58AC"
        static let characteristic = "9081F62B-B850-46E4-B9F1-9C37832C98C7"
        static let fileTransferCharacteristic = "7944B95F-A3EF-4C05-B900-E397D98AABDF"
        static let ackCharacteristic = "6396DA44-4FDC-4CFF-A33E-2D9138B8AA0B"
    }
    
    // MARK: - Error Codes
    
    struct ErrorCodes {
        static let networkManagerNotInitialized = 1
        static let noConnectionFound = 2
        static let receiverRejected = 3
        static let fileNotAccessible = 4
        static let encodingFailed = 5
        static let reconstructionFailed = 6
        static let endpointNotFound = 7
        static let fileOpenFailed = 8
        static let transferTimeout = 9
        static let peripheralNotConnected = 10
    }
    
    // MARK: - Performance Constants
    
    struct Performance {
        static let slidingWindowSize = 10
        static let ackBatchSize = 5
        static let retryTimeout: TimeInterval = 5.0
        static let maxRetries = 3
        static let chunkSizeMultiplier = 0.8 // Use 80% of MTU for data
    }
}


enum TransferQoS {
    case background
    case utility
    case `default`
    case userInitiated
    case userInteractive
    
    /// Returns the corresponding DispatchQoS value for system integration.
    /// Use this when creating DispatchQueue or Task with QoS requirements.
    var dispatchQoS: DispatchQoS {
        switch self {
        case .background: return .background
        case .utility: return .utility
        case .default: return .default
        case .userInitiated: return .userInitiated
        case .userInteractive: return .userInteractive
        }
    }

    var priority: Float {
        switch self {
        case .background: return 0.1
        case .utility: return 0.3
        case .default: return 0.5
        case .userInitiated: return 0.7
        case .userInteractive: return 1.0
        }
    }

    var systemPriority: Int {
        switch self {
        case .background: return 9
        case .utility: return 17
        case .default: return 21
        case .userInitiated: return 25
        case .userInteractive: return 33
        }
    }
}

// MARK: - Transfer Priorities

enum TransferPriority: Int, CaseIterable {
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}
