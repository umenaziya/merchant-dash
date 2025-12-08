import SwiftUI
import OSLog

struct Transfer2UIView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var selectedTab = 0
    @State private var animateCircles = false
    @State private var isDiscovering = false
    @State private var showScanningFeedback = false
    @State private var pulseAnimation = false
    @AppStorage("profile.selectedAvatar") private var selectedAvatarIndex: Int = 0
    @AppStorage("privacy.deviceName") private var deviceName: String = UIDevice.current.name
    
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "Transfer2UIView")
    private let avatarImages = ["3d avatar", "3d-avatar-1", "3d avatar 2", "3d avatar 3", "3d avatar 4", "3d avatar 5"]
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Orbital circles - perfectly centered
            GeometryReader { geometry in
                OrbitCirclesView(animate: animateCircles, showPulse: pulseAnimation)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            
            // Content with proper spacing for bottom navigation bar
            VStack(spacing: 0) {
                // Title
                Text("Start Transfer")
                    .font(
                        Font.custom("SF Pro Rounded", size: 36)
                            .weight(.medium)
                    )
                    .kerning(0.36)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.top, 60)
                    .accessibilityLabel("Start Transfer")
                    .accessibilityHint("Main transfer screen")
                
                // Subtitle with dynamic text
                Text(isDiscovering ? "Searching for devices…" : "Tap center to scan, double tap to cancel")
                    .font(
                        Font.custom("Poppins", size: 14)
                            .weight(.light)
                    )
                    .kerning(0.14)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .opacity(0.7)
                    .padding(.top, 8)
                    .animation(.easeInOut(duration: 0.3), value: isDiscovering)
                
                Spacer()
            }
            
            // Center radar icon with tap gestures - perfectly centered
            GeometryReader { geometry in
                CenterRadarIconView(
                    isScanning: isDiscovering,
                    showPulse: pulseAnimation,
                    onSingleTap: {
                        handleSingleTap()
                    },
                    onDoubleTap: {
                        handleDoubleTap()
                    }
                )
                .frame(width: 80, height: 80)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .id("center-radar-icon-single") // Ensure only one instance in view hierarchy
            }
            
            // Device nodes - only show discovered devices around circles, center is reserved for radar icon
            DeviceNodesView(
                discoveredDevices: coordinator.networkingManager.discoveredDevices,
                isDiscovering: isDiscovering,
                onDeviceSelected: { device in
                    coordinator.showDeviceSelection(device: device)
                }
            )
            
            // Bottom device count and transport legend
            VStack {
                Spacer()
                
                // Transport legend
                if !coordinator.networkingManager.discoveredDevices.isEmpty {
                    HStack(spacing: 16) {
                        TransportLegendItem(icon: "wifi.circle.fill", label: "Wi-Fi Aware", color: .cyan)
                        TransportLegendItem(icon: "antenna.radiowaves.left.and.right.circle.fill", label: "Bluetooth", color: .blue)
                        TransportLegendItem(icon: "network.circle.fill", label: "Multipeer", color: .purple)
                        TransportLegendItem(icon: "airplay.circle.fill", label: "AirDrop", color: .green)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.bottom, 8)
                }
                
                Text("\(coordinator.networkingManager.discoveredDevices.count) devices available • \(coordinator.networkingManager.connectedDevices.count) connected")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 20) // Reduced padding since bottom nav bar will be below
            }
        }
        .withGlassmorphismNavigation()
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                animateCircles = true
            }
            Task {
                await startDiscovery()
            }
        }
    }
    
    // MARK: - Local Device
    
    private var localDevice: DiscoveredDevice {
        DiscoveredDevice(
            id: UIDevice.current.identifierForVendor?.uuidString ?? "local",
            name: deviceName,
            type: .iPhone,
            connectionType: .wifiAware,
            isAvailable: true,
            avatarIndex: selectedAvatarIndex
        )
    }
    
    // MARK: - Discovery Methods
    
    private func startDiscovery() async {
        logger.info("Starting device discovery from UI")
        isDiscovering = true
        pulseAnimation = true
        
        // ✅ FIXED: Use resetDiscovery() method instead of direct mutation
        coordinator.networkingManager.resetDiscovery()
        
        // Start discovery with all enabled transports
        // Discovery continues indefinitely until user manually stops it (double tap)
        await coordinator.networkingManager.startDiscovery()
        
        logger.info("Device discovery started - will continue until manually stopped")
    }
    
    private func handleSingleTap() {
        logger.info("Single tap detected - starting scan")
        Task {
            await startDiscovery()
        }
    }
    
    private func handleDoubleTap() {
        logger.info("Double tap detected - canceling scan")
        
        // Immediately stop animations and discovery without transition
        withAnimation(.none) {
            isDiscovering = false
            pulseAnimation = false
        }
        
        coordinator.networkingManager.resetDiscovery()
    }
}

