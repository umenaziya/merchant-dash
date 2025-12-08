
import SwiftUI
import Combine
import WiFiAware
import MultipeerConnectivity
import CoreBluetooth
import UIKit
import OSLog

// MARK: - App Flow Coordinator
@MainActor
class AppCoordinator: ObservableObject {
    private let appLogger = Logger(subsystem: "com.srmist.AwareShare", category: "AppCoordinator")
    @Published var currentScreen: AppScreen = .splash
    @Published var isTransitioning = false
    @Published var selectedDevice: DiscoveredDevice?
    @Published var transferMode: TransferMode?
    @Published var selectedTransports: [ConnectionType] = []
    @Published var hasPermissions = false
    @Published var showPermissionPopup = false
    
    // MARK: - Error State
    @Published var currentError: AppError?
    @Published var retryAction: (() -> Void)?
    
    // MARK: - Transfer State
    @Published var isTransferring = false
    @Published var transferProgress: [String: Double] = [:] // Multi-transfer progress
    @Published var activeTransfers: [String: TransferOperation] = [:] // Active transfer operations
    @Published var transferComplete = false
    @Published var selectedFiles: [SelectedFile] = []
    @Published var completedTransferIds: Set<String> = [] // Track completed transfers
    
    // MARK: - Multi-Device Selection State
    @Published var selectedDevices: [DiscoveredDevice] = []
    @Published var multiDeviceTransferMode: Bool = false
    
    // MARK: - Permission State
    @Published var permissionInstructionsShown: Bool = false
    @Published var lastPermissionCheckDate: Date?
    
    // MARK: - Services
    @Published var networkingManager = NetworkingManager()
    @Published var connectionStateManager = ConnectionStateManager()
    private let benchmarkService = BenchmarkService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Navigation Methods
    func showSplash() {
        navigate(to: .splash)
    }

    init() {
        networkingManager.delegate = self
        connectionStateManager.configure(with: networkingManager)
        setupObservers()
        setupPermissionRefresh()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe transfer progress from NetworkingManager
        networkingManager.$transferProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.transferProgress = progress
            }
            .store(in: &cancellables)
        
