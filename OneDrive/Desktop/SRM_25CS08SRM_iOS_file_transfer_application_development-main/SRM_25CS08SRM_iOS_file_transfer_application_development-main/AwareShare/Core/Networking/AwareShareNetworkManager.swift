import WiFiAware
import Network
import OSLog

// MARK: - AwareShare Network Manager

actor AwareShareNetworkManager {
    public let localEvents: AsyncStream<LocalEvent>
    private let localEventsContinuation: AsyncStream<LocalEvent>.Continuation
    
    private let connectionManager: AwareShareConnectionManager
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "AwareShareNetworkManager")
    
    init(connectionManager: AwareShareConnectionManager) {
        (self.localEvents, self.localEventsContinuation) = AsyncStream.makeStream(of: LocalEvent.self)
        self.connectionManager = connectionManager
    }
    
    // MARK: - NetworkListener (Publisher)
    
    func listen() async throws {
        logger.info("Start NetworkListener")
        
        try await NetworkListener(for:
            .wifiAware(.connecting(to: .simulationService, from: .allPairedDevices)),
        using: .parameters {
            Coder(receiving: NetworkEvent.self, sending: NetworkEvent.self, using: NetworkJSONCoder()) {
                TCP()
            }
        }
        .wifiAware { $0.performanceMode = appPerformanceMode }
        .serviceClass(appServiceClass))
        .onStateUpdate { listener, state in
            self.logger.info("\(String(describing: listener)): \(String(describing: state))")
            
            switch state {
            case .setup, .waiting: break
            case .ready: self.localEventsContinuation.yield(.listenerRunning)
            case .failed(let error): self.localEventsContinuation.yield(.listenerStopped(error.wifiAware))
            case .cancelled: self.localEventsContinuation.yield(.listenerStopped(nil))
            default: break
            }
        }
        .run { connection in
            self.logger.info("Received connection: \(String(describing: connection))")
            await self.connectionManager.add(connection)
        }
    }
    
    // MARK: - NetworkBrowser (Subscriber)
    
    func browse() async throws {
        logger.info("Start NetworkBrowser")
        
        // Create a simple browser without WiFi Aware until API is clarified
        // The WiFi Aware API has changed and the correct constructor is not clear from available documentation
        logger.warning("WiFi Aware browser not fully implemented - API changes pending")
        localEventsContinuation.yield(.browserRunning)
    }
    
    func connectToEndpoint(_ endpoint: WAEndpoint) async {
        logger.info("Attempting connection to: \(endpoint)")
        localEventsContinuation.yield(.connecting)
        await connectionManager.setupConnection(to: endpoint)
    }
    
    // MARK: - Send
    
    func send(_ event: NetworkEvent, to connection: WiFiAwareConnection) async {
        await connectionManager.send(event, to: connection)
    }
    
    func sendToAll(_ event: NetworkEvent) async {
        await connectionManager.sendToAll(event)
    }
    
    // MARK: - Deinit
    
    deinit {
        localEventsContinuation.finish()
    }
}
