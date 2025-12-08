

import SwiftUI
import Combine
import WiFiAware
import MultipeerConnectivity
import CoreBluetooth
import AVFoundation
import Photos
import NearbyInteraction
import Network
import os

@MainActor
class PermissionsManager: ObservableObject {
    @Published var wifiAwareSupported: Bool = false
    @Published var wifiAwarePermission: PermissionStatus = .notRequested
    @Published var bluetoothPermission: PermissionStatus = .notRequested
    @Published var localNetworkPermission: PermissionStatus = .notRequested
    @Published var photoLibraryPermission: PermissionStatus = .notRequested
    @Published var cameraPermission: PermissionStatus = .notRequested
    @Published var showPermissionModal = false
    
    // Retain CBCentralManager and delegate to prevent deallocation
    private var bluetoothManager: CBCentralManager?
    private var bluetoothDelegate: BluetoothPermissionDelegate?
    
    // Retain NISession and delegate for WiFi Aware permission checking
    private var niSession: NISession?
    private var niDelegate: NIPermissionDelegate?
    
    enum PermissionStatus {
        case notRequested
        case requesting
        case granted
        case denied
        case notApplicable // For capabilities that are not supported
    }
    
    // MARK: - Bluetooth Permission Delegate
    private class BluetoothPermissionDelegate: NSObject, CBCentralManagerDelegate {
        var continuation: CheckedContinuation<CBManagerAuthorization, Never>?
        private var hasResumed = false
        private let lock = OSAllocatedUnfairLock(initialState: ())
        weak var centralManager: CBCentralManager?
        
        func centralManagerDidUpdateState(_ central: CBCentralManager) {
            // Only check authorization, not state
            let auth = CBCentralManager.authorization
            
            // Acquire lock before checking/setting the flag
            let continuationToResume = lock.withLock {
                // Check if already resumed
                guard !hasResumed else {
                    return nil as CheckedContinuation<CBManagerAuthorization, Never>?
                }
                
                // Set flag and capture continuation into local variable
                hasResumed = true
                let cont = continuation
                
                // Set continuation = nil while still holding the lock
                continuation = nil
                
                return cont
            }
            
            // Call continuation.resume(returning:) outside the lock
            // This ensures resume happens only once and without holding the lock
            continuationToResume?.resume(returning: auth)
        }
        
        func reset() {
            lock.withLock {
                hasResumed = false
                continuation = nil
            }
        }
    }
    
    // MARK: - Nearby Interaction Permission Delegate
    private class NIPermissionDelegate: NSObject, NISessionDelegate {
        var continuation: CheckedContinuation<Bool, Never>?
        private var hasResumed = false
        private let lock = OSAllocatedUnfairLock(initialState: ())
        weak var session: NISession?
        
        func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
            // Session successfully activated - permission granted
            let continuationToResume = lock.withLock {
                guard !hasResumed else {
                    return nil as CheckedContinuation<Bool, Never>?
                }
                hasResumed = true
                let cont = continuation
                continuation = nil
                return cont
            }
            
            continuationToResume?.resume(returning: true)
        }
        
        func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
            // Removal reasons are not directly related to permission, but if we get here
            // it means the session was active, so permission is granted
            let continuationToResume = lock.withLock {
                guard !hasResumed else {
                    return nil as CheckedContinuation<Bool, Never>?
                }
                hasResumed = true
                let cont = continuation
                continuation = nil
                return cont
            }
            
