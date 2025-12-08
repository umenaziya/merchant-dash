
import Foundation
import SwiftUI
import OSLog

// MARK: - Networking Integration

extension AppCoordinator: NetworkingManagerDelegate {
    
    func didDiscoverDevice(_ device: DiscoveredDevice) {
        networkingLogger.info("Discovered device: \(device.name)")
      
    }
    
    func didConnectToDevice(_ device: ConnectedDevice) {
        networkingLogger.info("Connected to device: \(device.name)")
        
        // ✅ FIXED: Remove storeConnection call - ConnectionStateManager now derives from NetworkingManager
        // Update selected device
        selectedDevice = DiscoveredDevice(
            id: device.id,
            name: device.name,
            type: device.type,
            connectionType: device.connectionType,
            isAvailable: device.isAvailable,
            avatarIndex: device.avatarIndex
        )
        
        // Navigate to send/receive options
        showSendReceiveOptions()
    }
    
    func didDisconnectFromDevice(_ device: ConnectedDevice) {
        networkingLogger.info("Disconnected from device: \(device.name)")
    
        if selectedDevice?.id == device.id {
            selectedDevice = nil
        }
    }
    
    func didUpdateTransferProgress(_ progress: Double, for transferId: String) {
        Task { @MainActor in
            // Merge per-transfer progress without overwriting the dictionary
            transferProgress[transferId] = progress
            
            // Mark this transfer as completed if it reaches 100%
            if progress >= 1.0 {
                completedTransferIds.insert(transferId)
            }
        }
    }
    
    func didReceiveFile(_ fileURL: URL, from device: ConnectedDevice) {
        networkingLogger.info("Received file: \(fileURL.lastPathComponent)")
        
        // Handle received file
        // Could show a notification or update UI
    }
}

// MARK: - Device Discovery Integration

extension AppCoordinator {
    
    func startDeviceDiscovery() async {
        await networkingManager.startDiscovery()
    }
    
    func stopDeviceDiscovery() async {
        await networkingManager.stopDiscovery()
    }
    
    func connectToSelectedDevice() async {
        guard let device = selectedDevice else { return }
        
        do {
            try await networkingManager.connectToDevice(device)
        } catch {
            networkingLogger.error("Failed to connect to device: \(error)")
        }
    }
}

// MARK: - File Transfer Integration

extension AppCoordinator {
    
    func sendSelectedFiles(to device: ConnectedDevice) async {
        guard transferMode != nil else { 
            networkingLogger.error("Transfer mode not set")
            showError(.transferFailed(reason: "Transfer mode not set"))
            return 
        }
        guard !selectedFiles.isEmpty else {
            networkingLogger.warning("No files selected for transfer")
            showError(.transferFailed(reason: "No files selected"))
            return
        }
        
        // Verify device is still connected
        guard connectionStateManager.isDeviceConnected(device.id) else {
            networkingLogger.error("Device \(device.name) is not connected")
            showError(.connectionFailed(transport: device.connectionType.rawValue, details: "Device disconnected"))
            return
        }
        
        networkingLogger.info("Sending \(self.selectedFiles.count) files to \(device.name)")
        
        // Check if user selected specific transports
        let useUserSelectedTransports = !selectedTransports.isEmpty
        if useUserSelectedTransports {
            networkingLogger.info("Using user-selected transports: \(self.selectedTransports.map { "\($0)" }.joined(separator: ", "))")
        } else {
            networkingLogger.info("Using automatic transport selection")
        }
        
        // Show transfer progress screen before starting
        showTransferProgress()
        
        // Send each selected file
        for selectedFile in selectedFiles {
            guard let fileURL = selectedFile.url else {
                networkingLogger.error("File URL is nil for: \(selectedFile.name)")
                continue
            }
            
            do {
                if useUserSelectedTransports {
                    // Use user-selected transports
                    try await networkingManager.sendFile(fileURL, to: device, using: selectedTransports)
                    networkingLogger.info("Successfully queued file \(selectedFile.name) with user-selected transports")
                } else {
                    // Use automatic transport selection
                    try await networkingManager.sendFile(fileURL, to: device)
                    networkingLogger.info("Successfully queued file \(selectedFile.name) with automatic transport selection")
                }
            } catch {
                networkingLogger.error("Failed to send file \(selectedFile.name): \(error)")
            }
        }
        
        networkingLogger.info("All files queued for transfer")
    }
    
    func receiveFiles(from device: ConnectedDevice) async {
        networkingLogger.info("Starting multi-file receive session from: \(device.name)")
        
        // Keep a loop awaiting successive files until cancelled or connection lost
        while connectionStateManager.isDeviceConnected(device.id) {
            do {
                let receivedFileURL = try await networkingManager.receiveFile(from: device)
                networkingLogger.info("Received file: \(receivedFileURL.lastPathComponent)")
                
                // Continue waiting for more files unless connection is lost
                // The completion navigation will be triggered by TransferQueueManager when all transfers are done
            } catch {
                networkingLogger.error("Failed to receive file: \(error)")
                
                // Check if device is still connected before showing error
                if connectionStateManager.isDeviceConnected(device.id) {
                    showError(.transferFailed(reason: "Failed to receive file: \(error.localizedDescription)"), retryAction: {
                        Task {
                            await self.receiveFiles(from: device)
                        }
                    })
                } else {
                    networkingLogger.info("Device disconnected, ending receive session")
                }
                break
            }
        }
        
        networkingLogger.info("Multi-file receive session ended for device: \(device.name)")
    }
}

// MARK: - AirDrop Integration

extension AppCoordinator {
    
    func presentAirDropShareSheet(for fileURLs: [URL]) {
        Task {
            await networkingManager.airDropManager.presentAirDropShareSheet(fileURLs: fileURLs)
        }
    }
    
    func handleReceivedAirDropFile(_ fileURL: URL) {
        networkingManager.airDropManager.handleReceivedFile(fileURL)
    }
}

// MARK: - Logger

private let networkingLogger = Logger(subsystem: "com.srmist.AwareShare", category: "NetworkingIntegration")