        // Observe active transfers from NetworkingManager
        networkingManager.$activeTransfers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transfers in
                self?.activeTransfers = transfers
            }
            .store(in: &cancellables)
        
        // Listen for all transfers complete notification
        NotificationCenter.default.publisher(for: .allTransfersComplete)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                // Handle all transfers complete
                self?.handleAllTransfersComplete(notification)
            }
            .store(in: &cancellables)
    }
    
    private func setupPermissionRefresh() {
        // Refresh permissions when app returns from background
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshPermissionStatus()
            }
            .store(in: &cancellables)
    }
    
    private func refreshPermissionStatus() {
        Task {
            let permissionsManager = PermissionsManager()
            await permissionsManager.refreshPermissionsStatus()
            lastPermissionCheckDate = Date()
            appLogger.info("Permissions refreshed after returning from background")
        }
    }
    
    func showStartTransfer() {
        // After splash screen, show permission popup first
        showPermissionPopup = true
    }
    
    func showTransfer2() {
        // Reset transfer state for new transfer
        resetTransferState()
        navigate(to: .transfer2)
    }
    
    private func resetTransferState() {
        isTransferring = false
        transferComplete = false
        selectedDevice = nil
        transferMode = nil
        selectedTransports.removeAll()
        completedTransferIds.removeAll()
        
        // Clean up temporary files before clearing selected files
        cleanupTemporaryFiles()
        
        // Don't clear connectionStatus directly - it's managed by ConnectionStateManager
        // Only disconnect from devices if no active transfers exist
        if activeTransfers.isEmpty {
            // Disconnect from all connected devices
            for connectedDevice in networkingManager.connectedDevices {
                Task {
                    await networkingManager.disconnectFromDevice(connectedDevice)
                }
            }
        }
        
        // Don't clear transferProgress and activeTransfers - they're managed by NetworkingManager
    }
    
    // MARK: - Transfer Management
    
    func getActiveTransfersList() -> [TransferOperation] {
        return Array(activeTransfers.values).sorted { $0.createdAt > $1.createdAt }
    }
    
    func getTransferMetrics(for transferId: String) -> TransferMetrics? {
        return benchmarkService.getMetrics(for: transferId)
    }
    
    func showSettings() {
        navigate(to: .settings)
    }
    
    func showHistory() {
        navigate(to: .history)
    }
    
    func showAirDrop() {
        navigate(to: .airDrop)
    }
    
    func showDeviceSelection(device: DiscoveredDevice) {
        selectedDevice = device
        
        // Use centralized connection requirement logic
        if requiresExplicitConnection(device.connectionType) {
            Task {
                await establishConnection(to: device)
            }
        } else {
            // For AirDrop and Multipeer, navigate directly to send/receive options
            showSendReceiveOptions()
        }
    }
    
    func requiresExplicitConnection(_ connectionType: ConnectionType) -> Bool {
        return connectionType == .wifiAware || connectionType == .bluetooth
    }
    
    func establishConnection(to device: DiscoveredDevice) async {
        do {
            connectionStateManager.markConnecting(deviceId: device.id)
            try await networkingManager.connectToDevice(device)
            appLogger.info("Connection established to \(device.name)")
        } catch {
            connectionStateManager.connectionStatus[device.id] = .error(error.localizedDescription)
            showError(.connectionFailed(transport: device.connectionType.rawValue, details: error.localizedDescription), retryAction: {
                Task {
                    await self.establishConnection(to: device)
                }
            })
        }
    }
    
    func showSendReceiveOptions() {
        navigate(to: .sendReceiveOptions)
    }
    
    func showTransportSelection() {
        navigate(to: .transportSelection)
    }
    
    func showFileSelection(mode: TransferMode) {
        transferMode = mode
        navigate(to: .fileSelection)
    }
    
    func getRecommendedTransports(for device: DiscoveredDevice) -> [ConnectionType] {
        let settingsService = SettingsService.shared
        var recommended: [ConnectionType] = []
        
        // Prioritize the device's current connection type
        recommended.append(device.connectionType)
        
        // Add other enabled transports in priority order
        let priorityOrder = settingsService.getTransportPriorityOrder()
        for transport in priorityOrder {
            if transport != device.connectionType && settingsService.isConnectionTypeEnabled(transport) {
                recommended.append(transport)
            }
        }
        
        return recommended
    }
    
    func showTransferProgress() {
        navigate(to: .transferProgress)
    }
    
    func showTransferComplete() {
        transferComplete = true
        navigate(to: .transferComplete)
    }
    
    func requestPermissions() {
        // This will be called from the permissions popup
        hasPermissions = true
        showPermissionPopup = false
        
        // Check if instructions should be shown
        let settingsService = SettingsService.shared
        if settingsService.showPermissionInstructions && !permissionInstructionsShown {
            settingsService.permissionInstructionsShownCount += 1
            permissionInstructionsShown = true
        }
        
        navigate(to: .transfer2)
    }
    
    // MARK: - Multi-Device Transfer Methods
    
    /// Toggle device selection for multi-device transfer
    func toggleDeviceSelection(_ device: DiscoveredDevice) {
        if self.selectedDevices.contains(where: { $0.id == device.id }) {
            self.selectedDevices.removeAll { $0.id == device.id }
        } else {
            self.selectedDevices.append(device)
        }
        appLogger.info("Selected devices count: \(self.selectedDevices.count)")
    }
    
    /// Clear all selected devices
    func clearDeviceSelection() {
        selectedDevices.removeAll()
        multiDeviceTransferMode = false
        appLogger.info("Cleared device selection")
    }
    
    /// Send file to all selected devices
    func sendToSelectedDevices(_ fileURL: URL) async {
        guard !selectedDevices.isEmpty else {
            appLogger.warning("No devices selected for multi-device transfer")
            return
        }
        
        appLogger.info("Starting multi-device transfer to \(self.selectedDevices.count) devices")
        
        // Connect to all devices first (if needed)
        var connectedDevices: [ConnectedDevice] = []
        
        for device in selectedDevices {
            do {
                if requiresExplicitConnection(device.connectionType) {
                    try await networkingManager.connectToDevice(device)
                }
                
                // Find connected device or create placeholder
                if let connected = networkingManager.connectedDevices.first(where: { $0.id == device.id }) {
                    connectedDevices.append(connected)
                }
            } catch {
                appLogger.error("Failed to connect to \(device.name): \(error)")
                showError(.connectionFailed(transport: device.connectionType.rawValue, details: error.localizedDescription))
            }
        }
        
        // Send file to all connected devices
        do {
            let transferIds = try await networkingManager.sendFileToMultipleDevices(fileURL, to: connectedDevices)
            appLogger.info("Initiated \(transferIds.count) transfers")
            
            // Show transfer progress screen
            showTransferProgress()
        } catch {
            appLogger.error("Multi-device transfer failed: \(error)")
            showError(.transferFailed(reason: error.localizedDescription))
        }
    }
    
    func showPermissionPopupModal() {
        showPermissionPopup = true
    }
    
    func dismissPermissionPopup() {
        showPermissionPopup = false
    }
    
    // MARK: - Error Handling
    
    func showError(_ error: AppError, retryAction: (() -> Void)? = nil) {
        currentError = error
        self.retryAction = retryAction
    }
    
    func dismissError() {
        currentError = nil
        retryAction = nil
    }

    
    private func handleAllTransfersComplete(_ notification: Notification) {
        appLogger.info("All transfers completed")
        
        // Clean up temporary files after transfer completion
        cleanupTemporaryFiles()
        
        // Navigate to completion screen
        showTransferComplete()
    }
    
    func cleanupTemporaryFiles() {
        appLogger.info("Cleaning up temporary files")
        
        // Clean up temporary files from selected files
        for selectedFile in selectedFiles {
            if let fileURL = selectedFile.url {
                // Only delete files in temporary directory or documents directory that we created
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let tempPath = FileManager.default.temporaryDirectory
                
                if fileURL.path.hasPrefix(documentsPath.path) || fileURL.path.hasPrefix(tempPath.path) {
                    do {
                        if FileManager.default.fileExists(atPath: fileURL.path) {
                            try FileManager.default.removeItem(at: fileURL)
                            appLogger.info("Cleaned up temporary file: \(fileURL.lastPathComponent)")
                        }
                    } catch {
                        appLogger.error("Failed to clean up temporary file \(fileURL.lastPathComponent): \(error)")
                    }
                }
            }
        }
        
        // Clear selected files after cleanup
        selectedFiles.removeAll()
    }
    
    // Public method for app lifecycle cleanup
    func cleanupOnAppTermination() {
        appLogger.info("App terminating - cleaning up temporary files")
        cleanupTemporaryFiles()
    }
    
    private func navigate(to screen: AppScreen) {
        withAnimation(.easeInOut(duration: 0.3)) {
            isTransitioning = true
            currentScreen = screen
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isTransitioning = false
        }
    }
}

