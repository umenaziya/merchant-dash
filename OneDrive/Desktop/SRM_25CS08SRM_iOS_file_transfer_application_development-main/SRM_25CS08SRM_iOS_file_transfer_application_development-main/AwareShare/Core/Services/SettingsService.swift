import Foundation
import SwiftUI
import UIKit
import Combine

// MARK: - Settings Service

/// Centralized service for managing app settings and preferences
@MainActor
class SettingsService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SettingsService()
    
    // MARK: - Transport Preferences
    
    @AppStorage("transport.wifiAware") var useWiFiAware: Bool = true
    @AppStorage("transport.bluetooth") var useBluetooth: Bool = true
    @AppStorage("transport.multipeer") var useMultipeer: Bool = true
    @AppStorage("transport.airdrop") var useAirDrop: Bool = true
    
    // MARK: - AirDrop Mode Settings
    
    /// Enable custom BLE discovery for AwareShare-to-AwareShare transfers
    /// When true: Uses custom discovery to find AwareShare devices
    /// When false: Goes directly to native share sheet (no custom discovery)
    @AppStorage("airdrop.useCustomDiscovery") var useCustomAirDropDiscovery: Bool = true
    
    // MARK: - Transfer Settings
    
    @AppStorage("transfer.autoAccept") var autoAcceptTransfers: Bool = false
    @AppStorage("transfer.overwriteExisting") var overwriteExisting: Bool = false
    @AppStorage("transfer.chunkSize") var preferredChunkSize: Int = 12288 // 12 KB default
    @AppStorage("transfer.trustedDevices") private var trustedDevicesCSV: String = ""
    
    // MARK: - Wi-Fi Aware Settings
    
    @AppStorage("wifiAware.ackBatchSize") var ackBatchSize: Int = 5
    @AppStorage("wifiAware.slidingWindowSize") var slidingWindowSize: Int = 10
    @AppStorage("wifiAware.handshakeTimeoutSeconds") var handshakeTimeoutSeconds: Double = 3.0
    @AppStorage("wifiAware.receiveTimeoutSeconds") var receiveTimeoutSeconds: Double = 60.0
    
    /// Computed property for backward compatibility with tests using `chunkSize`
    var chunkSize: Int {
        get { preferredChunkSize }
        set { preferredChunkSize = newValue }
    }
    
    // MARK: - Benchmarking
    
    @AppStorage("benchmark.enabled") var benchmarkEnabled: Bool = true
    
    // MARK: - Debug
    
    @AppStorage("debug.mockDevices") var enableMockDevices: Bool = false
    @AppStorage("debug.logLevel") var logLevel: String = "info"
    
    // MARK: - Capabilities
    
    @AppStorage("capability.androidEnabled") var androidDevicesEnabled: Bool = true
    
    // MARK: - Privacy
    
    @AppStorage("privacy.deviceName") var deviceName: String = UIDevice.current.name
    @AppStorage("profile.selectedAvatar") var selectedAvatarIndex: Int = 0
    
    // MARK: - Device Identity
    
    /// Persistent device identifier that remains stable across app restarts and name changes
    /// This is generated once and stored, ensuring the device identity remains consistent
    @AppStorage("privacy.deviceId") private var _deviceId: String = ""
    
    var deviceId: String {
        get {
            if _deviceId.isEmpty {
                // Generate and persist a new UUID if one doesn't exist
                _deviceId = UUID().uuidString
            }
            return _deviceId
        }
        set {
            _deviceId = newValue
        }
    }
    
    // MARK: - Permission Guidance Settings
    
    /// Show permission instructions when permissions are needed
    @AppStorage("permissions.showInstructions") var showPermissionInstructions: Bool = true
    
    /// Track how many times permission instructions have been shown
    @AppStorage("permissions.instructionsShownCount") var permissionInstructionsShownCount: Int = 0
    
    // MARK: - UI Preferences
    
    /// Prefer native AirDrop over custom discovery
    @AppStorage("ui.preferNativeAirDrop") var preferNativeAirDrop: Bool = false
    
    /// Show Quick Share tutorial on first launch
    @AppStorage("ui.showQuickShareTutorial") var showQuickShareTutorial: Bool = true
    
    /// App color scheme preference: "light", "dark", or nil for system default
    @AppStorage("ui.colorScheme") private var colorSchemeRaw: String = ""
    
    /// Get the preferred color scheme (nil means use system default)
    var preferredColorScheme: ColorScheme? {
        get {
            switch colorSchemeRaw.lowercased() {
            case "light": return .light
            case "dark": return .dark
            default: return nil // System default
            }
        }
        set {
            switch newValue {
            case .light: colorSchemeRaw = "light"
            case .dark: colorSchemeRaw = "dark"
            case nil: colorSchemeRaw = ""
            }
        }
    }
    
    /// Get UIUserInterfaceStyle for UIKit components (nil means use system default)
    var preferredUserInterfaceStyle: UIUserInterfaceStyle? {
        get {
            switch colorSchemeRaw.lowercased() {
            case "light": return .light
            case "dark": return .dark
            default: return nil // System default
            }
        }
        set {
            switch newValue {
            case .light: colorSchemeRaw = "light"
            case .dark: colorSchemeRaw = "dark"
            case nil: colorSchemeRaw = ""
            @unknown default: colorSchemeRaw = ""
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Get enabled connection types based on user preferences
    var enabledConnectionTypes: [ConnectionType] {
        var types: [ConnectionType] = []
        if useWiFiAware { types.append(.wifiAware) }
        if useBluetooth { types.append(.bluetooth) }
        if useMultipeer { types.append(.multipeer) }
        if useAirDrop { types.append(.airDrop) }
        return types
    }
    
    /// Check if a specific connection type is enabled
    func isConnectionTypeEnabled(_ type: ConnectionType) -> Bool {
        switch type {
        case .wifiAware: return useWiFiAware
        case .bluetooth: return useBluetooth
        case .multipeer: return useMultipeer
        case .airDrop: return useAirDrop
        }
    }
    
    /// Get transport priority order (for fallback)
    func getTransportPriorityOrder() -> [ConnectionType] {
        var order: [ConnectionType] = []
        
        // Wi-Fi Aware is fastest, prioritize it
        if useWiFiAware { order.append(.wifiAware) }
        
        // Multipeer is reliable and fast
        if useMultipeer { order.append(.multipeer) }
        
        // Bluetooth is slower but widely available
        if useBluetooth { order.append(.bluetooth) }
        
        // AirDrop is Apple-only but very reliable
        if useAirDrop { order.append(.airDrop) }
        
        return order
    }
    
    func exportSettings() -> [String: Any] {
        return [
            "transport": [
                "wifiAware": useWiFiAware,
                "bluetooth": useBluetooth,
                "multipeer": useMultipeer,
                "airdrop": useAirDrop
            ],
            "airdrop": [
                "useCustomDiscovery": useCustomAirDropDiscovery
            ],
            "transfer": [
                "autoAccept": autoAcceptTransfers,
                "overwriteExisting": overwriteExisting,
                "chunkSize": preferredChunkSize,
                "trustedDevices": trustedDevices
            ],
            "wifiAware": [
                "ackBatchSize": ackBatchSize,
                "slidingWindowSize": slidingWindowSize,
                "handshakeTimeoutSeconds": handshakeTimeoutSeconds,
                "receiveTimeoutSeconds": receiveTimeoutSeconds
            ],
            "benchmark": [
                "enabled": benchmarkEnabled
            ],
            "debug": [
                "mockDevices": enableMockDevices,
                "logLevel": logLevel
            ],
            "capability": [
                "androidEnabled": androidDevicesEnabled
            ],
            "privacy": [
                "deviceName": deviceName,
                "selectedAvatar": selectedAvatarIndex
            ],
            "permissions": [
                "showInstructions": showPermissionInstructions,
                "instructionsShownCount": permissionInstructionsShownCount
            ],
            "ui": [
                "preferNativeAirDrop": preferNativeAirDrop,
                "showQuickShareTutorial": showQuickShareTutorial
            ]
        ]
    }
    
    /// Import settings from dictionary
    func importSettings(from dict: [String: Any]) {
        if let transport = dict["transport"] as? [String: Any] {
            useWiFiAware = transport["wifiAware"] as? Bool ?? true
            useBluetooth = transport["bluetooth"] as? Bool ?? true
            useMultipeer = transport["multipeer"] as? Bool ?? true
            useAirDrop = transport["airdrop"] as? Bool ?? true
        }
        
        if let airdrop = dict["airdrop"] as? [String: Any] {
            useCustomAirDropDiscovery = airdrop["useCustomDiscovery"] as? Bool ?? true
        }
        
        if let transfer = dict["transfer"] as? [String: Any] {
            autoAcceptTransfers = transfer["autoAccept"] as? Bool ?? false
            overwriteExisting = transfer["overwriteExisting"] as? Bool ?? false
            preferredChunkSize = transfer["chunkSize"] as? Int ?? 12288
            if let trusted = transfer["trustedDevices"] as? [String] { trustedDevices = trusted }
        }
        
        if let wifiAware = dict["wifiAware"] as? [String: Any] {
            ackBatchSize = wifiAware["ackBatchSize"] as? Int ?? 5
            slidingWindowSize = wifiAware["slidingWindowSize"] as? Int ?? 10
            handshakeTimeoutSeconds = wifiAware["handshakeTimeoutSeconds"] as? Double ?? 3.0
            receiveTimeoutSeconds = wifiAware["receiveTimeoutSeconds"] as? Double ?? 60.0
        }
        
        if let benchmark = dict["benchmark"] as? [String: Any] {
            benchmarkEnabled = benchmark["enabled"] as? Bool ?? true
        }
        
        if let debug = dict["debug"] as? [String: Any] {
            enableMockDevices = debug["mockDevices"] as? Bool ?? false
            logLevel = debug["logLevel"] as? String ?? "info"
        }
        
        if let capability = dict["capability"] as? [String: Any] {
            androidDevicesEnabled = capability["androidEnabled"] as? Bool ?? true
        }
        
        if let privacy = dict["privacy"] as? [String: Any] {
            deviceName = privacy["deviceName"] as? String ?? UIDevice.current.name
            // Only import deviceId if it's not already set (to preserve existing device identity)
            if let importedDeviceId = privacy["deviceId"] as? String, !importedDeviceId.isEmpty, _deviceId.isEmpty {
                _deviceId = importedDeviceId
            }
        }
        
        if let permissions = dict["permissions"] as? [String: Any] {
            showPermissionInstructions = permissions["showInstructions"] as? Bool ?? true
            permissionInstructionsShownCount = permissions["instructionsShownCount"] as? Int ?? 0
        }
        
        if let ui = dict["ui"] as? [String: Any] {
            preferNativeAirDrop = ui["preferNativeAirDrop"] as? Bool ?? false
            showQuickShareTutorial = ui["showQuickShareTutorial"] as? Bool ?? true
        }
        
        validateChunkSize()
    }
    
    func validateChunkSize() {
        // Ensure chunk size is within reasonable bounds
        if preferredChunkSize < 1024 {
            preferredChunkSize = 1024 // Minimum 1KB
        } else if preferredChunkSize > 1024 * 1024 {
            preferredChunkSize = 1024 * 1024 // Maximum 1MB
        }
    }
}

// MARK: - Settings Keys (for direct UserDefaults access if needed)

extension SettingsService {
    enum Key {
        static let wifiAware = "transport.wifiAware"
        static let bluetooth = "transport.bluetooth"
        static let multipeer = "transport.multipeer"
        static let airDrop = "transport.airdrop"
        static let autoAccept = "transfer.autoAccept"
        static let overwriteExisting = "transfer.overwriteExisting"
        static let chunkSize = "transfer.chunkSize"
        static let trustedDevices = "transfer.trustedDevices"
        static let ackBatchSize = "wifiAware.ackBatchSize"
        static let slidingWindowSize = "wifiAware.slidingWindowSize"
        static let handshakeTimeoutSeconds = "wifiAware.handshakeTimeoutSeconds"
        static let receiveTimeoutSeconds = "wifiAware.receiveTimeoutSeconds"
        static let benchmarkEnabled = "benchmark.enabled"
        static let mockDevices = "debug.mockDevices"
        static let logLevel = "debug.logLevel"
        static let androidEnabled = "capability.androidEnabled"
        static let deviceName = "privacy.deviceName"
        static let deviceId = "privacy.deviceId"
    }
}

// MARK: - Trusted Devices helpers

extension SettingsService {
    var trustedDevices: [String] {
        get { trustedDevicesCSV.split(separator: ",").map { String($0) }.filter { !$0.isEmpty } }
        set { trustedDevicesCSV = newValue.joined(separator: ",") }
    }
    
    func isTrustedDevice(_ deviceId: String) -> Bool {
        return trustedDevices.contains(deviceId)
    }
    
    func addTrustedDevice(_ deviceId: String) {
        var set = Set(trustedDevices)
        set.insert(deviceId)
        trustedDevices = Array(set)
    }
    
    func removeTrustedDevice(_ deviceId: String) {
        var set = Set(trustedDevices)
        set.remove(deviceId)
        trustedDevices = Array(set)
    }
}
