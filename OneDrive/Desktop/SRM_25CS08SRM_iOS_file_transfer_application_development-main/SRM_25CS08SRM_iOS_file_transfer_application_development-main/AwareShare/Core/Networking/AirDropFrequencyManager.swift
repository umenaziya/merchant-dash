import Foundation
import CoreBluetooth
import Combine
import OSLog

/// **CUSTOM BLE-BASED DISCOVERY FOR AWARESHARE-TO-AWARESHARE TRANSFERS**

@MainActor
class AirDropFrequencyManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var isDiscovering = false
    @Published var isAvailable = false
    
    // MARK: - Properties
    
    weak var delegate: NetworkingManagerDelegate?
    
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var discoveredDeviceIds: [UUID: String] = [:]
    
    /// Apple's proprietary AirDrop service UUID (for reference only, not used for discovery)
    /// Actual AirDrop uses closed protocols that are not accessible to third-party apps
    private let airDropServiceUUID = CBUUID(string: "7D18EEAD-0000-0000-0000-000000000000")
    
    /// **Custom service UUID for AwareShare device discovery**
    /// This UUID identifies AwareShare instances on the network
    /// Format: Standard 128-bit UUID
    /// Purpose: BLE advertisement and scanning for AwareShare-to-AwareShare discovery
    /// Must be consistent across all AwareShare installations for discovery to work
    private let awareShareServiceUUID = CBUUID(string: "A1B2C3D4-E5F6-4789-A012-3456789ABCDE")
    
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "AirDropFrequencyManager")
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        checkAvailability()
    }
    
    // MARK: - Availability Check
    
    private func checkAvailability() {
        // Check if Bluetooth is available
        let centralManager = CBCentralManager(delegate: nil, queue: nil)
        let state = centralManager.state
        
        isAvailable = state != .unsupported && state != .poweredOff
        
        if !isAvailable {
            logger.warning("Bluetooth is not available for AirDrop discovery")
        }
    }
    
    // MARK: - Discovery Methods
    
    func startDiscovery() async {
        guard isAvailable else {
            logger.error("Cannot start AirDrop discovery: Bluetooth not available")
            return
        }
        
        guard !isDiscovering else {
            logger.info("AirDrop discovery already in progress")
            return
        }
        
        logger.info("Starting AirDrop discovery via BLE")
        isDiscovering = true
        discoveredDevices.removeAll()
        
        // Initialize central manager for scanning
        centralManager = CBCentralManager(delegate: self, queue: .main)
        
        // Initialize peripheral manager for advertising
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
    }
    
    func stopDiscovery() async {
        guard isDiscovering else { return }
        
        logger.info("Stopping AirDrop discovery")
        isDiscovering = false
        
        centralManager?.stopScan()
        peripheralManager?.stopAdvertising()
        
        discoveredPeripherals.removeAll()
        discoveredDeviceIds.removeAll()
    }
    
    // MARK: - Connection Methods
    
    func connectToDevice(_ device: DiscoveredDevice) async throws -> ConnectedDevice {
        logger.info("Connecting to AirDrop device: \(device.name)")
        
        // AirDrop connection is handled by iOS automatically when using share sheet
        // This method prepares the device for connection
        
        guard let peripheralUUID = discoveredDeviceIds.first(where: { $0.value == device.id })?.key,
              let peripheral = discoveredPeripherals[peripheralUUID] else {
            throw AirDropError.deviceNotFound
        }
        
        // Attempt to connect to the peripheral
        if peripheral.state != .connected {
            centralManager?.connect(peripheral, options: nil)
            
            // Wait for connection with timeout
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    continuation.resume(throwing: AirDropError.connectionTimeout)
                }
                
                // Store continuation for connection callback
                // Note: In a real implementation, you'd store this in a dictionary keyed by peripheral UUID
                // For now, we'll use a simplified approach
                Task {
                    // Wait a bit for connection
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    timeoutTask.cancel()
                    continuation.resume()
                }
            }
        }
        
        // Create connected device
        // Note: AirDrop connection is handled by system, so we use a placeholder
        let connectedDevice = ConnectedDevice(
            id: device.id,
            name: device.name,
            type: device.type,
            connectionType: .airDrop,
            isAvailable: true,
            connection: Optional<Any>.none as Any,
            avatarIndex: device.avatarIndex
        )
        
        delegate?.didConnectToDevice(connectedDevice)
        return connectedDevice
    }
    
    // MARK: - Advertising Data
  
    private func createAdvertisingData() -> [String: Any] {
        let deviceName = SettingsService.shared.deviceName
        let avatarIndex = SettingsService.shared.selectedAvatarIndex
        
        // Encode avatar index into service data
        // Pack version (1 byte) + avatarIndex (1 byte) into a compact payload
        var serviceData = Data()
        serviceData.append(contentsOf: [0x01]) // Version 1
        serviceData.append(contentsOf: [UInt8(avatarIndex & 0xFF)]) // Avatar index (1 byte)
        
        // TODO: Add device capabilities (supported file types, max file size)
        // TODO: Add protocol version for backward compatibility
        
        return [
            CBAdvertisementDataServiceUUIDsKey: [awareShareServiceUUID],
            CBAdvertisementDataLocalNameKey: deviceName,
            CBAdvertisementDataServiceDataKey: [awareShareServiceUUID: serviceData]
        ]
    }
}

