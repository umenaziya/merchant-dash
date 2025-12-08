

import Foundation
import MultipeerConnectivity
import Combine
import OSLog
import UIKit

// MARK: - Multipeer Manager

class MultipeerManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    weak var delegate: NetworkingManagerDelegate?
    
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "MultipeerManager")
    
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser
    
    private let serviceType = ServiceConfiguration.multipeerServiceType
    private var peerID: MCPeerID
    
    private var isDiscovering = false
    private var isAdvertising = false
    
    // Discovered peers tracking
    private var discoveredPeers: [String: MCPeerID] = [:]
    private var peerDiscoveryTimestamps: [String: Date] = [:]
    private var peerIdToDeviceId: [MCPeerID: String] = [:]
    private var peerAvatarIndex: [MCPeerID: Int] = [:] // Track avatar index per peer
    private let peerTimeoutInterval: TimeInterval = 60.0
    private var cleanupTask: Task<Void, Never>?
    
    // File transfer tracking
    private var fileTransferProgress: [String: Progress] = [:]
    private var receivedFiles: [String: URL] = [:]
    private var fileReceptionContinuations: [String: CheckedContinuation<URL, Error>] = [:]
    private var fileReceptionResumed: [String: Bool] = [:]
    private var fileTransferMonitoringTasks: [String: Task<Void, Never>] = [:]
    private var fileReceptionTimeouts: [String: Task<Void, Never>] = [:]
    
    // Serial queue for synchronizing access to fileReceptionResumed dictionary
    private let fileReceptionQueue = DispatchQueue(label: "com.srmist.AwareShare.MultipeerManager.fileReception")
    
    // MARK: - Initialization
    
    override init() {
        // Initialize peer ID before super.init() using device name from settings with fallback to system name
        let displayName = SettingsService.shared.deviceName.isEmpty ? UIDevice.current.name : SettingsService.shared.deviceName
        peerID = MCPeerID(displayName: displayName)
        
        // Initialize session
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        
        // Initialize advertiser with discovery info (device name and avatar)
        let discoveryInfo: [String: String] = [
            "deviceId": SettingsService.shared.deviceId,
            "deviceName": SettingsService.shared.deviceName,
            "avatarIndex": String(SettingsService.shared.selectedAvatarIndex)
        ]
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        
        // Initialize browser
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        
        super.init()
        
        // Set delegates
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
        
        // Listen for device name changes to update advertiser
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceNameChanged),
            name: NSNotification.Name("DeviceNameChanged"),
            object: nil
        )
    }
    
    @objc private func deviceNameChanged() {
        logger.info("Device name changed, recreating MultipeerConnectivity session and browser with updated peerID")
        logger.warning("This will disconnect all existing peers. Callers should handle restart or require app restart.")
        
        // Save current state
        let wasAdvertising = isAdvertising
        let wasDiscovering = isDiscovering
        
        // Stop advertising and browsing if active
        if isAdvertising {
            advertiser.stopAdvertisingPeer()
            isAdvertising = false
        }
        if isDiscovering {
            browser.stopBrowsingForPeers()
            isDiscovering = false
        }
        
        // Disconnect existing session (this will disconnect all peers)
        // Clear delegate first to prevent delegate callbacks during cleanup
        session.delegate = nil
        session.disconnect()
        
        // Create new peerID with updated device name
        let displayName = SettingsService.shared.deviceName.isEmpty ? UIDevice.current.name : SettingsService.shared.deviceName
        peerID = MCPeerID(displayName: displayName)
        
        // Create new session with updated peerID
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        // Create new browser with updated peerID
        browser.delegate = nil
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        
        // Create new advertiser with updated peerID and discovery info
        let discoveryInfo: [String: String] = [
            "deviceId": SettingsService.shared.deviceId,
            "deviceName": SettingsService.shared.deviceName,
            "avatarIndex": String(SettingsService.shared.selectedAvatarIndex)
        ]
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        advertiser.delegate = self
        
        // Restart advertising and browsing if they were active before
        if wasAdvertising {
            advertiser.startAdvertisingPeer()
            isAdvertising = true
        }
        if wasDiscovering {
            browser.startBrowsingForPeers()
            isDiscovering = true
        }
        
        logger.info("MultipeerConnectivity components recreated with new peerID: \(self.peerID.displayName)")
    }
    
    deinit {
        // Cancel cleanup task for safety
        cleanupTask?.cancel()
        
        // Cancel all file transfer monitoring tasks
        for (_, task) in fileTransferMonitoringTasks {
            task.cancel()
        }
        fileTransferMonitoringTasks.removeAll()
        
        // Cancel all file reception timeout tasks
        for (_, task) in fileReceptionTimeouts {
            task.cancel()
        }
        fileReceptionTimeouts.removeAll()
    }
    
    // MARK: - Discovery Methods
    
    func startDiscovery() async {
        logger.info("Starting MultipeerConnectivity discovery")
        
        isDiscovering = true
        
        // Start advertising
        advertiser.startAdvertisingPeer()
        isAdvertising = true
        
        // Start browsing
        browser.startBrowsingForPeers()
    }
    
    func stopDiscovery() async {
        logger.info("Stopping MultipeerConnectivity discovery")
        
        isDiscovering = false
        isAdvertising = false
        
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        
        // Cancel cleanup task
        cleanupTask?.cancel()
        cleanupTask = nil
    }
    
    // MARK: - Connection Methods
    
    func connectToDevice(_ device: DiscoveredDevice) async throws {
        logger.info("Connecting to Multipeer device: \(device.name)")
        
        // First check if already connected - match by device.id instead of device.name
        if let peer = session.connectedPeers.first(where: { peerIdToDeviceId[$0] == device.id }) {
            logger.info("Already connected to peer: \(device.name) (id: \(device.id))")
            return
        }
        
        // Look up the peer from discovered peers dictionary
        guard let peer = discoveredPeers[device.id] else {
            logger.error("Peer not found in discovered peers for device: \(device.id)")
            throw MultipeerError.peerNotFound
        }
        
        // Invite the peer
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }
    
    /// Disconnects from the specified device.
    /// 
    /// **Important**: MultipeerConnectivity uses a single `MCSession` for all peers.
    /// Calling `session.disconnect()` will disconnect ALL connected peers, not just the specified device.
    /// This is a limitation of the MultipeerConnectivity framework when using a single session.
    /// 
    /// To support multiple simultaneous connections with selective disconnection,
    /// the architecture would need to be redesigned to maintain one session per peer.
    func disconnectFromDevice(_ device: ConnectedDevice) async {
        logger.info("Disconnecting from Multipeer device: \(device.name)")
        logger.warning("Note: This will disconnect all peers in the session due to MultipeerConnectivity limitations")
        
        // Find and disconnect the peer (this will disconnect all peers) - match by device.id instead of device.name
        if session.connectedPeers.first(where: { peerIdToDeviceId[$0] == device.id }) != nil {
            session.disconnect()
        }
    }
    
    // MARK: - File Transfer Methods
    
    func sendFile(_ fileURL: URL, to device: ConnectedDevice, transferId: String) async throws {
        logger.info("Sending file via MultipeerConnectivity: \(fileURL.lastPathComponent)")
        
        // Find the peer - match by device.id instead of device.name
        guard let peer = session.connectedPeers.first(where: { peerIdToDeviceId[$0] == device.id }) else {
            throw MultipeerError.peerNotConnected
        }
        
        // Send file using MultipeerConnectivity
        // Use continuation to properly handle async completion and errors
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.sendResource(at: fileURL, withName: fileURL.lastPathComponent, toPeer: peer) { [weak self] error in
                if let error = error {
                    self?.logger.error("Error sending file: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    self?.logger.info("File sent successfully")
                    continuation.resume()
                }
            }
        }
    }
    
    func receiveFile(from device: ConnectedDevice, transferId: String) async throws -> URL {
        logger.info("Receiving file via MultipeerConnectivity from: \(device.name)")
        
        // File reception is handled by the session delegate
        // This method sets up the reception and waits for completion
        return try await withCheckedThrowingContinuation { continuation in
            // Store continuation for when file is received
            fileReceptionContinuations[transferId] = continuation
            initializeFileReceptionResumed(transferId)
            
            // Set timeout for file reception
            let timeoutTask = Task<Void, Never> {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds timeout
                
                // Explicitly check if task was cancelled before executing timeout logic
                guard !Task.isCancelled else { return }
                
                // Atomically check and mark as resumed if not already resumed
                guard self.markFileReceptionResumedIfNotAlready(transferId) else { return }
                
                // Clean up continuation
                if let storedContinuation = self.fileReceptionContinuations.removeValue(forKey: transferId) {
                    storedContinuation.resume(throwing: MultipeerError.transferTimeout)
                }
                // Clean up timeout task reference
                self.fileReceptionTimeouts.removeValue(forKey: transferId)
            }
            
            // Store timeout task so it can be cancelled on successful completion
            fileReceptionTimeouts[transferId] = timeoutTask
        }
    }

    private func markFileReceptionResumedIfNotAlready(_ transferId: String) -> Bool {
        return fileReceptionQueue.sync {
            if fileReceptionResumed[transferId] == false {
                fileReceptionResumed[transferId] = true
                return true
            }
            return false
        }
    }
    
    /// Atomically initializes the file reception resumed flag for a given transfer ID.
    /// This method ensures thread-safe access to fileReceptionResumed dictionary.
    private func initializeFileReceptionResumed(_ transferId: String) {
        fileReceptionQueue.sync {
            fileReceptionResumed[transferId] = false
        }
    }
    
    /// Atomically checks if the file reception continuation has been resumed for a given transfer ID.
    /// This method ensures thread-safe read access to fileReceptionResumed dictionary.
    private func isFileReceptionResumed(_ transferId: String) -> Bool {
        return fileReceptionQueue.sync {
            return fileReceptionResumed[transferId] == true
        }
    }
}