// MARK: - App Screen Enum
enum AppScreen: CaseIterable {
    case splash
    case startTransfer
    case transfer2
    case settings
    case history
    case airDrop
    case deviceSelection
    case sendReceiveOptions
    case transportSelection
    case fileSelection
    case transferProgress
    case transferComplete
    case permissionPopup
    
    var title: String {
        switch self {
        case .splash: return "Splash"
        case .startTransfer: return "Start Transfer"
        case .transfer2: return "Device Discovery"
        case .settings: return "Settings"
        case .history: return "Transfer History"
        case .airDrop: return "AirDrop"
        case .deviceSelection: return "Device Selected"
        case .sendReceiveOptions: return "Send or Receive"
        case .transportSelection: return "Select Transport"
        case .fileSelection: return "Select Files"
        case .transferProgress: return "Transferring"
        case .transferComplete: return "Transfer Complete"
        case .permissionPopup: return "Permissions"
        }
    }
}

// MARK: - Supporting Models
enum TransferMode {
    case send
    case receive
}

struct DiscoveredDevice {
    let id: String
    let name: String
    let type: DeviceType
    let connectionType: ConnectionType
    let isAvailable: Bool
    let avatarIndex: Int? // Avatar index from remote device (0-5)
}

enum DeviceType {
    case iPhone
    case iPad
    case mac
    case android
    case unknown
}