            continuationToResume?.resume(returning: true)
        }
        
        func sessionWasSuspended(_ session: NISession) {
            // Suspension doesn't indicate permission denial, session was active
            let continuationToResume = lock.withLock {
                guard !hasResumed else {
                    return nil as CheckedContinuation<Bool, Never>?
                }
                hasResumed = true
                let cont = continuation
                continuation = nil
                return cont
            }
            
            continuationToResume?.resume(returning: true)
        }
        
        func reset() {
            lock.withLock {
                hasResumed = false
                continuation = nil
            }
        }
    }
    
    private func requestLocalNetworkPermission() async {
        localNetworkPermission = .requesting
        
        // Trigger Local Network permission using a Bonjour browse on app service type
        let browser = NWBrowser(for: .bonjour(type: "_awareshare._tcp", domain: nil), using: .tcp)
        let (stream, continuation) = AsyncStream<NWBrowser.State>.makeStream()
        
        browser.stateUpdateHandler = { state in
            continuation.yield(state)
        }
        
        browser.start(queue: .main)
        
        // Set a timeout to prevent infinite waiting - increased to 10 seconds for better reliability
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds timeout
            browser.cancel()
            continuation.finish()
            // On timeout, we cannot determine the permission status reliably
            if localNetworkPermission == .requesting {
                localNetworkPermission = .denied
            }
        }
        
        // Observe state changes; mark denied on explicit EACCES, otherwise grant permission
        for await state in stream {
            switch state {
            case .ready:
                // Browser is ready, permission is likely granted
                localNetworkPermission = .granted
                browser.cancel()
                continuation.finish()
                timeoutTask.cancel()
                return
            case .failed(let error):
                if case .posix(let code) = (error as NWError), code == .EACCES {
                    localNetworkPermission = .denied
                } else {
                    // Other errors are inconclusive
                    localNetworkPermission = .denied
                }
                browser.cancel()
                continuation.finish()
                timeoutTask.cancel()
                return
            case .cancelled:
                continuation.finish()
                timeoutTask.cancel()
                return
            default:
                break
            }
        }
        
        // Fallback: if status is still .requesting, mark as denied
        if localNetworkPermission == .requesting {
            localNetworkPermission = .denied
        }
        timeoutTask.cancel()
    }
    
    /// Ensures the Bluetooth manager is initialized with the given options
    /// Reuses existing manager if available
    /// If ShowPowerAlertKey is needed and manager doesn't have it, replaces the manager
    private func ensureBluetoothManager(options: [String: Any]? = nil) {
        if bluetoothManager == nil {
            // Always initialize with ShowPowerAlertKey to support system alerts
            // This doesn't hurt and allows us to trigger alerts when needed
            let finalOptions: [String: Any] = options ?? [CBCentralManagerOptionShowPowerAlertKey: true]
            let delegate = BluetoothPermissionDelegate()
            let manager = CBCentralManager(delegate: delegate, queue: .main, options: finalOptions)
            delegate.centralManager = manager
            self.bluetoothManager = manager
            self.bluetoothDelegate = delegate
        } else if let options = options, !options.isEmpty {
            // If we need specific options and manager exists without them,
            // we may need to replace it. However, since options can't be changed
            // after initialization, we'll reuse the existing manager.
            // ShowPowerAlertKey is already set by default, so this should be fine.
        }
    }
    
    /// Clears the Bluetooth manager when done with Bluetooth-related flows
    private func clearBluetoothManager() {
        bluetoothManager?.delegate = nil
        bluetoothManager = nil
        bluetoothDelegate = nil
    }
    
    /// Clears the NISession when done with WiFi Aware permission checking
    private func clearNISession() {
        niSession?.invalidate()
        niSession?.delegate = nil
        niSession = nil
        niDelegate = nil
    }
    
    func requestAllPermissions() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.requestWiFiAwarePermission() }
            group.addTask { await self.requestBluetoothPermission() }
            group.addTask { await self.requestLocalNetworkPermission() }
        }
    }
    
    private func requestWiFiAwarePermission() async {
        wifiAwarePermission = .requesting
        
        // Check capability first
        wifiAwareSupported = NISession.isSupported
        
        // Nearby Interaction support check and minimal activation to surface prompt if needed
        guard wifiAwareSupported else {
            // Device doesn't support Wi-Fi Aware - this is a capability issue, not a permission issue
            // Use .notApplicable so it doesn't block allPermissionsGranted
            wifiAwarePermission = .notApplicable
            return
        }
        
        // Create delegate and session
        let delegate = NIPermissionDelegate()
        let session = NISession()
        delegate.session = session
        session.delegate = delegate
        
        // Store references to prevent deallocation
        self.niSession = session
        self.niDelegate = delegate
        
        // Ensure cleanup happens even if an error occurs
        defer {
            clearNISession()
        }
        
        // Reset delegate state
        delegate.reset()
        
        // Configurable timeout (default 2 seconds)
        let timeoutNanoseconds: UInt64 = 2_000_000_000 // 2 seconds
        
        // Wait for delegate callback or timeout
        let permissionGranted: Bool = await withTaskGroup(of: Bool.self) { group in
            // Task 1: Wait for delegate callback
            group.addTask {
                await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                    delegate.continuation = continuation
                }
            }
            
            // Task 2: Timeout fallback
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return false // Timeout indicates we couldn't determine, treat as denied
            }
            
            // Return first result (either delegate callback or timeout)
            guard let result = await group.next() else {
                return false
            }
            
            // Cancel remaining task
            group.cancelAll()
            
            return result
        }
        
        // Update permission status based on result
        wifiAwarePermission = permissionGranted ? .granted : .denied
    }
    
    private func requestBluetoothPermission() async {
        bluetoothPermission = .requesting
        
        // Use system authorization API first
        let currentAuth = CBCentralManager.authorization
        switch currentAuth {
        case .allowedAlways:
            bluetoothPermission = .granted
            return
        case .restricted, .denied:
            bluetoothPermission = .denied
            return
        case .notDetermined:
            // Ensure manager is initialized to trigger the prompt
            ensureBluetoothManager()
            
            guard let delegate = bluetoothDelegate else {
                bluetoothPermission = .denied
                return
            }
            
            // Reset delegate state for new permission request
            delegate.reset()
            
            // Wait for authorization to be determined via delegate callback
            let auth = await withCheckedContinuation { (continuation: CheckedContinuation<CBManagerAuthorization, Never>) in
                delegate.continuation = continuation
            }
            
            // Map authorization to permission status
            switch auth {
            case .allowedAlways:
                bluetoothPermission = .granted
            case .restricted, .denied:
                bluetoothPermission = .denied
            case .notDetermined:
                // Should not happen after prompt, but handle gracefully
                bluetoothPermission = .denied
            @unknown default:
                bluetoothPermission = .denied
            }
            // Note: We keep the manager for potential reuse in other Bluetooth flows
        @unknown default:
            bluetoothPermission = .denied
        }
    }
    
    var allPermissionsGranted: Bool {
        // Wi-Fi Aware is optional - only required if supported
        let wifiAwareOk = !wifiAwareSupported || wifiAwarePermission == .granted || wifiAwarePermission == .notApplicable
        return wifiAwareOk && bluetoothPermission == .granted && localNetworkPermission == .granted
    }
    
    // MARK: - Photo Library Permission
    
    func requestPhotoLibraryPermission() async {
        photoLibraryPermission = .requesting
        
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            photoLibraryPermission = .granted
        case .denied, .restricted:
            photoLibraryPermission = .denied
        case .notDetermined:
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            switch status {
            case .authorized, .limited:
                photoLibraryPermission = .granted
            case .denied, .restricted:
                photoLibraryPermission = .denied
            @unknown default:
                photoLibraryPermission = .denied
            }
        @unknown default:
            photoLibraryPermission = .denied
        }
    }
    
    // MARK: - Camera Permission
    
    func requestCameraPermission() async {
        cameraPermission = .requesting
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraPermission = .granted
        case .denied, .restricted:
            cameraPermission = .denied
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermission = granted ? .granted : .denied
        @unknown default:
            cameraPermission = .denied
        }
    }
    
   
    func openWiFiSettings() {
        showWiFiInstructions()
    }
    

    func openBluetoothSettings() {
        // Ensure manager is initialized to check current state
        ensureBluetoothManager()
        
        guard let manager = bluetoothManager else {
            showBluetoothInstructions()
            return
        }
        
        let state = manager.state
        let currentAuth = CBCentralManager.authorization
        
        switch currentAuth {
        case .allowedAlways:
            // Bluetooth permission already granted
            if state == .poweredOff {
                // Bluetooth is powered off - trigger system alert with Settings button
                triggerBluetoothSystemAlert()
            } else if state == .poweredOn {
                // Bluetooth is on - show brief tip or do nothing
                // Optionally show instructions
                showBluetoothInstructions()
            } else {
                // Other states - show instructions
                showBluetoothInstructions()
            }
        case .denied, .restricted:
            // Permission denied - can only guide user to app settings
            showBluetoothDeniedAlert()
        case .notDetermined:
            // Trigger system Bluetooth alert with "Settings" button
            // This is the only Apple-sanctioned way to open Bluetooth settings
            triggerBluetoothSystemAlert()
        @unknown default:
            showBluetoothInstructions()
        }
    }
    
    /// Shows AirDrop instructions
    /// Note: No public API exists to directly open AirDrop settings on iOS 18+
    func openAirDropSettings() {
        showAirDropInstructions()
    }
    
    /// Opens app-specific settings page (only public API available)
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Helper Methods for Permission Guidance
    
    /// Show Wi-Fi enabling instructions
    private func showWiFiInstructions() {
        Task { @MainActor in
            let alert = UIAlertController(
                title: "Enable Wi-Fi",
                message: "To use Wi-Fi Aware, please enable Wi-Fi:\n\n1. Swipe down from top-right corner to open Control Center\n2. Tap the Wi-Fi icon to enable Wi-Fi\n\nAlternatively, go to Settings > Wi-Fi",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { [weak self] _ in
                self?.openAppSettings()
            })
            
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            
            presentAlert(alert)
        }
    }
    
    /// Show Bluetooth enabling instructions
    private func showBluetoothInstructions() {
        Task { @MainActor in
            let alert = UIAlertController(
                title: "Enable Bluetooth",
                message: "To discover nearby devices, please enable Bluetooth:\n\n1. Swipe down from top-right corner to open Control Center\n2. Tap the Bluetooth icon to enable Bluetooth\n\nAlternatively, go to Settings > Bluetooth",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            
            presentAlert(alert)
        }
    }
    
    /// Show Bluetooth denied alert
    private func showBluetoothDeniedAlert() {
        Task { @MainActor in
            let alert = UIAlertController(
                title: "Bluetooth Permission Required",
                message: "AwareShare needs Bluetooth permission to discover nearby devices. Please enable it in Settings > AwareShare > Bluetooth",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { [weak self] _ in
                self?.openAppSettings()
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            presentAlert(alert)
        }
    }
    
    /// Trigger iOS system Bluetooth alert with "Settings" button
    /// This is the only Apple-sanctioned way to guide users to Bluetooth settings
    private func triggerBluetoothSystemAlert() {
        // Ensure manager is initialized (it will have ShowPowerAlertKey by default)
        ensureBluetoothManager()
        
        guard let manager = bluetoothManager else {
            return
        }
        
        // System alert appears automatically if Bluetooth is off and ShowPowerAlertKey was set
        // The alert includes a "Settings" button that opens Bluetooth settings directly
        // Accessing the state property helps ensure the manager is fully initialized
        // and may trigger the alert if Bluetooth is powered off
        _ = manager.state
    }
    
    /// Show AirDrop enabling instructions
    private func showAirDropInstructions() {
        Task { @MainActor in
            let alert = UIAlertController(
                title: "Enable AirDrop",
                message: "To use AirDrop, please enable it:\n\n1. Swipe down from top-right corner to open Control Center\n2. Long-press the network card (top-left group)\n3. Tap AirDrop and select 'Everyone' or 'Contacts Only'\n\nAlternatively, go to Settings > General > AirDrop",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            
            presentAlert(alert)
        }
    }
    
    /// Helper to present alerts from any context
    private func presentAlert(_ alert: UIAlertController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        // Find top-most view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        topController.present(alert, animated: true)
    }
    
    /// Check permission status when app returns from background
    func refreshPermissionsStatus() async {
        await requestWiFiAwarePermission()
        await requestBluetoothPermission()
        await requestLocalNetworkPermission()
    }
}

// MARK: - Permission Modal View
struct PermissionModalView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var permissionsManager = PermissionsManager()
    @State private var showModal = true
    @State private var showSettingsAlert = false
    
    var body: some View {
        ZStack {
            if showModal {
                Color.black.opacity(0.6).ignoresSafeArea()
                    .onTapGesture {}
                
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                        Text("Permissions Required")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Enable services to start\ntransfer & receive files.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 32)
                    .padding(.horizontal, 24)
                    
                    VStack(spacing: 0) {
                        PermissionRow(title: "Wi‑Fi Aware", description: "Discover nearby devices", icon: "wifi", status: permissionsManager.wifiAwarePermission, isRecommended: true)
                        Divider().background(Color.gray.opacity(0.3))
                        PermissionRow(title: "Bluetooth", description: "Connect to nearby devices", icon: "antenna.radiowaves.left.and.right", status: permissionsManager.bluetoothPermission)
                        Divider().background(Color.gray.opacity(0.3))
                        PermissionRow(title: "Local Network", description: "Enable peer discovery on LAN", icon: "network", status: permissionsManager.localNetworkPermission)
                    }
                    
                    VStack(spacing: 16) {
                        Button(action: {
                            Task {
                                await permissionsManager.requestAllPermissions()
                                
                                // Wait for permissions with timeout
                                let startTime = Date()
                                let timeout: TimeInterval = 10.0
                                
                                while !permissionsManager.allPermissionsGranted {
                                    if Date().timeIntervalSince(startTime) > timeout {
                                        break
                                    }
                                    try? await Task.sleep(nanoseconds: 100_000_000)
                                }
                                
                                if !permissionsManager.allPermissionsGranted {
                                    showSettingsAlert = true
                                } else {
                                    withAnimation(.easeInOut(duration: 0.3)) { showModal = false }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        coordinator.requestPermissions()
                                    }
                                }
                            }
                        }) {
                            HStack {
                                if permissionsManager.wifiAwarePermission == .requesting || permissionsManager.bluetoothPermission == .requesting || permissionsManager.localNetworkPermission == .requesting {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                                    Text("Requesting Permissions...").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                                } else {
                                    Text("Enable All Services").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.04, green: 0.52, blue: 1.0), Color(red: 0.04, green: 0.68, blue: 0.94)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(16)
                        }
                        .disabled(permissionsManager.wifiAwarePermission == .requesting || permissionsManager.bluetoothPermission == .requesting || permissionsManager.localNetworkPermission == .requesting)
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) { showModal = false }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { coordinator.showTransfer2() }
                        }) {
                            Text("Skip for Now").font(.system(size: 16, weight: .medium)).foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.all, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 30)
                .background(RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.12, green: 0.12, blue: 0.12)).overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.gray.opacity(0.2), lineWidth: 1)))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
        }
        .alert("Permission Denied", isPresented: $showSettingsAlert) {
            Button("Open Settings") { openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable required permissions in Settings to continue.")
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showModal)
    }
    
    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(settingsURL) else { return }
        UIApplication.shared.open(settingsURL)
    }
}

