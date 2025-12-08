import Foundation
import CoreBluetooth
import Network
import OSLog
import Combine

// MARK: - Connection Monitor

/// Monitors connection health and implements auto-reconnect logic
actor ConnectionMonitor: Sendable {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "ConnectionMonitor")
    
    // Connection tracking
    private var monitoredConnections: [String: MonitoredConnection] = [:]
    private var reconnectTasks: [String: Task<Void, Never>] = [:]
    
    // Configuration
    private let healthCheckInterval: TimeInterval = 30.0 // 30 seconds
    private let maxReconnectAttempts = 3
    private let reconnectDelay: TimeInterval = 5.0 // 5 seconds
    
    // MARK: - Connection Monitoring
    
    /// Start monitoring a connection
    func startMonitoring(connectionId: String, connection: Any, connectionType: ConnectionType) {
        logger.info("Starting connection monitoring for: \(connectionId)")
        
        let monitoredConnection = MonitoredConnection(
            id: connectionId,
            connection: connection,
            connectionType: connectionType,
            isHealthy: true,
            lastHealthCheck: Date(),
            reconnectAttempts: 0
        )
        
        monitoredConnections[connectionId] = monitoredConnection
        
        // Start health monitoring task
        startHealthMonitoring(for: connectionId)
    }
    
    /// Stop monitoring a connection
    func stopMonitoring(connectionId: String) {
        logger.info("Stopping connection monitoring for: \(connectionId)")
        
        // Cancel any ongoing reconnect tasks
        reconnectTasks[connectionId]?.cancel()
        reconnectTasks.removeValue(forKey: connectionId)
        
        // Remove from monitoring
        monitoredConnections.removeValue(forKey: connectionId)
    }
    
    /// Report connection health status
    func reportConnectionHealth(connectionId: String, isHealthy: Bool) {
        logger.debug("Connection health report for \(connectionId): \(isHealthy)")
        
        guard var connection = monitoredConnections[connectionId] else { return }
        
        connection.isHealthy = isHealthy
        connection.lastHealthCheck = Date()
        
        if !isHealthy {
            logger.warning("Connection \(connectionId) reported as unhealthy")
            handleUnhealthyConnection(connectionId: connectionId)
        } else {
            // Reset reconnect attempts on successful health check
            connection.reconnectAttempts = 0
        }
        
        monitoredConnections[connectionId] = connection
    }
    
    // MARK: - Health Monitoring
    
    private func startHealthMonitoring(for connectionId: String) {
        let task = Task {
            while monitoredConnections[connectionId] != nil {
                try? await Task.sleep(nanoseconds: UInt64(healthCheckInterval * 1_000_000_000))
                
                guard let connection = monitoredConnections[connectionId] else { break }
                
                // Check if connection is stale (no health updates)
                let timeSinceLastCheck = Date().timeIntervalSince(connection.lastHealthCheck)
                if timeSinceLastCheck > healthCheckInterval * 2 {
                    logger.warning("Connection \(connectionId) appears stale, marking as unhealthy")
                    await self.reportConnectionHealth(connectionId: connectionId, isHealthy: false)
                }
            }
        }
        
        reconnectTasks[connectionId] = task
    }
    
    private func handleUnhealthyConnection(connectionId: String) {
        guard var connection = monitoredConnections[connectionId] else { return }
        
        connection.reconnectAttempts += 1
        
        if connection.reconnectAttempts <= maxReconnectAttempts {
            logger.info("Attempting to reconnect \(connectionId) (attempt \(connection.reconnectAttempts)/\(self.maxReconnectAttempts))")
            scheduleReconnect(for: connectionId, connection: connection)
        } else {
            logger.error("Max reconnect attempts reached for \(connectionId), giving up")
            // Notify delegate of permanent failure
            notifyConnectionFailed(connectionId: connectionId)
        }
        
        monitoredConnections[connectionId] = connection
    }
    
    private func scheduleReconnect(for connectionId: String, connection: MonitoredConnection) {
        let task = Task {
            // Wait before attempting reconnect
            try? await Task.sleep(nanoseconds: UInt64(reconnectDelay * 1_000_000_000))
            
            // Attempt to reconnect based on connection type
            let success = await attemptReconnect(connectionId: connectionId, connectionType: connection.connectionType)
            
            if success {
                logger.info("Successfully reconnected \(connectionId)")
                // Reset reconnect attempts
                if var updatedConnection = monitoredConnections[connectionId] {
                    updatedConnection.reconnectAttempts = 0
                    updatedConnection.isHealthy = true
                    updatedConnection.lastHealthCheck = Date()
                    monitoredConnections[connectionId] = updatedConnection
                }
            } else {
                logger.warning("Reconnect attempt failed for \(connectionId)")
                // Will be handled by the next health check
            }
        }
        
        reconnectTasks[connectionId] = task
    }
    
    private func attemptReconnect(connectionId: String, connectionType: ConnectionType) async -> Bool {
        // This would integrate with the specific connection managers
        // For now, we'll return false to indicate manual intervention needed
        logger.info("Reconnect attempt for \(connectionId) via \(connectionType.rawValue)")
        
        // In a real implementation, this would:
        // 1. For BLE: Re-scan and connect to the peripheral
        // 2. For Wi-Fi Aware: Re-establish the connection
        // 3. For Multipeer: Re-invite the peer
        
        return false // Placeholder - would need integration with specific managers
    }
    
    private func notifyConnectionFailed(connectionId: String) {
        logger.error("Connection \(connectionId) has permanently failed")
        // In a real implementation, this would notify the delegate
        // and potentially trigger UI updates
    }
    
    // MARK: - Connection Status
    
    /// Get the health status of a connection
    func getConnectionHealth(connectionId: String) -> ConnectionHealth? {
        guard let connection = monitoredConnections[connectionId] else { return nil }
        
        return ConnectionHealth(
            isHealthy: connection.isHealthy,
            lastHealthCheck: connection.lastHealthCheck,
            reconnectAttempts: connection.reconnectAttempts
        )
    }
    
    /// Get all monitored connections
    func getAllMonitoredConnections() -> [String: ConnectionHealth] {
        return monitoredConnections.mapValues { connection in
            ConnectionHealth(
                isHealthy: connection.isHealthy,
                lastHealthCheck: connection.lastHealthCheck,
                reconnectAttempts: connection.reconnectAttempts
            )
        }
    }
}

// MARK: - Supporting Types

struct MonitoredConnection: Sendable {
    let id: String
    let connection: Any
    let connectionType: ConnectionType
    var isHealthy: Bool
    var lastHealthCheck: Date
    var reconnectAttempts: Int
}

struct ConnectionHealth: Sendable {
    let isHealthy: Bool
    let lastHealthCheck: Date
    let reconnectAttempts: Int
}

// MARK: - Connection Health Delegate

protocol ConnectionHealthDelegate: AnyObject {
    func connectionDidBecomeUnhealthy(_ connectionId: String)
    func connectionDidReconnect(_ connectionId: String)
    func connectionDidFailPermanently(_ connectionId: String)
}