struct OrbitCirclesView: View {
    let animate: Bool
    let showPulse: Bool
    
    var body: some View {
        ZStack {
            // Multiple orbital circles with precise Figma diameters and positioning - perfectly centered
            ForEach(Array([120, 200, 280, 360, 440].enumerated()), id: \.offset) { index, diameter in
                Circle()
                    .stroke(
                        showPulse ? Color.cyan.opacity(0.3) : Color.white.opacity(0.12),
                        lineWidth: showPulse ? 1.5 : 1
                    )
                    .frame(width: CGFloat(diameter), height: CGFloat(diameter))
                    .scaleEffect(animate ? 1.05 : 1.0)
                    .opacity(animate ? 0.9 : 1.0)
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: false), value: animate)
                    .animation(.easeInOut(duration: 0.5), value: showPulse)
            }
            
            // Blur effects for glow
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.cyan.opacity(0.3),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 50,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .offset(x: -100, y: -150)
            
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.purple.opacity(0.3),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 50,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .offset(x: 80, y: 140)
        }
    }
}

struct DeviceNodesView: View {
    let discoveredDevices: [DiscoveredDevice]
    let isDiscovering: Bool
    let onDeviceSelected: (DiscoveredDevice) -> Void
    
    // Predefined positions for devices around concentric circles (center position removed)
    // Devices appear around the circles, not in the center
    private let devicePositions: [CGPoint] = [
        CGPoint(x: -140, y: -140),  // Top-left
        CGPoint(x: 140, y: -140),   // Top-right
        CGPoint(x: -100, y: 100),   // Bottom-left
        CGPoint(x: 100, y: 100),    // Bottom-right
        CGPoint(x: 0, y: -160),     // Top-center
        CGPoint(x: -160, y: 0),     // Middle-left
        CGPoint(x: 160, y: 0)       // Middle-right
    ]
    
    // Predefined colors for device nodes
    private let deviceColors: [Color] = [
        .yellow,
        .cyan,
        Color(red: 0.22, green: 0.08, blue: 0.24),
        Color(red: 0.05, green: 0.16, blue: 0.24),
        Color(red: 0.9, green: 0.62, blue: 1),
        Color(red: 0.31, green: 0.85, blue: 0.85),
        Color(red: 0.85, green: 0.65, blue: 0.31),
        Color(red: 0.65, green: 0.31, blue: 0.85)
    ]
    
    // Avatar images
    private let avatarImages: [String] = [
        "3d-avatar-1", "3d avatar 5", "3d avatar 3", 
        "3d avatar 4", "3d avatar 2", "3d avatar"
    ]
    
    var body: some View {
        ZStack {
            // Show discovered devices with animation around concentric circles
            // Center position is reserved for radar icon only
            ForEach(Array(discoveredDevices.enumerated()), id: \.element.id) { index, device in
                // Use avatar from device if available, otherwise use index-based fallback
                let avatarIndex = device.avatarIndex ?? (index % avatarImages.count)
                let avatarName = avatarImages[avatarIndex % avatarImages.count]
                
                TransferDeviceNode(
                    imageName: avatarName,
                    imageColor: deviceColors[index % deviceColors.count],
                    deviceName: device.name,
                    isUser: false,
                    isAvatar: true,
                    device: device,
                    connectionType: device.connectionType,
                    onTap: { onDeviceSelected(device) }
                )
                .offset(x: devicePositions[min(index, devicePositions.count - 1)].x,
                       y: devicePositions[min(index, devicePositions.count - 1)].y)
                .scaleEffect(1.0)
                .opacity(1.0)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1), value: discoveredDevices.count)
            }
            
            // Show discovery indicator when no devices found - REMOVED WiFi icon to prevent duplicate with center icon
            if discoveredDevices.isEmpty && !isDiscovering {
                VStack(spacing: 12) {
                    Text("No devices found")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Tap center icon to search")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                .offset(y: 80) // Move below center icon to avoid overlap
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No devices found. Tap center icon to search")
            }
        }
    }
}

struct TransferDeviceNode: View {
    let imageName: String
    let imageColor: Color
    let deviceName: String
    let isUser: Bool
    let isAvatar: Bool
    let device: DiscoveredDevice?
    let connectionType: ConnectionType?
    let onTap: (() -> Void)?
    @State private var isPressed = false
    @EnvironmentObject private var coordinator: AppCoordinator
    
