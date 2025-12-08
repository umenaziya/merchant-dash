//
//  MockNetworkingDelegate.swift
//  AwareShareTests
//
//  Created by AI Assistant
//

import Foundation
@testable import AwareShareApp

/// Mock implementation of NetworkingManagerDelegate for testing
@MainActor
class MockNetworkingDelegate: NetworkingManagerDelegate {
    
    // MARK: - Call Tracking
    
    var didDiscoverDeviceCalled = false
    var didConnectToDeviceCalled = false
    var didDisconnectFromDeviceCalled = false
    var didUpdateTransferProgressCalled = false
    var didReceiveFileCalled = false
    
    var discoveredDevices: [DiscoveredDevice] = []
    var connectedDevices: [ConnectedDevice] = []
    var disconnectedDevices: [ConnectedDevice] = []
    var progressUpdates: [(progress: Double, transferId: String)] = []
    var receivedFiles: [(fileURL: URL, device: ConnectedDevice)] = []
    
    // MARK: - NetworkingManagerDelegate Methods
    
    func didDiscoverDevice(_ device: DiscoveredDevice) {
        didDiscoverDeviceCalled = true
        discoveredDevices.append(device)
    }
    
    func didConnectToDevice(_ device: ConnectedDevice) {
        didConnectToDeviceCalled = true
        connectedDevices.append(device)
    }
    
    func didDisconnectFromDevice(_ device: ConnectedDevice) {
        didDisconnectFromDeviceCalled = true
        disconnectedDevices.append(device)
    }
    
    func didUpdateTransferProgress(_ progress: Double, for transferId: String) {
        didUpdateTransferProgressCalled = true
        progressUpdates.append((progress: progress, transferId: transferId))
    }
    
    func didReceiveFile(_ fileURL: URL, from device: ConnectedDevice) {
        didReceiveFileCalled = true
        receivedFiles.append((fileURL: fileURL, device: device))
    }
    
    // MARK: - Reset Method
    
    func reset() {
        didDiscoverDeviceCalled = false
        didConnectToDeviceCalled = false
        didDisconnectFromDeviceCalled = false
        didUpdateTransferProgressCalled = false
        didReceiveFileCalled = false
        
        discoveredDevices.removeAll()
        connectedDevices.removeAll()
        disconnectedDevices.removeAll()
        progressUpdates.removeAll()
        receivedFiles.removeAll()
    }
}

