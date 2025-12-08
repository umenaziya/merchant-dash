

import Foundation

protocol WiFiAwareManagerProtocol: Actor {
    
    // MARK: - Delegate Management
    
    func setDelegate(_ delegate: NetworkingManagerDelegate?) async
    
    // MARK: - Discovery Methods
    
    /// Start discovering nearby Wi-Fi Aware devices
    func startDiscovery() async
    
    /// Stop discovering nearby devices
    func stopDiscovery() async
    
    /// Start publishing Wi-Fi Aware service
    func startPublishing() async throws
    
    // MARK: - Connection Methods
    
    /// Connect to a discovered device
    /// - Parameter device: The device to connect to
    func connectToDevice(_ device: DiscoveredDevice) async throws
    
    /// Disconnect from a connected device
    /// - Parameter device: The device to disconnect from
    func disconnectFromDevice(_ device: ConnectedDevice) async
    
    // MARK: - File Transfer Methods
    
    /// Send a file to a connected device
    /// - Parameters:
    ///   - fileURL: The URL of the file to send
    ///   - device: The destination device
    ///   - transferId: Unique identifier for this transfer
    func sendFile(_ fileURL: URL, to device: ConnectedDevice, transferId: String) async throws
    
    /// Receive a file from a connected device
    /// - Parameters:
    ///   - device: The source device
    ///   - transferId: Unique identifier for this transfer
    /// - Returns: The URL where the received file was saved
    func receiveFile(from device: ConnectedDevice, transferId: String) async throws -> URL
}

