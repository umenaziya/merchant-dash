//
//  MockWiFiAwareManager.swift
//  AwareShareTests
//
//  Created by AI Assistant
//

import Foundation
import WiFiAware
@testable import AwareShareApp

/// Mock implementation of WiFiAwareManagerProtocol for testing
@MainActor
class MockWiFiAwareManager: WiFiAwareManagerProtocol {
    
    // MARK: - Configurable Behavior
    
    var shouldThrowOnConnect: Bool = false
    var shouldThrowOnSendFile: Bool = false
    var shouldThrowOnReceiveFile: Bool = false
    var connectError: Error = NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock connection error"])
    var sendFileError: Error = NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock send file error"])
    var receiveFileError: Error = NSError(domain: "MockError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Mock receive file error"])
    
    // MARK: - Call Tracking
    
    var startDiscoveryCalled = false
    var stopDiscoveryCalled = false
    var connectToDeviceCalled = false
    var disconnectFromDeviceCalled = false
    var sendFileCalled = false
    var receiveFileCalled = false
    var resetCalled = false
    
    var lastConnectedDevice: DiscoveredDevice?
    var lastDisconnectedDevice: ConnectedDevice?
    var lastSentFileURL: URL?
    var lastSentDevice: ConnectedDevice?
    var lastSentTransferId: String?
    var lastReceiveDevice: ConnectedDevice?
    var lastReceiveTransferId: String?
    
    // MARK: - Temporary File Tracking
    
    var createdTempFiles: [URL] = []
    
    // MARK: - Delegate
    
    weak var delegate: NetworkingManagerDelegate?
    
    func setDelegate(_ delegate: NetworkingManagerDelegate) async {
        self.delegate = delegate
    }
    
    func setConsentDelegate(_ delegate: ConsentPrompting) async {
        // Mock implementation
    }
    
    // MARK: - Discovery Methods
    
    func startDiscovery() async {
        startDiscoveryCalled = true
    }
    
    func stopDiscovery() async {
        stopDiscoveryCalled = true
    }
    
    func startPublishing() async throws {
        // Mock implementation - can throw if needed
    }
    
    // MARK: - Connection Methods
    
    func connectToDevice(_ device: DiscoveredDevice) async throws {
        connectToDeviceCalled = true
        lastConnectedDevice = device
        
        if shouldThrowOnConnect {
            throw connectError
        }
    }
    
    func disconnectFromDevice(_ device: ConnectedDevice) async {
        disconnectFromDeviceCalled = true
        lastDisconnectedDevice = device
    }
    
    // MARK: - File Transfer Methods
    
    func sendFile(_ fileURL: URL, to device: ConnectedDevice, transferId: String) async throws {
        sendFileCalled = true
        lastSentFileURL = fileURL
        lastSentDevice = device
        lastSentTransferId = transferId
        
        if shouldThrowOnSendFile {
            throw sendFileError
        }
        
        // Check if file exists
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            throw NSError(domain: "MockError", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found"])
        }
    }
    
    func receiveFile(from device: ConnectedDevice, transferId: String) async throws -> URL {
        receiveFileCalled = true
        lastReceiveDevice = device
        lastReceiveTransferId = transferId
        
        if shouldThrowOnReceiveFile {
            throw receiveFileError
        }
        
        // Return a mock file URL with unique filename
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueFilename = "mock-received-file-\(UUID().uuidString).txt"
        let mockFileURL = tempDir.appendingPathComponent(uniqueFilename)
        
        // Create a mock file
        try "Mock received file content".write(to: mockFileURL, atomically: true, encoding: .utf8)
        
        // Track the created temporary file
        createdTempFiles.append(mockFileURL)
        
        return mockFileURL
    }
    
    // MARK: - Reset Method
    
    func reset() async {
        resetCalled = false
        startDiscoveryCalled = false
        stopDiscoveryCalled = false
        connectToDeviceCalled = false
        disconnectFromDeviceCalled = false
        sendFileCalled = false
        receiveFileCalled = false
        shouldThrowOnConnect = false
        shouldThrowOnSendFile = false
        shouldThrowOnReceiveFile = false
        lastConnectedDevice = nil
        lastDisconnectedDevice = nil
        lastSentFileURL = nil
        lastSentDevice = nil
        lastSentTransferId = nil
        lastReceiveDevice = nil
        lastReceiveTransferId = nil
        
        // Clean up temporary files
        for fileURL in createdTempFiles {
            try? FileManager.default.removeItem(at: fileURL)
        }
        createdTempFiles.removeAll()
    }
}

// MARK: - WiFiAwareManagerProtocol

/// Protocol that WiFiAwareManager should conform to for testability
protocol WiFiAwareManagerProtocol {
    func setDelegate(_ delegate: NetworkingManagerDelegate) async
    func setConsentDelegate(_ delegate: ConsentPrompting) async
    func startDiscovery() async
    func stopDiscovery() async
    func startPublishing() async throws
    func connectToDevice(_ device: DiscoveredDevice) async throws
    func disconnectFromDevice(_ device: ConnectedDevice) async
    func sendFile(_ fileURL: URL, to device: ConnectedDevice, transferId: String) async throws
    func receiveFile(from device: ConnectedDevice, transferId: String) async throws -> URL
}

