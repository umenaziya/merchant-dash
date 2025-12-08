import SwiftUI
import Combine
import CoreBluetooth
import NearbyInteraction

struct PermissionWindowPopupView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var permissionsManager = PermissionsManager()
    @State private var hasCheckedPermissions = false
    
    /// Computed property that provides the device count text with proper pluralization
    private var deviceCountText: String {
        let count = coordinator.networkingManager.discoveredDevices.count
        if count == 1 {
            return "• 1 device available"
        } else {
            return "• \(count) devices available"
        }
    }
    
    var body: some View {
        ZStack {
            // Background - Pure black matching Figma (#010101)
            Color(red: 0.01, green: 0.01, blue: 0.01)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top spacing
                Spacer()
                    .frame(height: 40)
                
                // Logo - centered at top
                Image(systemName: "arrow.triangle.2.circlepath.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .padding(.bottom, 28)
                
                // Title - SF Pro Rounded Medium, 36px
                Text("Start Transfer")
                    .font(.system(size: 36, weight: .medium, design: .rounded))
                    .tracking(0.36)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
                
                // Subtitle - Poppins Light equivalent, 14px, 70% opacity
                Text("Tap a device to start transferring")
                    .font(.system(size: 14, weight: .light))
                    .tracking(0.14)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 50)
                
                // Permission Card
                VStack(spacing: 0) {
                    // Header section
                    VStack(spacing: 8) {
                        Text("Permission")
                            .font(.system(size: 17, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                        
                        Text("Enable connectivity options below")
                            .font(.system(size: 14, weight: .regular))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Some settings open in iOS Settings app")
                            .font(.system(size: 12, weight: .regular))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1))
                    
                    // Divider
                    Divider()
                        .background(Color.white.opacity(0.17))
                    
                    // Wi-Fi Aware option
                    VStack(spacing: 4) {
                        TransferOptionButton(
                            title: "Enable Wi‑Fi",
                            subtitle: "Open Control Center or Settings",
                            status: permissionsManager.wifiAwarePermission
                        ) {
                            permissionsManager.openWiFiSettings()
                        }
                    }
                    
                    // Divider
                    Divider()
                        .background(Color.white.opacity(0.17))
                    
                    // Bluetooth option
                    VStack(spacing: 4) {
                        TransferOptionButton(
                            title: "BLUETOOTH",
                            subtitle: "Tap to enable in Settings",
                            status: permissionsManager.bluetoothPermission
                        ) {
                            permissionsManager.openBluetoothSettings()
                        }
                    }
                    
                    // Divider
                    Divider()
                        .background(Color.white.opacity(0.17))
                    
                    // Local Network option
                    VStack(spacing: 4) {
                        TransferOptionButton(
                            title: "LOCAL NETWORK",
                            subtitle: "Grant permission in App Settings",
                            status: permissionsManager.localNetworkPermission
                        ) {
                            permissionsManager.openAppSettings()
                        }
                    }
                    
                    // Quick tip section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow.opacity(0.8))
                            Text("Quick Tip")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Text("Enable Wi-Fi and Bluetooth in Control Center (swipe down from top-right corner)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // Continue button - allows user to proceed even if permissions aren't granted
                    Button(action: {
                        coordinator.requestPermissions()
                    }) {
                        HStack {
                            Spacer()
                            Text("Continue")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .background(Color(red: 0.04, green: 0.52, blue: 1.0))
                        .cornerRadius(12)
                    }
                    .accessibilityIdentifier("Continue")
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                .frame(maxWidth: 327)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.17), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                
                // Device count
                Text(deviceCountText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 30)
                
                Spacer()
            }
        }
        .accessibilityIdentifier("PermissionModalView")
        .onAppear {
            checkPermissionsStatus()
        }
        .onChange(of: permissionsManager.bluetoothPermission) { oldValue, newValue in
            checkPermissionsAndNavigate()
        }
        .onChange(of: permissionsManager.localNetworkPermission) { oldValue, newValue in
            checkPermissionsAndNavigate()
        }
        .onChange(of: permissionsManager.wifiAwarePermission) { oldValue, newValue in
            checkPermissionsAndNavigate()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Check permissions again when app comes to foreground (user may have granted them in Settings)
            Task {
                await refreshPermissionsStatus()
                checkPermissionsAndNavigate()
            }
        }
        .withGlassmorphismNavigation()
    }
    
    // MARK: - Permission Checking Methods
    
    private func checkPermissionsStatus() {
        Task {
            await refreshPermissionsStatus()
            // Mark as checked after initial load
            hasCheckedPermissions = true
            // If permissions are already granted, navigate immediately
            if permissionsManager.allPermissionsGranted {
                checkPermissionsAndNavigate()
            }
        }
    }
    
    private func refreshPermissionsStatus() async {
        // Check Bluetooth permission
        let bluetoothAuth = CBCentralManager.authorization
        switch bluetoothAuth {
        case .allowedAlways:
            permissionsManager.bluetoothPermission = .granted
        case .denied, .restricted:
            permissionsManager.bluetoothPermission = .denied
        case .notDetermined:
            permissionsManager.bluetoothPermission = .notRequested
        @unknown default:
            permissionsManager.bluetoothPermission = .notRequested
        }
        
        // Check Wi-Fi Aware support (requires NearbyInteraction)
        // Note: NISession.isSupported is deprecated, but we use it for iOS 26.0 compatibility
        let wifiAwareSupported = NISession.isSupported
        permissionsManager.wifiAwareSupported = wifiAwareSupported
        if wifiAwareSupported {
            permissionsManager.wifiAwarePermission = .granted
        } else {
            permissionsManager.wifiAwarePermission = .notApplicable
        }
        
        // Check Local Network permission by attempting to create a browser
        // This is a best-effort check - actual permission is checked during discovery
        permissionsManager.localNetworkPermission = .granted // Assume granted unless denied during discovery
    }
    
    private func checkPermissionsAndNavigate() {
        // Only auto-navigate if permissions are granted (don't auto-navigate immediately on appear)
        // This allows user to see the screen and manually grant permissions
        guard hasCheckedPermissions else { return }
        
        // Auto-navigate if all permissions are granted - immediately, no timeout
        if permissionsManager.allPermissionsGranted {
            hasCheckedPermissions = false // Reset to prevent multiple navigations
            coordinator.requestPermissions()
        }
    }
}

struct TransferOptionButton: View {
    let title: String
    let subtitle: String?
    let status: PermissionsManager.PermissionStatus?
    let action: () -> Void
    @State private var isPressed = false
    
    init(title: String, subtitle: String? = nil, status: PermissionsManager.PermissionStatus? = nil, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.04, green: 0.52, blue: 1.0))
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Status indicator
                if let status = status {
                    statusIcon(for: status)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                isPressed ? Color.white.opacity(0.05) : Color.clear
            )
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    @ViewBuilder
    private func statusIcon(for status: PermissionsManager.PermissionStatus) -> some View {
        switch status {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.red)
        case .requesting:
            ProgressView()
                .scaleEffect(0.8)
        case .notRequested:
            Image(systemName: "circle")
                .font(.system(size: 20))
                .foregroundColor(.gray.opacity(0.5))
        case .notApplicable:
            Image(systemName: "minus.circle")
                .font(.system(size: 20))
                .foregroundColor(.gray.opacity(0.5))
        }
    }
}

#Preview {
    PermissionWindowPopupView()
        .environmentObject(AppCoordinator())
}