// MARK: - CBCentralManagerDelegate

extension AirDropFrequencyManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            logger.info("Bluetooth is powered on, starting scan")
            if isDiscovering {
                startScanning()
            }
        case .poweredOff:
            logger.warning("Bluetooth is powered off")
            isAvailable = false
            Task {
                await stopDiscovery()
            }
        case .unauthorized:
            logger.error("Bluetooth is unauthorized")
            isAvailable = false
        case .unsupported:
            logger.error("Bluetooth is unsupported")
            isAvailable = false
        case .resetting:
            logger.info("Bluetooth is resetting")
        case .unknown:
            logger.info("Bluetooth state is unknown")
        @unknown default:
            logger.warning("Unknown Bluetooth state: \(central.state.rawValue)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        // Check if this is an AirDrop-capable device
        guard let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID],
              serviceUUIDs.contains(awareShareServiceUUID) else {
            return
        }
        
        // Get device name from advertisement data
        let deviceName = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "Unknown Device"
        
        // Avoid duplicates
        if discoveredPeripherals[peripheral.identifier] != nil {
            return
        }
        
        logger.info("Discovered AirDrop device: \(deviceName) (RSSI: \(rssi))")
        
        discoveredPeripherals[peripheral.identifier] = peripheral
        
        // Create discovered device
        let deviceId = UUID().uuidString
        discoveredDeviceIds[peripheral.identifier] = deviceId
        
        // Extract avatar index from service data if available
        var avatarIndex: Int? = nil
        if let serviceDataDict = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
           let serviceData = serviceDataDict[awareShareServiceUUID],
           serviceData.count >= 2 {
            // Parse service data: [version: 1 byte, avatarIndex: 1 byte]
            let version = serviceData[0]
            if version == 0x01 && serviceData.count >= 2 {
                avatarIndex = Int(serviceData[1])
            }
        }
        
        let device = DiscoveredDevice(
            id: deviceId,
            name: deviceName,
            type: .iPhone, // Assume iPhone for AirDrop devices
            connectionType: .airDrop,
            isAvailable: true,
            avatarIndex: avatarIndex
        )
        
        discoveredDevices.append(device)
        delegate?.didDiscoverDevice(device)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Connected to peripheral: \(peripheral.identifier)")
        
        // AirDrop connection is established
        // The actual file transfer will use Wi-Fi Direct (AWDL)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("Failed to connect to peripheral: \(error?.localizedDescription ?? "Unknown error")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("Disconnected from peripheral: \(peripheral.identifier)")
        
        // Remove from discovered devices
        if let deviceId = discoveredDeviceIds[peripheral.identifier] {
            discoveredDevices.removeAll { $0.id == deviceId }
            discoveredDeviceIds.removeValue(forKey: peripheral.identifier)
        }
        discoveredPeripherals.removeValue(forKey: peripheral.identifier)
    }
    
    private func startScanning() {
        guard let centralManager = centralManager,
              centralManager.state == .poweredOn else {
            return
        }
        
        // Scan for AirDrop-capable devices
        centralManager.scanForPeripherals(
            withServices: [awareShareServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        logger.info("Started scanning for AirDrop devices")
    }
}

// MARK: - CBPeripheralManagerDelegate

extension AirDropFrequencyManager: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            logger.info("Peripheral manager is powered on, starting advertising")
            if isDiscovering {
                startAdvertising()
            }
        case .poweredOff:
            logger.warning("Peripheral manager is powered off")
        case .unauthorized:
            logger.error("Peripheral manager is unauthorized")
        case .unsupported:
            logger.error("Peripheral manager is unsupported")
        case .resetting:
            logger.info("Peripheral manager is resetting")
        case .unknown:
            logger.info("Peripheral manager state is unknown")
        @unknown default:
            logger.warning("Unknown peripheral manager state: \(peripheral.state.rawValue)")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            logger.error("Failed to start advertising: \(error.localizedDescription)")
        } else {
            logger.info("Started advertising AirDrop availability")
        }
    }
    
    private func startAdvertising() {
        guard let peripheralManager = peripheralManager,
              peripheralManager.state == .poweredOn else {
            return
        }
        
        // Create service
        let service = CBMutableService(type: awareShareServiceUUID, primary: true)
        
        // Add service to peripheral manager
        peripheralManager.add(service)
        
        // Start advertising
        peripheralManager.startAdvertising(createAdvertisingData())
    }
}

// MARK: - AirDrop Error Extensions

extension AirDropError {
    static let deviceNotFound = AirDropError.shareSheetFailed
    static let connectionTimeout = AirDropError.shareSheetFailed
}

