

import SwiftUI

struct EnhancedSettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    
    // MARK: - AppStorage (Persisted Settings)
    @AppStorage("transport.wifiAware") private var useWiFiAware: Bool = true
    @AppStorage("transport.bluetooth") private var useBluetooth: Bool = true
    @AppStorage("transport.multipeer") private var useMultipeer: Bool = true
    @AppStorage("transport.airdrop") private var useAirDrop: Bool = true
    
    @AppStorage("transfer.autoAccept") private var autoAcceptTransfers: Bool = false
    @AppStorage("transfer.overwriteExisting") private var overwriteExisting: Bool = false
    @AppStorage("transfer.chunkSize") private var preferredChunkSize: Int = 12288
    
    @AppStorage("benchmark.enabled") private var benchmarkEnabled: Bool = true
    
    @AppStorage("debug.mockDevices") private var enableMockDevices: Bool = false
    @AppStorage("debug.logLevel") private var logLevel: String = "info"
    
    @AppStorage("privacy.deviceName") private var deviceName: String = UIDevice.current.name
    @AppStorage("profile.selectedAvatar") private var selectedAvatarIndex: Int = 0
    @AppStorage("airdrop.useCustomDiscovery") private var useCustomAirDropDiscovery: Bool = true
    @State private var showBenchmarkHistory = false
    
    // Interface customization (iOS 26)
    @AppStorage("interface.navigationBarTransparency") private var navigationBarTransparency: Double = 0.5
    @AppStorage("interface.navigationBarStyle") private var navigationBarStyle: String = "liquid"
    
    // Profile avatar images
    private let avatarImages = ["3d avatar", "3d-avatar-1", "3d avatar 2", "3d avatar 3", "3d avatar 4"]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Avatar Selector
                    profileAvatarSection
                        .padding(.top, 20)
                    // Transport Preferences Card
                    settingsCard(title: "Transport Preferences") {
                        VStack(spacing: 12) {
                            settingsToggleRow(title: "Wi‑Fi Aware", icon: "wifi", isOn: $useWiFiAware, color: .cyan)
                                .onChange(of: useWiFiAware) { _, enabled in
                                    handleTransportPreferenceChange(.wifiAware, enabled: enabled)
                                }
                            Divider().background(Color.white.opacity(0.1))
                            settingsToggleRow(title: "Bluetooth", icon: "antenna.radiowaves.left.and.right", isOn: $useBluetooth, color: .blue)
                                .onChange(of: useBluetooth) { _, enabled in
                                    handleTransportPreferenceChange(.bluetooth, enabled: enabled)
                                }
                            Divider().background(Color.white.opacity(0.1))
                            settingsToggleRow(title: "Multipeer", icon: "network", isOn: $useMultipeer, color: .purple)
                                .onChange(of: useMultipeer) { _, enabled in
                                    handleTransportPreferenceChange(.multipeer, enabled: enabled)
                                }
                            Divider().background(Color.white.opacity(0.1))
                            settingsToggleRow(title: "AirDrop", icon: "airplayaudio", isOn: $useAirDrop, color: .green)
                                .onChange(of: useAirDrop) { _, enabled in
                                    handleTransportPreferenceChange(.airDrop, enabled: enabled)
                                }
                        }
                    }
                    
                    // AirDrop Settings Card
                    settingsCard(title: "AirDrop Settings") {
                        VStack(spacing: 12) {
                            settingsToggleRow(title: "Use Custom Device Discovery", icon: "antenna.radiowaves.left.and.right.circle", isOn: $useCustomAirDropDiscovery, color: .green)
                                .onChange(of: useCustomAirDropDiscovery) { _, enabled in
                                    SettingsService.shared.useCustomAirDropDiscovery = enabled
                                }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.green.opacity(0.8))
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Custom Discovery vs Native AirDrop")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        Text("When enabled: Finds other AwareShare devices via Bluetooth before sharing.\n\nWhen disabled: Goes directly to iOS share sheet for native AirDrop.")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.7))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    // File Transfer Settings Card
                    settingsCard(title: "File Transfer Settings") {
                        VStack(spacing: 12) {
                            settingsToggleRow(title: "Auto-accept transfers", icon: "checkmark.circle", isOn: $autoAcceptTransfers, color: .green)
                                .onChange(of: autoAcceptTransfers) { _, enabled in
                                    SettingsService.shared.autoAcceptTransfers = enabled
                                }
                            Divider().background(Color.white.opacity(0.1))
                            settingsToggleRow(title: "Overwrite existing files", icon: "arrow.triangle.2.circlepath", isOn: $overwriteExisting, color: .orange)
                                .onChange(of: overwriteExisting) { _, enabled in
                                    SettingsService.shared.overwriteExisting = enabled
                                }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.cyan)
                                        .frame(width: 24)
                                    Text("Chunk size")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(formatChunkSize(preferredChunkSize))")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.cyan)
                                }
                                
                                Slider(value: Binding(
                                    get: { Double(preferredChunkSize) },
                                    set: { newValue in
                                        preferredChunkSize = Int(newValue)
                                        SettingsService.shared.validateChunkSize()
                                        preferredChunkSize = SettingsService.shared.preferredChunkSize
                                    }
                                ), in: 8192...16384, step: 1024)
                                .tint(.cyan)
                                .onChange(of: preferredChunkSize) { _, newValue in
                                    SettingsService.shared.validateChunkSize()
                                    preferredChunkSize = SettingsService.shared.preferredChunkSize
                                }
                                
                                Text("Range: 8 KB - 16 KB (recommended for Wi-Fi Aware)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                                
                                HStack(spacing: 12) {
                                    presetButton("8 KB", value: 8192)
                                    presetButton("12 KB", value: 12288)
                                    presetButton("16 KB", value: 16384)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    // Interface Customization Card (iOS 26)
                    settingsCard(title: "Interface (iOS 26)") {
                        VStack(spacing: 12) {
                            // Navigation Bar Style Picker
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "paintpalette")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.cyan)
                                        .frame(width: 24)
                                    Text("Navigation Bar Style")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                
                                Picker("Style", selection: $navigationBarStyle) {
                                    Text("Liquid Glass").tag("liquid")
                                    Text("Clear").tag("clear")
                                    Text("Tinted").tag("tinted")
                                }
                                .pickerStyle(.segmented)
                                .padding(.top, 4)
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            // Transparency Slider
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "circle.lefthalf.filled")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.cyan)
                                        .frame(width: 24)
                                    Text("Transparency")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(Int(navigationBarTransparency * 100))%")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.cyan)
                                }
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "eye.slash")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.5))
                                    
                                    Slider(value: $navigationBarTransparency, in: 0...1, step: 0.05)
                                        .tint(.cyan)
                                    
                                    Image(systemName: "eye")
                                        .font(.system(size: 12))
                                        .foregroundColor(.cyan)
                                }
                                
                                Text("Adjust navigation bar transparency to match your preference. Higher values create more opaque, lower values create more transparent glass effect.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.top, 4)
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            // Reduce Transparency Info
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.cyan)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("iOS 26 Liquid Glass Effect")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("The navigation bar uses iOS 26's liquid glass effect with adjustable transparency. It reflects and refracts surrounding content for a modern, immersive experience.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.7))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Benchmarking Card
                    settingsCard(title: "Benchmarking") {
                        VStack(spacing: 12) {
                            settingsToggleRow(title: "Enable benchmarking", icon: "chart.bar", isOn: $benchmarkEnabled, color: .purple)
                                .onChange(of: benchmarkEnabled) { _, enabled in
                                    BenchmarkService.shared.isEnabled = enabled
                                }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            Button {
                                showBenchmarkHistory = true
                            } label: {
                                HStack {
                                    Image(systemName: "chart.bar.xaxis")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.cyan)
                                        .frame(width: 24)
                                    Text("View Benchmark History")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            Button(role: .destructive) {
                                BenchmarkService.shared.clearHistory()
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.red)
                                        .frame(width: 24)
                                    Text("Clear History")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                            }
                        }
                    }
                    
                    // Debug Card
                    settingsCard(title: "Debug") {
                        VStack(spacing: 12) {
                            settingsToggleRow(title: "Enable mock devices", icon: "iphone.gen3.radiowaves.left.and.right", isOn: $enableMockDevices, color: .yellow)
                                .onChange(of: enableMockDevices) { _, enabled in
                                    if enabled {
                                        MockDeviceManager.shared.attach(delegate: coordinator.networkingManager)
                                        MockDeviceManager.shared.start()
                                    } else {
                                        MockDeviceManager.shared.stop()
                                    }
                                }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            HStack {
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.cyan)
                                    .frame(width: 24)
                                Text("Log level")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Picker("", selection: $logLevel) {
                                    Text("Debug").tag("debug")
                                    Text("Info").tag("info")
                                    Text("Warn").tag("warn")
                                    Text("Error").tag("error")
                                }
                                .pickerStyle(.menu)
                                .tint(.cyan)
                            }
                            
                        }
                    }
                    
                    // Privacy Card
                    settingsCard(title: "Privacy") {
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "iphone")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.cyan)
                                        .frame(width: 24)
                                    Text("Device name")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                
                                TextField("Enter device name", text: $deviceName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                    )
                                    .disableAutocorrection(true)
                                    .autocapitalization(.words)
                                    .onChange(of: deviceName) { _, newValue in
                                        // Sync with SettingsService
                                        SettingsService.shared.deviceName = newValue
                                        // Update peer display name for discovery
                                        NotificationCenter.default.post(name: NSNotification.Name("DeviceNameChanged"), object: nil)
                                    }
                                
                                Text("This name will be visible to other devices during discovery")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.top, 4)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100) // Bottom padding for nav bar
            }
        }
        .withGlassmorphismNavigation()
        .sheet(isPresented: $showBenchmarkHistory) {
            BenchmarkHistoryView()
        }
        .onAppear {
            // Clamp chunk size to valid range (8-16 KB)
            preferredChunkSize = min(max(preferredChunkSize, 8192), 16384)
            SettingsService.shared.validateChunkSize()
            
            // Sync AppStorage values with SettingsService
            SettingsService.shared.useWiFiAware = useWiFiAware
            SettingsService.shared.useBluetooth = useBluetooth
            SettingsService.shared.useMultipeer = useMultipeer
            SettingsService.shared.useAirDrop = useAirDrop
            SettingsService.shared.autoAcceptTransfers = autoAcceptTransfers
            SettingsService.shared.overwriteExisting = overwriteExisting
            SettingsService.shared.deviceName = deviceName
            
            // Apply benchmarking toggle live
            BenchmarkService.shared.isEnabled = benchmarkEnabled
            if enableMockDevices {
                MockDeviceManager.shared.attach(delegate: coordinator.networkingManager)
                MockDeviceManager.shared.start()
            }
        }
    }
    
    // MARK: - Settings Change Handlers
    
    private func handleTransportPreferenceChange(_ transport: ConnectionType, enabled: Bool) {
        // Update SettingsService
        switch transport {
        case .wifiAware:
            SettingsService.shared.useWiFiAware = enabled
        case .bluetooth:
            SettingsService.shared.useBluetooth = enabled
        case .multipeer:
            SettingsService.shared.useMultipeer = enabled
        case .airDrop:
            SettingsService.shared.useAirDrop = enabled
        }
        
        // If discovery is active, restart it to apply new transport preferences
        Task {
            if coordinator.networkingManager.isDiscovering {
                coordinator.networkingManager.resetDiscovery()
                await coordinator.networkingManager.startDiscovery()
            }
        }
    }
    
    
    // MARK: - Profile Avatar Section
    
    private var profileAvatarSection: some View {
        VStack(spacing: 16) {
            Text("Profile Avatar")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                ForEach(0..<avatarImages.count, id: \.self) { index in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedAvatarIndex = index
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: selectedAvatarIndex == index ? [
                                            Color.cyan.opacity(0.3),
                                            Color.cyan.opacity(0.15)
                                        ] : [
                                            Color.white.opacity(0.1),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                            
                            Image(avatarImages[index])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                            
                            if selectedAvatarIndex == index {
                                Circle()
                                    .stroke(Color.cyan, lineWidth: 2)
                                    .frame(width: 60, height: 60)
                                
                                Circle()
                                    .fill(Color.cyan)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 20, y: -20)
                            }
                        }
                    }
                    .accessibilityLabel("Avatar \(index + 1)")
                    .accessibilityHint(selectedAvatarIndex == index ? "Selected" : "Tap to select")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Settings Card
    
    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Settings Toggle Row
    
    private func settingsToggleRow(title: String, icon: String, isOn: Binding<Bool>, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn.wrappedValue ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Helper Functions
    
    private func formatChunkSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        return String(format: "%.0f KB", kb)
    }
    
    private func presetButton(_ label: String, value: Int) -> some View {
        Button(action: {
            preferredChunkSize = value
        }) {
            Text(label)
                .font(.caption)
                .foregroundColor(preferredChunkSize == value ? .blue : .white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(preferredChunkSize == value ? Color.blue.opacity(0.2) : Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(preferredChunkSize == value ? Color.blue : Color.clear, lineWidth: 1)
                )
        }
    }
}

#Preview {
    EnhancedSettingsView()
        .environmentObject(AppCoordinator())
}