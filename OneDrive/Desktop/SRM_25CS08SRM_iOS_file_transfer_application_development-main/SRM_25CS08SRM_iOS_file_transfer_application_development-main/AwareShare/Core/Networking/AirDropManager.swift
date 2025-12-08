

import Foundation
import UIKit
import Combine
import OSLog
import CoreBluetooth

/// **HYBRID AIRDROP IMPLEMENTATION: CUSTOM DISCOVERY + NATIVE TRANSFER**

class AirDropManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    weak var delegate: NetworkingManagerDelegate?
    
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "AirDropManager")
    
    /// BLE-based device discovery manager
    /// Used for custom AwareShare-to-AwareShare device discovery
    /// Note: This is NOT native AirDrop discovery
    private let frequencyManager = AirDropFrequencyManager()
    
    // Published properties for discovered devices
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var isDiscovering = false
    
    /// Whether to use custom discovery mode
    /// Reads from SettingsService.shared.useCustomAirDropDiscovery
    var useCustomDiscovery: Bool {
        SettingsService.shared.useCustomAirDropDiscovery
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupFrequencyManager()
    }
    
    func setDelegate(_ delegate: NetworkingManagerDelegate?) {
        self.delegate = delegate
        frequencyManager.delegate = delegate
    }
    
    private func setupFrequencyManager() {
        // Observe discovered devices from frequency manager
        frequencyManager.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .assign(to: &$discoveredDevices)
        
        frequencyManager.$isDiscovering
            .receive(on: DispatchQueue.main)
            .assign(to: &$isDiscovering)
    }
    
    // MARK: - Discovery Methods
    
    /// Start custom BLE-based device discovery for AwareShare instances
    ///
    /// **Important**: This is NOT native AirDrop discovery
    /// - Discovers only other AwareShare app instances
    /// - Uses custom BLE service UUID for advertisement/scanning
    /// - Does not discover native AirDrop-enabled devices
    ///
    /// **Process**:
    /// 1. Advertises this device via BLE with custom service UUID
    /// 2. Scans for other devices advertising the same UUID
    /// 3. Builds list of discovered AwareShare devices
    /// 4. User can select device, then file transfer uses native share sheet
    func startDiscovery() async {
        // Only start discovery if custom discovery is enabled
        guard useCustomDiscovery else {
            logger.info("Custom discovery is disabled, skipping BLE discovery")
            return
        }
        
        logger.info("Starting custom BLE discovery for AwareShare devices (not native AirDrop discovery)")
        await frequencyManager.startDiscovery()
    }
    
    func stopDiscovery() async {
        logger.info("Stopping AirDrop discovery")
        await frequencyManager.stopDiscovery()
    }
    
    // MARK: - Connection Methods
    
    func connectToDevice(_ device: DiscoveredDevice) async throws -> ConnectedDevice {
        logger.info("Connecting to AirDrop device: \(device.name)")
        
        // Use frequency manager to establish BLE connection
        // The actual file transfer will use Wi-Fi Direct (AWDL) via system share sheet
        return try await frequencyManager.connectToDevice(device)
    }
    
    func disconnectFromDevice(_ device: ConnectedDevice) async {
        logger.info("Disconnecting from AirDrop device: \(device.name)")
        
        // AirDrop doesn't maintain persistent connections
        // Connection is closed after transfer completes
    }
    
    // MARK: - File Transfer Methods
    
    /// Send file using native iOS AirDrop via share sheet
    ///
    /// **Important**: File transfer uses native iOS mechanisms
    /// - Presents `UIActivityViewController` (system share sheet)
    /// - User selects recipient from iOS AirDrop UI
    /// - iOS handles all file transfer protocols
    /// - Works with ANY AirDrop-enabled device (not just AwareShare)
    ///
    /// The `device` parameter is used for logging/tracking only
    /// Actual recipient selection happens in the share sheet
    func sendFile(_ fileURL: URL, to device: ConnectedDevice, transferId: String) async throws {
        logger.info("Sending file via native AirDrop share sheet: \(fileURL.lastPathComponent)")
        
        // Validate file accessibility
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.error("File does not exist: \(fileURL.path)")
            throw AirDropError.fileNotAccessible
        }
        
        // Check file size (AirDrop has practical limits)
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let fileSize = fileAttributes[.size] as? Int64 {
                if fileSize > NetworkingConstants.AirDrop.maxFileSize {
                    logger.warning("File size (\(fileSize) bytes) exceeds recommended AirDrop limit")
                }
            }
        } catch {
            logger.warning("Could not determine file size: \(error)")
        }
        
        // Present native iOS AirDrop share sheet
        await presentAirDropShareSheet(fileURL: fileURL)
    }
    
    /// Receive file via AirDrop
    ///
    /// **Note**: AirDrop reception is handled entirely by iOS system
    /// - Files are received through app's document types configuration
    /// - App delegate handles incoming files via `application(_:open:options:)`
    /// - This method exists for protocol consistency but cannot be directly called
    func receiveFile(from device: ConnectedDevice, transferId: String) async throws -> URL {
        logger.info("Receiving file via AirDrop from: \(device.name)")
        
        // AirDrop file reception is handled by the system
        // Files are received through the app's document types
        // This method is here for consistency with other transport protocols
        throw AirDropError.receptionNotSupported
    }
    
    // MARK: - AirDrop Share Sheet
    
    private func presentAirDropShareSheet(fileURL: URL) async {
        await MainActor.run {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                logger.error("Could not find root view controller for AirDrop share sheet")
                return
            }
            
            // Create activity items with proper error handling
            let activityItems: [Any] = [fileURL]
            
            let activityViewController = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )
            
            // Exclude activities that don't support AirDrop
            activityViewController.excludedActivityTypes = [
                .assignToContact,
                .addToReadingList,
                .postToFacebook,
                .postToTwitter,
                .postToWeibo,
                .print,
                .copyToPasteboard,
                .assignToContact,
                .saveToCameraRoll,
                .addToReadingList,
                .postToFlickr,
                .postToVimeo,
                .postToTencentWeibo,
                .postToFacebook
            ]
            
            // Configure for iPad
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, 
                                          y: rootViewController.view.bounds.midY, 
                                          width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            // Set completion handler with detailed logging
            activityViewController.completionWithItemsHandler = { [weak self] activityType, completed, returnedItems, error in
                if let error = error {
                    self?.logger.error("AirDrop share error: \(error)")
                } else if completed {
                    if let activityType = activityType {
                        self?.logger.info("File shared successfully via \(activityType.rawValue)")
                    } else {
                        self?.logger.info("File shared successfully via AirDrop")
                    }
                } else {
                    self?.logger.info("AirDrop share was cancelled by user")
                }
            }
            
            // Present the share sheet
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    // MARK: - File Reception Handling
    
    func handleReceivedFile(_ fileURL: URL) {
        logger.info("Received file via AirDrop: \(fileURL.lastPathComponent)")
        
        // Create a connected device for the sender
        let device = ConnectedDevice(
            id: UUID().uuidString,
            name: "AirDrop Sender",
            type: .unknown,
            connectionType: .airDrop,
            isAvailable: true,
            connection: fileURL,
            avatarIndex: nil
        )
        
        delegate?.didReceiveFile(fileURL, from: device)
    }
    
    // MARK: - Document Types Support
    
    static func configureDocumentTypes() -> [String: Any] {
        return [
            "CFBundleTypeName": "AwareShare Files",
            "CFBundleTypeRole": "Editor",
            "LSHandlerRank": "Owner",
            "CFBundleTypeIconFiles": [],
            "LSItemContentTypes": [
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
        ]
    }
}

