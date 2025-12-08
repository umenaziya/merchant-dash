import SwiftUI
import CoreBluetooth
import NearbyInteraction
import UIKit

// MARK: - AirDrop View

struct AirDropView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var showFilePicker = false
    @State private var selectedFiles: [URL] = []
    @StateObject private var permissionsManager = PermissionsManager()
    @StateObject private var airDropManager = AirDropManager()
    @State private var showSendReceivePopup = false
    @State private var pendingFiles: [URL] = []
    @AppStorage("airdrop.useCustomDiscovery") private var useCustomDiscovery = true
    
    var body: some View {
        ZStack {
            // Background - Pure black matching app theme
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Top spacing
                    Spacer()
                        .frame(height: 60)
                    
                    // Title - SF Pro Rounded Medium, 36px
                    Text("AirDrop")
                        .font(.system(size: 36, weight: .medium, design: .rounded))
                        .tracking(0.36)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                    
                    // Subtitle - Poppins Light equivalent, 14px, 70% opacity
                    Text("Share files instantly with nearby devices")
                        .font(.system(size: 14, weight: .light))
                        .tracking(0.14)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 24)
                    
                    // Mode Selector
                    Picker("AirDrop Mode", selection: $useCustomDiscovery) {
                        Text("Native AirDrop").tag(false)
                        Text("Discover Devices").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .onChange(of: useCustomDiscovery) { oldValue, newValue in
                        // Restart discovery when mode changes
                        Task {
                            await airDropManager.stopDiscovery()
                            if newValue {
                                await airDropManager.startDiscovery()
                            }
                        }
                    }
                    
                    // AirDrop Status Card
                    VStack(spacing: 20) {
                        // Status Icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: statusIconColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: statusIconName)
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: statusIconGradientColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        // Status Text
                        VStack(spacing: 8) {
                            Text(airDropStatusText)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text(airDropStatusDescription)
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 32)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                    
                    // Discovered Devices List (only shown in custom discovery mode)
                    if useCustomDiscovery {
                        if !airDropManager.discoveredDevices.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Nearby Devices")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    if airDropManager.isDiscovering {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                                
                                ForEach(airDropManager.discoveredDevices, id: \.id) { device in
                                    AirDropDeviceRow(device: device)
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                        }
                        
                        // Scanning Indicator
                        if airDropManager.isDiscovering && airDropManager.discoveredDevices.isEmpty {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Scanning for nearby devices...")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.top, 16)
                        }
                    }
                    
                    // Select Files Button
                    Button(action: {
                        showFilePicker = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Select Files to Share")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.8),
                                    Color.green.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    
                    // How to enable AirDrop button (always available for guidance)
                    Button(action: {
                        permissionsManager.openAirDropSettings()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 20, weight: .semibold))
                            Text("How to enable AirDrop")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.8),
                                    Color.blue.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Instructions Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How to use AirDrop")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            InstructionRow(
                                number: 1,
                                text: "Ensure AirDrop is enabled in Control Center"
                            )
                            InstructionRow(
                                number: 2,
                                text: "Select files you want to share"
                            )
                            InstructionRow(
                                number: 3,
                                text: "Choose a nearby device to send to"
                            )
                            InstructionRow(
                                number: 4,
                                text: "Recipient accepts the transfer"
                            )
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .withGlassmorphismNavigation()
        .sheet(isPresented: $showFilePicker) {
            AirDropFileSelectionView(
                onFilesSelected: { urls in
                    if !urls.isEmpty {
                        if useCustomDiscovery && !airDropManager.discoveredDevices.isEmpty {
                            // Show device selection popup in custom discovery mode
                            pendingFiles = urls
                            showSendReceivePopup = true
                        } else {
                            // Direct to native AirDrop share sheet
                            coordinator.presentAirDropShareSheet(for: urls)
                        }
                    }
                }
            )
            .environmentObject(coordinator)
        }
        .sheet(isPresented: $showSendReceivePopup) {
            AirDropSendReceivePopup(
                files: pendingFiles,
                discoveredDevices: airDropManager.discoveredDevices,
                onSend: { device in
                    showSendReceivePopup = false
                    handleSendFiles(pendingFiles, to: device)
                },
                onReceive: {
                    showSendReceivePopup = false
                    handleReceiveFiles()
                },
                onCancel: {
                    showSendReceivePopup = false
                    pendingFiles.removeAll()
                }
            )
            .environmentObject(coordinator)
        }
        .onAppear {
            Task {
                // Start discovery only if custom discovery is enabled
                if useCustomDiscovery {
                    await airDropManager.startDiscovery()
                }
            }
        }
        .onDisappear {
            Task {
                await airDropManager.stopDiscovery()
            }
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleSendFiles(_ files: [URL], to device: DiscoveredDevice) {
        Task {
            do {
                // Connect to device first
                let connectedDevice = try await airDropManager.connectToDevice(device)
                
                // Present share sheet for each file
                await coordinator.presentAirDropShareSheet(for: files)
            } catch {
                await MainActor.run {
                    coordinator.showError(.transferFailed(reason: "Failed to connect to \(device.name): \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func handleReceiveFiles() {
        // AirDrop reception is handled automatically by the system
        // The app will receive files through document types
        // Show info message that reception is ready
        print("AirDrop receive mode activated - waiting for incoming transfers")
    }
    
    // MARK: - Helper Properties
    
    private var isAirDropAvailable: Bool {
        airDropManager.isAirDropAvailable()
    }
    
    private var statusIconName: String {
        if isAirDropAvailable {
            return "airplayaudio"
        } else {
            return "exclamationmark.triangle"
        }
    }
    
    private var statusIconColors: [Color] {
        if isAirDropAvailable {
            return [Color.green.opacity(0.3), Color.green.opacity(0.15)]
        } else {
            return [Color.orange.opacity(0.3), Color.orange.opacity(0.15)]
        }
    }
    
    private var statusIconGradientColors: [Color] {
        if isAirDropAvailable {
            return [Color.green, Color.green.opacity(0.8)]
        } else {
            return [Color.orange, Color.orange.opacity(0.8)]
        }
    }
    
    private var airDropStatusText: String {
        if isAirDropAvailable {
            return "Ready to Share"
        } else {
            return "AirDrop Unavailable"
        }
    }
    
    private var airDropStatusDescription: String {
        if isAirDropAvailable {
            return "Your device is ready to share files"
        } else {
            let status = airDropManager.getAvailabilityStatus()
            if case .unavailable(let reason) = status {
                return reason
            }
            return "Please enable AirDrop in Settings to share files with nearby devices"
        }
    }
}

// MARK: - Instruction Row

struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Number circle
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
            }
            
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview {
    AirDropView()
        .environmentObject(AppCoordinator())
        .preferredColorScheme(.dark)
}