// MARK: - MCSessionDelegate

extension MultipeerManager: MCSessionDelegate {
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        logger.info("Peer \(peerID.displayName) changed state to: \(state.rawValue)")
        
        switch state {
        case .connected:
            // Remove from discovered peers when connection succeeds
            // Use reverse map to get exact deviceId, fallback to displayName if no mapping exists
            let deviceId = peerIdToDeviceId[peerID] ?? peerID.displayName
            let avatarIndex = peerAvatarIndex[peerID]
            discoveredPeers.removeValue(forKey: deviceId)
            peerDiscoveryTimestamps.removeValue(forKey: deviceId)
            // Keep peerIdToDeviceId and peerAvatarIndex mappings for later lookups by device.id
            
            let device = ConnectedDevice(
                id: deviceId,
                name: peerID.displayName,
                type: .unknown,
                connectionType: .multipeer,
                isAvailable: true,
                connection: peerID,
                avatarIndex: avatarIndex
            )
            
            delegate?.didConnectToDevice(device)
            
        case .connecting:
            logger.info("Connecting to peer: \(peerID.displayName)")
            
        case .notConnected:
            // Use reverse map to get exact deviceId, fallback to displayName if no mapping exists
            let deviceId = peerIdToDeviceId[peerID] ?? peerID.displayName
            let avatarIndex = peerAvatarIndex[peerID]
            // Keep mappings in case peer reconnects
            
            let device = ConnectedDevice(
                id: deviceId,
                name: peerID.displayName,
                type: .unknown,
                connectionType: .multipeer,
                isAvailable: false,
                connection: peerID,
                avatarIndex: avatarIndex
            )
            
            delegate?.didDisconnectFromDevice(device)
            
        @unknown default:
            logger.info("Unknown session state for peer: \(peerID.displayName)")
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        logger.info("Received data from peer: \(peerID.displayName)")
        
        // Handle received data
        handleReceivedData(data, from: peerID)
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        logger.info("Received stream from peer: \(peerID.displayName)")
        
        // Handle received stream
        handleReceivedStream(stream, name: streamName, from: peerID)
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        logger.info("Started receiving resource: \(resourceName) from peer: \(peerID.displayName)")
        
        // Parse transferId from resource name (format: "<transferId>::<fileName>")
        let transferId: String
        if resourceName.contains("::"), let parsedId = resourceName.components(separatedBy: "::").first, !parsedId.isEmpty {
            transferId = parsedId
        } else {
            // Fallback: generate new transferId if format is incorrect
            transferId = UUID().uuidString
            logger.warning("Resource name does not contain transferId in expected format: \(resourceName)")
        }
        
        // Track file transfer progress
        fileTransferProgress[transferId] = progress
        
        // Monitor progress with proper lifecycle management
        let monitoringTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled && !progress.isFinished {
                await MainActor.run {
                    self.delegate?.didUpdateTransferProgress(progress.fractionCompleted, for: transferId)
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
        
        // Store monitoring task for later cleanup (mirrors sendFile pattern)
        fileTransferMonitoringTasks[transferId] = monitoringTask
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Parse transferId from resource name (format: "<transferId>::<fileName>")
        let transferId: String
        let fileName: String
        if resourceName.contains("::") {
            let components = resourceName.components(separatedBy: "::")
            if components.count >= 2, let parsedId = components.first, !parsedId.isEmpty {
                transferId = parsedId
                fileName = components.dropFirst().joined(separator: "::") // Rejoin in case fileName contains "::"
            } else {
                // Fallback: use resourceName as fileName and try to find continuation by fileName
                transferId = UUID().uuidString
                fileName = resourceName
                logger.warning("Resource name does not contain transferId in expected format: \(resourceName)")
            }
        } else {
            // Fallback: use resourceName as fileName and try to find continuation by fileName
            transferId = UUID().uuidString
            fileName = resourceName
            logger.warning("Resource name does not contain transferId in expected format: \(resourceName)")
        }
        
        if let error = error {
            logger.error("Failed to receive resource: \(resourceName) from peer: \(peerID.displayName), error: \(error)")
            
            // Cancel and remove timeout task before resuming continuation
            if let timeoutTask = fileReceptionTimeouts.removeValue(forKey: transferId) {
                timeoutTask.cancel()
            }
            
            // Atomically check and mark as resumed if not already resumed
            guard markFileReceptionResumedIfNotAlready(transferId) else {
                logger.warning("Continuation already resumed for transfer: \(transferId)")
                return
            }
            
            // Resume the matching continuation with error
            if let continuation = fileReceptionContinuations.removeValue(forKey: transferId) {
                continuation.resume(throwing: error)
            }
            
        } else {
            logger.info("Finished receiving resource: \(resourceName) from peer: \(peerID.displayName)")
            
            if let localURL = localURL {
                // Move file to documents directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsPath.appendingPathComponent(fileName)
                
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: localURL, to: destinationURL)
                    
                    // Notify delegate
                    let deviceId = peerIdToDeviceId[peerID] ?? peerID.displayName
                    let avatarIndex = peerAvatarIndex[peerID]
                    let device = ConnectedDevice(
                        id: deviceId,
                        name: peerID.displayName,
                        type: .unknown,
                        connectionType: .multipeer,
                        isAvailable: true,
                        connection: peerID,
                        avatarIndex: avatarIndex
                    )
                    
                    delegate?.didReceiveFile(destinationURL, from: device)
                    
                    // Cancel and remove timeout task before resuming continuation
                    if let timeoutTask = fileReceptionTimeouts.removeValue(forKey: transferId) {
                        timeoutTask.cancel()
                    }
                    
                    // Atomically check and mark as resumed if not already resumed
                    guard markFileReceptionResumedIfNotAlready(transferId) else {
                        logger.warning("Continuation already resumed for transfer: \(transferId)")
                        return
                    }
                    
                    // Resume the matching continuation with success
                    if let continuation = fileReceptionContinuations.removeValue(forKey: transferId) {
                        continuation.resume(returning: destinationURL)
                    }
                    
                } catch {
                    logger.error("Failed to move received file: \(error)")
                    
                    // Cancel and remove timeout task before resuming continuation
                    if let timeoutTask = fileReceptionTimeouts.removeValue(forKey: transferId) {
                        timeoutTask.cancel()
                    }
                    
                    // Atomically check and mark as resumed if not already resumed
                    guard markFileReceptionResumedIfNotAlready(transferId) else {
                        logger.warning("Continuation already resumed for transfer: \(transferId)")
                        return
                    }
                    
                    // Resume continuation with file move error
                    if let continuation = fileReceptionContinuations.removeValue(forKey: transferId) {
                        continuation.resume(throwing: error)
                    }
                }
            } else {
                // Cancel and remove timeout task before resuming continuation
                if let timeoutTask = fileReceptionTimeouts.removeValue(forKey: transferId) {
                    timeoutTask.cancel()
                }
                
                // Atomically check and mark as resumed if not already resumed
                guard markFileReceptionResumedIfNotAlready(transferId) else {
                    logger.warning("Continuation already resumed for transfer: \(transferId)")
                    return
                }
                
                // Resume continuation with missing file error
                if let continuation = fileReceptionContinuations.removeValue(forKey: transferId) {
                    continuation.resume(throwing: MultipeerError.fileNotReceived)
                }
            }
        }
        
        // Cancel and remove monitoring task
        if let monitoringTask = fileTransferMonitoringTasks.removeValue(forKey: transferId) {
            monitoringTask.cancel()
        }
        
        // Clean up progress tracking
        fileTransferProgress.removeValue(forKey: transferId)
    }
    
