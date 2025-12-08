import Foundation
import Combine

@MainActor
class ConnectionStateManager: ObservableObject {
    @Published var connectionStatus: [String: ConnectionStatus] = [:]
    
    private var networkingManager: NetworkingManager?
    private var cancellables = Set<AnyCancellable>()
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    func configure(with networkingManager: NetworkingManager) {
        self.networkingManager = networkingManager
        
        // Subscribe to NetworkingManager's connectedDevices to derive connection status
        networkingManager.$connectedDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connectedDevices in
                self?.updateConnectionStatus(from: connectedDevices)
            }
            .store(in: &cancellables)
    }
    
    private func updateConnectionStatus(from connectedDevices: [ConnectedDevice]) {
        let priorStatus = connectionStatus
        let currentDeviceIds = Set(connectedDevices.map { $0.id })
        var newStatus = priorStatus

        // Transition previously connected devices to disconnected if they are no longer present
        for (deviceId, status) in priorStatus {
            if case .connected = status, !currentDeviceIds.contains(deviceId) {
                newStatus[deviceId] = .disconnected
            }
        }

        // Set all currently connected devices to connected status
        for deviceId in currentDeviceIds {
            newStatus[deviceId] = .connected
        }
        
        // Note: .connecting and .error states are preserved from the initial `priorStatus` copy
        // and are only overridden when a device becomes `.connected`.

        connectionStatus = newStatus
    }
    
    func markConnecting(deviceId: String) {
        connectionStatus[deviceId] = .connecting
    }
    
    internal func storeConnection(_ device: ConnectedDevice) {
        // ✅ FIXED: Only set derived status, no storage - NetworkingManager owns the data
        // This function is kept for internal use only - connection state is derived from NetworkingManager
        connectionStatus[device.id] = .connected
    }
    
    func getConnectedDevice(for discoveredDevice: DiscoveredDevice) -> ConnectedDevice? {
        // ✅ FIXED: Query NetworkingManager directly instead of local storage
        return networkingManager?.connectedDevices.first { $0.id == discoveredDevice.id }
    }
    
    internal func removeConnection(deviceId: String) {
        // ✅ FIXED: This function is kept for internal use only - connection state is derived from NetworkingManager
        // Manual removal is no longer needed as state is derived from NetworkingManager.$connectedDevices
        connectionStatus.removeValue(forKey: deviceId)
    }
    
    func isDeviceConnected(_ deviceId: String) -> Bool {
        // ✅ FIXED: Query NetworkingManager directly instead of local storage
        return networkingManager?.connectedDevices.contains { $0.id == deviceId } ?? false
    }
}