    // Initialize with optional parameters for backward compatibility
    init(imageName: String, imageColor: Color, deviceName: String, isUser: Bool, isAvatar: Bool, device: DiscoveredDevice? = nil, connectionType: ConnectionType? = nil, onTap: (() -> Void)? = nil) {
        self.imageName = imageName
        self.imageColor = imageColor
        self.deviceName = deviceName
        self.isUser = isUser
        self.isAvatar = isAvatar
        self.device = device
        self.connectionType = connectionType
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Enhanced glow effect matching Figma
                Circle()
                    .fill(imageColor.opacity(0.4))
                    .frame(width: isUser ? 70 : 60, height: isUser ? 70 : 60)
                    .blur(radius: 15)
                
                // Outer ring glow
                Circle()
                    .stroke(imageColor.opacity(0.6), lineWidth: 1)
                    .frame(width: isUser ? 65 : 55, height: isUser ? 65 : 55)
                    .blur(radius: 8)
                
                // Device icon container with enhanced styling
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                imageColor.opacity(0.8),
                                imageColor.opacity(0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isUser ? 55 : 45, height: isUser ? 55 : 45)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .overlay(
                        Group {
                            if isAvatar {
                                // 3D Avatar Image with enhanced styling
                                Image(imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: isUser ? 50 : 40, height: isUser ? 50 : 40)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                    )
                            } else {
                                // System Icon
                                Image(systemName: imageName)
                                    .foregroundColor(.white)
                                    .font(.system(size: isUser ? 22 : 18, weight: .medium))
                            }
                        }
                    )
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isPressed)
                
                // Transport indicator badge
                if let connectionType = connectionType {
                    Circle()
                        .fill(transportColor(for: connectionType))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: transportIcon(for: connectionType))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .offset(x: isUser ? 20 : 16, y: isUser ? -20 : -16)
                        .shadow(color: transportColor(for: connectionType).opacity(0.5), radius: 4, x: 0, y: 2)
                }
                
                // Connection status badge
                if let device = device {
                    Circle()
                        .fill(coordinator.connectionStateManager.isDeviceConnected(device.id) ? Color.green : Color.gray.opacity(0.5))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                        .offset(x: isUser ? -20 : -16, y: isUser ? -20 : -16)
                        .shadow(color: coordinator.connectionStateManager.isDeviceConnected(device.id) ? Color.green.opacity(0.5) : Color.clear, radius: 4, x: 0, y: 2)
                }
            }
            
            // Device name with enhanced typography
            Text(deviceName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
        }
        .onTapGesture {
            // Prevent tap if this is the local user device
            guard !isUser else { return }
            
            isPressed = true
            
            Task {
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
                await MainActor.run {
                    isPressed = false
                    
                    // Use the custom onTap callback if provided, otherwise use the device or create a mock
                    if let onTap = onTap {
                        onTap()
                    } else {
                    let selectedDevice = device ?? DiscoveredDevice(
                        id: UUID().uuidString,
                        name: deviceName,
                        type: .unknown,
                        connectionType: .wifiAware,
                        isAvailable: true,
                        avatarIndex: nil
                    )
                        coordinator.showDeviceSelection(device: selectedDevice)
                    }
                }
            }
        }
    }
    
    // MARK: - Transport Helper Methods
    
    private func transportIcon(for type: ConnectionType) -> String {
        switch type {
        case .wifiAware: return "wifi.circle.fill"
        case .bluetooth: return "antenna.radiowaves.left.and.right.circle.fill"
        case .multipeer: return "network.circle.fill"
        case .airDrop: return "airplay.circle.fill"
        }
    }
    
    private func transportColor(for type: ConnectionType) -> Color {
        switch type {
        case .wifiAware: return .cyan
        case .bluetooth: return .blue
        case .multipeer: return .purple
        case .airDrop: return .green
        }
    }
}

// MARK: - Transport Legend Item

struct TransportLegendItem: View {
    let icon: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Center Radar Icon View

struct CenterRadarIconView: View {
    let isScanning: Bool
    let showPulse: Bool
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    
    @State private var animateRadar = false
    @State private var isPressed = false
    @State private var tapTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // Outer glow when scanning - conditional rendering to prevent duplicates
            Group {
                if showPulse && isScanning {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.cyan.opacity(0.4),
                                    Color.cyan.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .blur(radius: 10)
                        .scaleEffect(1.2)
                        .opacity(0.6)
                        .id("outer-glow-single")
                }
            }
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: showPulse && isScanning)
            