// MARK: - AirDrop Error

enum AirDropError: Error, LocalizedError {
    case receptionNotSupported
    case shareSheetFailed
    case fileNotAccessible
    
    var errorDescription: String? {
        switch self {
        case .receptionNotSupported:
            return "AirDrop reception is handled by the system"
        case .shareSheetFailed:
            return "Failed to present AirDrop share sheet"
        case .fileNotAccessible:
            return "File is not accessible for sharing"
        }
    }
}

// MARK: - AirDrop Extensions

extension AirDropManager {
    
    /// Present AirDrop share sheet for multiple files
    func presentAirDropShareSheet(fileURLs: [URL]) async {
        await MainActor.run {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                logger.error("Could not find root view controller for AirDrop share sheet")
                return
            }
            
            let activityViewController = UIActivityViewController(
                activityItems: fileURLs,
                applicationActivities: nil
            )
            
            // Configure for iPad
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, 
                                          y: rootViewController.view.bounds.midY, 
                                          width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            // Set completion handler
            activityViewController.completionWithItemsHandler = { [weak self] activityType, completed, returnedItems, error in
                if let error = error {
                    self?.logger.error("AirDrop share error: \(error)")
                } else if completed {
                    self?.logger.info("Files shared successfully via AirDrop")
                }
            }
            
            // Present the share sheet
            rootViewController.present(activityViewController, animated: true)
        }
    }
    

    /// Check AirDrop availability using realistic checks
    /// - Returns: True if AirDrop should be available for use
    /// - Note: This checks device capabilities and settings, not actual AirDrop system state
    func isAirDropAvailable() -> Bool {
        #if targetEnvironment(simulator)
        // AirDrop is not available in the simulator
        logger.warning("AirDrop is not available in iOS Simulator")
        return false
        #else
        // Check if AirDrop is enabled in settings
        guard SettingsService.shared.useAirDrop else {
            logger.info("AirDrop is disabled in settings")
            return false
        }
        
        // Check Bluetooth authorization
        let bluetoothAuth = CBCentralManager.authorization
        if bluetoothAuth == .denied || bluetoothAuth == .restricted {
            logger.warning("Bluetooth authorization denied or restricted")
            return false
        }
        
        // AirDrop should be available
        return true
        #endif
    }
    
    /// Get structured availability status for AirDrop
    func getAvailabilityStatus() -> AirDropAvailabilityStatus {
        #if targetEnvironment(simulator)
        return .unavailable(reason: "Not available in iOS Simulator")
        #else
        if !SettingsService.shared.useAirDrop {
            return .unavailable(reason: "AirDrop is disabled in settings")
        }
        
        let bluetoothAuth = CBCentralManager.authorization
        if bluetoothAuth == .denied {
            return .unavailable(reason: "Bluetooth permission denied")
        }
        if bluetoothAuth == .restricted {
            return .unavailable(reason: "Bluetooth permission restricted")
        }
        
        return .available
        #endif
    }
    
    /// Get supported file types for AirDrop
    func getSupportedFileTypes() -> [String] {
        return NetworkingConstants.AirDrop.supportedFileTypes
    }
    
    /// Get AirDrop usage instructions for UI display
    func getUsageInstructions() -> AirDropUsageInfo {
        return AirDropUsageInfo(
            isAvailable: isAirDropAvailable(),
            requiresSystemShareSheet: true,
            maxFileSize: NetworkingConstants.AirDrop.maxFileSize,
            supportedFileTypes: getSupportedFileTypes(),
            instructions: [
                "Two modes available:",
                "  • Custom Discovery: Find AwareShare devices via Bluetooth",
                "  • Native AirDrop: Use iOS share sheet directly",
                "",
                "Custom Discovery Mode:",
                "  1. Start discovery to find AwareShare devices",
                "  2. Select device from list",
                "  3. Choose files to share",
                "  4. Transfer uses native iOS AirDrop",
                "",
                "Native AirDrop Mode:",
                "  1. Select files to share",
                "  2. iOS share sheet opens automatically",
                "  3. Choose recipient from AirDrop section",
                "  4. Works with any AirDrop-enabled device",
                "",
                "Tips:",
                "  • Enable AirDrop in Control Center",
                "  • Keep devices within 30 feet",
                "  • Bluetooth and Wi-Fi must be enabled"
            ]
        )
    }
}

// MARK: - AirDrop Usage Info

struct AirDropUsageInfo {
    let isAvailable: Bool
    let requiresSystemShareSheet: Bool
    let maxFileSize: Int64
    let supportedFileTypes: [String]
    let instructions: [String]
}

// MARK: - AirDrop Availability Status

enum AirDropAvailabilityStatus {
    case available
    case unavailable(reason: String)
    
    var isAvailable: Bool {
        switch self {
        case .available:
            return true
        case .unavailable:
            return false
        }
    }
}