    // MARK: - Helper Methods
    
    private func handleReceivedData(_ data: Data, from peerID: MCPeerID) {
        // Handle received data messages
        // This could be used for small data transfers or control messages
    }
    
    private func handleReceivedStream(_ stream: InputStream, name: String, from peerID: MCPeerID) {
        // Handle received streams
        // This could be used for real-time data streaming
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    
  
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        logger.info("Received invitation from peer: \(peerID.displayName)")
        
        // Parse peer information on background thread
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else {
                invitationHandler(false, nil)
                return
            }
            
            // Extract device information from context or discovered peers
            var deviceId: String?
            var deviceName: String = peerID.displayName
            
            // Try to parse context data if available
            if let context = context {
                // Attempt to parse as JSON first
                if let contextData = try? JSONSerialization.jsonObject(with: context) as? [String: Any] {
                    deviceId = contextData["deviceId"] as? String
                    deviceName = contextData["deviceName"] as? String ?? peerID.displayName
                } else if let contextString = String(data: context, encoding: .utf8), !contextString.isEmpty {
                    // Fallback: treat as plain string deviceId if JSON parsing fails
                    deviceId = contextString
                }
            }
            
            // Fallback: Check if peer is in discovered peers (may have deviceId from discovery info)
            if deviceId == nil {
                // Find deviceId from peerIdToDeviceId reverse mapping
                deviceId = self.peerIdToDeviceId[peerID]
            }
            
            // Use peerID displayName as fallback identifier if no deviceId found
            let finalDeviceId = deviceId ?? peerID.displayName
            
            // Check if device is trusted
            let isTrusted = await MainActor.run {
                SettingsService.shared.isTrustedDevice(finalDeviceId)
            }
            
            if isTrusted {
                // Auto-accept trusted devices
                self.logger.info("Auto-accepting invitation from trusted device: \(deviceName) (id: \(finalDeviceId))")
                invitationHandler(true, self.session)
                return
            }
            
            // For untrusted devices, request user consent on main thread
            await MainActor.run {
                self.requestInvitationConsent(
                    peerID: peerID,
                    deviceId: finalDeviceId,
                    deviceName: deviceName,
                    invitationHandler: invitationHandler
                )
            }
        }
    }
    

    @MainActor
    private func requestInvitationConsent(
        peerID: MCPeerID,
        deviceId: String,
        deviceName: String,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        logger.info("Requesting user consent for invitation from: \(deviceName) (id: \(deviceId))")
        
        // Create consent alert
        let alert = UIAlertController(
            title: "Connection Request",
            message: "\(deviceName) wants to connect to your device.\n\nDo you want to accept this connection?",
            preferredStyle: .alert
        )
        
        // Reject action
        alert.addAction(UIAlertAction(title: "Reject", style: .cancel) { [weak self] _ in
            self?.logger.info("User rejected invitation from: \(deviceName)")
            invitationHandler(false, nil)
        })
        
        // Accept action
        alert.addAction(UIAlertAction(title: "Accept", style: .default) { [weak self] _ in
            self?.logger.info("User accepted invitation from: \(deviceName)")
            invitationHandler(true, self?.session)
        })
        
        // Accept and Trust action
        alert.addAction(UIAlertAction(title: "Accept & Trust", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.logger.info("User accepted and trusted invitation from: \(deviceName)")
            SettingsService.shared.addTrustedDevice(deviceId)
            invitationHandler(true, self.session)
        })
        
        // Present the alert on the topmost view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            var topController = rootViewController
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            topController.present(alert, animated: true)
        } else {
            // Fallback: if we can't present UI, reject for security
            logger.warning("Unable to present consent UI, rejecting invitation for security")
            invitationHandler(false, nil)
        }
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logger.error("Failed to start advertising: \(error)")
    }
    
    // MARK: - Peer Cleanup
    
    private func startPeerCleanupTask() {
        guard cleanupTask == nil else { return }
        
        cleanupTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // Check every 30 seconds
                
                let now = Date()
                let stalePeerIds = self.peerDiscoveryTimestamps.compactMap { (deviceId, timestamp) in
                    now.timeIntervalSince(timestamp) > self.peerTimeoutInterval ? deviceId : nil
                }
                
                for deviceId in stalePeerIds {
                    self.discoveredPeers.removeValue(forKey: deviceId)
                    self.peerDiscoveryTimestamps.removeValue(forKey: deviceId)
                    self.logger.info("Removed stale discovered peer: \(deviceId)")
                }
            }
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    
    @objc func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // This method is required by the protocol but we handle discovery differently
    }
    
    @objc func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logger.info("Lost peer: \(peerID.displayName)")
        
        // Find keys to remove by matching peerID value
        let keysToRemove = discoveredPeers.filter { $0.value == peerID }.map { $0.key }
        
        // Remove from discovered peers
        for key in keysToRemove {
            discoveredPeers.removeValue(forKey: key)
            peerDiscoveryTimestamps.removeValue(forKey: key)
        }
        
        // Remove from reverse map
        peerIdToDeviceId.removeValue(forKey: peerID)
        peerAvatarIndex.removeValue(forKey: peerID)
        
        // Remove any keys from peerDiscoveryTimestamps that no longer exist in discoveredPeers
        let existingKeys = Set(discoveredPeers.keys)
        let timestampKeysToRemove = peerDiscoveryTimestamps.keys.filter { !existingKeys.contains($0) }
        for key in timestampKeysToRemove {
            peerDiscoveryTimestamps.removeValue(forKey: key)
        }
    }
    
    @objc func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logger.error("Failed to start browsing: \(error)")
    }
}

// MARK: - Supporting Types

enum MultipeerError: Error, LocalizedError {
    case peerNotFound
    case peerNotConnected
    case sessionNotActive
    case fileTransferFailed
    case transferTimeout
    case fileNotReceived
    
    var errorDescription: String? {
        switch self {
        case .peerNotFound:
            return "Peer not found"
        case .peerNotConnected:
            return "Peer not connected"
        case .sessionNotActive:
            return "Session not active"
        case .fileTransferFailed:
            return "File transfer failed"
        case .transferTimeout:
            return "File transfer timed out"
        case .fileNotReceived:
            return "File was not received"
        }
    }
}

// MARK: - Extensions