            // Main icon container - single instance only
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.15, blue: 0.15),
                            Color(red: 0.09, green: 0.09, blue: 0.09)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: 70)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    showPulse && isScanning ? Color.cyan.opacity(0.6) : Color.white.opacity(0.2),
                                    showPulse && isScanning ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            
            // Radar circles animation - conditional group to prevent duplicates
            Group {
                if isScanning && animateRadar {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(
                                Color.cyan.opacity(0.4 - Double(index) * 0.1),
                                lineWidth: 1
                            )
                            .frame(
                                width: 20 + CGFloat(index) * 10,
                                height: 20 + CGFloat(index) * 10
                            )
                            .scaleEffect(animateRadar ? 1.3 : 1.0)
                            .opacity(animateRadar ? 0 : 1)
                            .animation(
                                Animation.easeOut(duration: 2)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(index) * 0.3),
                                value: animateRadar
                            )
                            .id("radar-circle-\(index)")
                    }
                }
            }
            
            // Center icon - SINGLE instance only, NO shadow to prevent ghosting/duplicate appearance
            Image(systemName: isScanning ? "antenna.radiowaves.left.and.right" : "wifi")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            showPulse && isScanning ? Color.cyan : Color.white,
                            showPulse && isScanning ? Color.cyan.opacity(0.8) : Color.white.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .id("center-icon-single") // Ensure only one instance
        }
        .compositingGroup() // Composite into single layer to prevent duplicates
        .drawingGroup() // Render as single image to prevent duplicate rendering
        .contentShape(Circle())
        .gesture(
            // Prioritize double tap
            TapGesture(count: 2)
                .onEnded { _ in
                    // Cancel any pending single tap
                    tapTask?.cancel()
                    tapTask = nil
                    
                    // Reset pressed state immediately
                    isPressed = false
                    
                    // Handle double tap
                    onDoubleTap()
                }
        )
        .simultaneousGesture(
            // Single tap with delay to allow double tap detection
            TapGesture(count: 1)
                .onEnded { _ in
                    // Cancel any existing tap task
                    tapTask?.cancel()
                    
                    // Delay single tap to allow double tap to be detected
                    tapTask = Task {
                        try? await Task.sleep(nanoseconds: 250_000_000) // 250ms delay
                        
                        // Only fire if not cancelled (double tap didn't happen)
                        if !Task.isCancelled && !isScanning {
                            await MainActor.run {
                                isPressed = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isPressed = false
                                    onSingleTap()
                                }
                            }
                        }
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isScanning ? "Scanning for devices" : "Radar scanner")
        .accessibilityHint("Single tap to start scanning, double tap to cancel")
        .accessibilityAddTraits(.isButton)
        .onAppear {
            // Only start animation if scanning
            if isScanning {
                animateRadar = true
            }
        }
        .onDisappear {
            tapTask?.cancel()
            tapTask = nil
            animateRadar = false
        }
        .onChange(of: isScanning) { _, newValue in
            // Update animation state when scanning changes, without animation to prevent duplicates
            withAnimation(.none) {
                animateRadar = newValue
            }
        }
    }
}

struct RadarIconView: View {
    @State private var animateRadar = false
    
    var body: some View {
        ZStack {
            // Background square
            RoundedRectangle(cornerRadius: 8.56)
                .fill(Color(red: 0.09, green: 0.09, blue: 0.09))
                .frame(width: 40, height: 40)
            
            // Radar circles
            ForEach(0..<4) { index in
                Circle()
                    .stroke(
                        Color.white.opacity(0.3 - Double(index) * 0.07),
                        lineWidth: 0.5
                    )
                    .frame(
                        width: 15 + CGFloat(index) * 5,
                        height: 15 + CGFloat(index) * 5
                    )
                    .scaleEffect(animateRadar ? 1.2 : 1.0)
                    .opacity(animateRadar ? 0 : 1)
                    .animation(
                        Animation.easeOut(duration: 2)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.2),
                        value: animateRadar
                    )
            }
            
            // Center dot
            Circle()
                .fill(Color.cyan)
                .frame(width: 6, height: 6)
        }
        .onAppear {
            animateRadar = true
        }
    }
}


// MARK: - Preview
struct Transfer2UIView_Previews: PreviewProvider {
    static var previews: some View {
        Transfer2UIView()
            .previewDevice("iPhone 14 Pro")
            .previewDisplayName("iPhone 14 Pro")
    }
}