// MARK: - Permission Row (unchanged)
struct PermissionRow: View {
    let title: String
    let description: String
    let icon: String
    let status: PermissionsManager.PermissionStatus
    let isRecommended: Bool
    
    init(title: String, description: String, icon: String, status: PermissionsManager.PermissionStatus, isRecommended: Bool = false) {
        self.title = title
        self.description = description
        self.icon = icon
        self.status = status
        self.isRecommended = isRecommended
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 24)).foregroundColor(.blue).frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                    if isRecommended {
                        Text("RECOMMENDED").font(.system(size: 10, weight: .bold)).foregroundColor(.blue).padding(.horizontal, 8).padding(.vertical, 2).background(Color.blue.opacity(0.2)).cornerRadius(4)
                    }
                    Spacer()
                }
                Text(description).font(.system(size: 14, weight: .regular)).foregroundColor(.white.opacity(0.7))
            }
            Group {
                switch status {
                case .notRequested: Image(systemName: "circle").foregroundColor(.gray)
                case .requesting: ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .blue)).scaleEffect(0.8)
                case .granted: Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                case .denied: Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                case .notApplicable: Image(systemName: "slash.circle").foregroundColor(.gray)
                }
            }.font(.system(size: 20))
        }
        .padding(.all, 20)
    }
}

#Preview {
    PermissionModalView().environmentObject(AppCoordinator())
}