enum ConnectionType: String, Codable, Hashable {
    case wifiAware = "wifiAware"
    case bluetooth = "bluetooth"
    case airDrop = "airDrop"
    case multipeer = "multipeer"
}

extension ConnectionType {
    /// Display name for UI labels. Single source of truth for connection type names.
    var displayName: String {
        switch self {
        case .wifiAware: return "Wi-Fi Aware"
        case .bluetooth: return "Bluetooth LE"
        case .airDrop: return "AirDrop"
        case .multipeer: return "Multipeer"
        }
    }
}

// MARK: - Main App View
struct AppCoordinatorView: View {
    @StateObject private var coordinator = AppCoordinator()
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Content based on current screen
            Group {
                switch coordinator.currentScreen {
                case .splash:
                    AnimatedSplashScreenView()
                        .environmentObject(coordinator)
                case .startTransfer:
                    Transfer2UIView()
                        .environmentObject(coordinator)
                case .transfer2:
                    Transfer2UIView()
                        .environmentObject(coordinator)
                case .settings:
                    EnhancedSettingsView()
                        .environmentObject(coordinator)
                case .history:
                    TransferHistoryView()
                        .environmentObject(coordinator)
                case .airDrop:
                    AirDropView()
                        .environmentObject(coordinator)
                case .deviceSelection:
                    // DeviceSelectionView not implemented - redirect to transport selection
                    TransportSelectionView()
                        .environmentObject(coordinator)
                case .sendReceiveOptions:
                    SendReceiveOptionsView()
                        .environmentObject(coordinator)
                case .transportSelection:
                    TransportSelectionView()
                        .environmentObject(coordinator)
                case .fileSelection:
                    FileSelectionView()
                        .environmentObject(coordinator)
                case .transferProgress:
                    TransferProgressView()
                        .environmentObject(coordinator)
                case .transferComplete:
                    TransferCompleteView()
                        .environmentObject(coordinator)
                case .permissionPopup:
                    PermissionWindowPopupView()
                        .environmentObject(coordinator)
                }
            }
            .opacity(coordinator.isTransitioning ? 0.7 : 1.0)
            .scaleEffect(coordinator.isTransitioning ? 0.95 : 1.0)
            
            // Permission popup overlay
            if coordinator.showPermissionPopup {
                PermissionWindowPopupView()
                    .environmentObject(coordinator)
                    .zIndex(1000)
            }
            
            // Error overlay
            if let error = coordinator.currentError {
                ErrorOverlayView(
                    error: error,
                    onRetry: coordinator.retryAction != nil ? {
                        coordinator.retryAction?()
                        coordinator.dismissError()
                    } : nil,
                    onDismiss: {
                        coordinator.dismissError()
                    }
                )
                .zIndex(2000)
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            coordinator.cleanupOnAppTermination()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // Clean up temporary files when app goes to background
            coordinator.cleanupTemporaryFiles()
        }
    }
}

// NetworkingManagerDelegate conformance is implemented in `Core/Networking/NetworkingIntegration.swift`

// MARK: - Supporting Types

// SelectedFile is defined in FileSelectionView.swift

// MARK: - Preview
#Preview {
    AppCoordinatorView()
}
