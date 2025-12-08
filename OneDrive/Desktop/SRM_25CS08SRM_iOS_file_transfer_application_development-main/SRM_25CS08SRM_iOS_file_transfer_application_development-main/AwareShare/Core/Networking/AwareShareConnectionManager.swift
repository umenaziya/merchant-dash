import Foundation
import WiFiAware
import Network
import OSLog

// MARK: - Network Event with Connection Context

struct NetworkEventWithContext: Sendable {
    let event: NetworkEvent
    let connectionId: String
    let connection: WiFiAwareConnection
}

// MARK: - Custom Connection Manager

actor AwareShareConnectionManager: Sendable {
    private var connections: [WiFiAwareConnectionID: WiFiAwareConnection] = [:]
    private var connectionsInfo: [WiFiAwareConnectionID: ConnectionInfo] = [:]
    
    public let localEvents: AsyncStream<LocalEvent>
    private let localEventsContinuation: AsyncStream<LocalEvent>.Continuation
    
    public let networkEventsWithContext: AsyncStream<NetworkEventWithContext>
    private let networkEventsWithContextContinuation: AsyncStream<NetworkEventWithContext>.Continuation
    
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "AwareShareConnectionManager")
    
    init() {
        (self.localEvents, self.localEventsContinuation) = AsyncStream.makeStream(of: LocalEvent.self)
        (self.networkEventsWithContext, self.networkEventsWithContextContinuation) = AsyncStream.makeStream(of: NetworkEventWithContext.self)
    }
    
    // MARK: - Setup
    
    func add(_ connection: WiFiAwareConnection) {
        logger.info("Add connection: \(connection.debugDescription)")
        
        connectionsInfo[connection.id] = .init(
            receiverTask: setupReceiver(connection),
            stateUpdateTask: setupStateUpdateHandler(connection)
        )
    }
    
    func setupConnection(to endpoint: WAEndpoint) {
        let connection = NetworkConnection(
            to: endpoint,
            using: .parameters {
                Coder(receiving: NetworkEvent.self, sending: NetworkEvent.self, using: NetworkJSONCoder()) {
                    TCP()
                }
            }
            .wifiAware { $0.performanceMode = appPerformanceMode }
            .serviceClass(appServiceClass)
        )
        
        logger.info("Set up connection: \(connection.debugDescription)\nto: \(endpoint)")
        
        add(connection)
    }
    
    // MARK: - State Updates
    
    private func setupStateUpdateHandler(_ connection: WiFiAwareConnection) -> Task<Void, Error> {
        let (stream, continuation) = AsyncStream.makeStream(of: WiFiAwareConnectionState.self)
        
        connection.onStateUpdate { connection, state in
            self.logger.info("\(connection.debugDescription): \(String(describing: state))")
            continuation.yield((connection, state))
        }
        
        return Task {
            for await (connection, state) in stream {
                var connectionError: NWError? = nil
                
                switch state {
                case .setup, .waiting, .preparing: break
                    
                case .ready:
                    connections[connection.id] = connection
                    
                    if let wifiAwarePath = try await connection.currentPath?.wifiAware {
                        let connectedDevice = wifiAwarePath.endpoint.device
                        let performanceReport = wifiAwarePath.performance
                        
                        let detail = ConnectionDetail(connection: connection, performanceReport: performanceReport)
                        localEventsContinuation.yield(.connection(.ready(connectedDevice, detail)))
                        
                        connectionsInfo[connection.id]?.remoteDevice = connectedDevice
                    }
                    
                case .failed(let error):
                    stop(connection)
                    connectionError = error
                    fallthrough
                    
                case .cancelled:
                    guard let disconnectedDevice = connectionsInfo[connection.id]?.remoteDevice else { continue }
                    localEventsContinuation.yield(.connection(.stopped(disconnectedDevice, connection.id, connectionError?.wifiAware)))
                    
                @unknown default: break
                }
            }
        }
    }
    
    // MARK: - Receive
    
    private func setupReceiver(_ connection: WiFiAwareConnection) -> Task<Void, Error> {
        logger.info("Set up receiver: \(connection.debugDescription)")
        
        return Task {
            do {
                for try await (event, _) in connection.messages {
                    // Yield event with connection context
                    let eventWithContext = NetworkEventWithContext(
                        event: event,
                        connectionId: connection.id,
                        connection: connection
                    )
                    networkEventsWithContextContinuation.yield(eventWithContext)
                }
            } catch {
                logger.error("Receiver task failed for \(connection.debugDescription): \(error)")
                throw error
            }
        }
    }
    
    // MARK: - Send
    
    func send(_ event: NetworkEvent, to connection: WiFiAwareConnection) async {
        do {
            try await connection.send(event)
        } catch {
            logger.error("Failed to send to: \(connection.debugDescription): \(error)")
        }
    }
    
    func sendToAll(_ event: NetworkEvent) async {
        for connection in connections.values {
            await send(event, to: connection)
        }
    }
    
    func getConnection(byId id: WiFiAwareConnectionID) -> WiFiAwareConnection? {
        return connections[id]
    }
    
    func getAllConnections() -> [WiFiAwareConnection] {
        return Array(connections.values)
    }
    
    // MARK: - Monitor
    
    func monitor() async throws {
        for connection in connections.values.filter({ $0.state == .ready }) {
            if let wifiAwarePath = try await connection.currentPath?.wifiAware {
                let device = wifiAwarePath.endpoint.device
                let performanceReport = wifiAwarePath.performance
                
                let detail = ConnectionDetail(connection: connection, performanceReport: performanceReport)
                localEventsContinuation.yield(.connection(.performance(device, detail)))
            }
        }
    }
    
    // MARK: - Teardown
    
    private func cleanup(for id: WiFiAwareConnectionID) {
        // Cancel both tasks
        connectionsInfo[id]?.receiverTask.cancel()
        connectionsInfo[id]?.stateUpdateTask.cancel()
        
        // Remove from both dictionaries
        if let removedConnection = connections.removeValue(forKey: id) {
            logger.info("Removed connection: \(removedConnection.debugDescription)")
        }
        if let removedInfo = connectionsInfo.removeValue(forKey: id) {
            logger.info("Removed connection info for ID: \(id)")
        }
    }
    
    func stop(_ connection: WiFiAwareConnection) {
        logger.info("Stop connection: \(connection.debugDescription)")
        cleanup(for: connection.id)
    }
    
    func invalidate(_ id: WiFiAwareConnectionID) {
        logger.info("Invalidate connection ID: \(id)")
        cleanup(for: id)
    }
    
    deinit {
        for info in connectionsInfo.values {
            info.receiverTask.cancel()
            info.stateUpdateTask.cancel()
        }
        connections.removeAll()
        
        localEventsContinuation.finish()
        networkEventsWithContextContinuation.finish()
    }
}

// MARK: - Supporting Types

private struct ConnectionInfo {
    let receiverTask: Task<Void, Error>
    let stateUpdateTask: Task<Void, Error>
    var remoteDevice: WAPairedDevice?
}
