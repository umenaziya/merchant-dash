import SwiftUI

struct TransportSelectionView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var selectedTransports: [ConnectionType] = []
    
    // Note: Transport priority is display-only and determined by the order in selectedTransports array
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        if let device = coordinator.selectedDevice {
                            VStack(spacing: 8) {
                                // Device info
                                Text(device.name)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Connected via \(device.connectionType.displayName)")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        Text("Select Transfer Method")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.top, 16)
                        
                        Text("Choose one or more transports. Priority is determined by selection order.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, geometry.safeAreaInsets.top + 40)
                    
                    Spacer()
                    
                    // Transport options
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(availableTransports, id: \.self) { transport in
                                TransportCard(
                                    transport: transport,
                                    isSelected: selectedTransports.contains(transport),
                                    isEnabled: isTransportEnabled(transport),
                                    priority: selectedTransports.firstIndex(of: transport).map { $0 + 1 },
                                    onTap: {
                                        toggleTransport(transport)
                                    }
                                )
                            }
                            
                            // Use Recommended button
                            Button(action: useRecommended) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Use Recommended")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.cyan)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.cyan.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                    
                    // Continue button
                    if !selectedTransports.isEmpty {
                        Button(action: continueToFileSelection) {
                            HStack {
                                Text("Continue")
                                    .font(.system(size: 18, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.04, green: 0.52, blue: 1.0),
                                        Color(red: 0.04, green: 0.68, blue: 0.94)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Back button
                    Button(action: {
                        coordinator.showSendReceiveOptions()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 32)
                }
            }
        }
        .onAppear {
            // Pre-select recommended transports
            if selectedTransports.isEmpty {
                useRecommended()
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var availableTransports: [ConnectionType] {
        [.wifiAware, .bluetooth, .multipeer, .airDrop]
    }
    
    // MARK: - Helper Methods
    
    private func isTransportEnabled(_ transport: ConnectionType) -> Bool {
        let settingsService = SettingsService.shared
        return settingsService.isConnectionTypeEnabled(transport)
    }
    
    private func toggleTransport(_ transport: ConnectionType) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedTransports.contains(transport) {
                selectedTransports.removeAll { $0 == transport }
            } else {
                selectedTransports.append(transport)
            }
        }
    }
    
    private func useRecommended() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if let device = coordinator.selectedDevice {
                selectedTransports = coordinator.getRecommendedTransports(for: device)
            }
        }
    }
    
    private func continueToFileSelection() {
        // Store selected transports in coordinator
        coordinator.selectedTransports = selectedTransports
        
        // Navigate to file selection
        if let mode = coordinator.transferMode {
            coordinator.showFileSelection(mode: mode)
        }
    }
    
}

// MARK: - Transport Card

struct TransportCard: View {
    let transport: ConnectionType
    let isSelected: Bool
    let isEnabled: Bool
    let priority: Int?
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            if isEnabled {
                onTap()
            }
        }) {
            HStack(spacing: 16) {
                // Transport icon
                ZStack {
                    Circle()
                        .fill(transportColor.opacity(isEnabled ? 0.2 : 0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: transportIcon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isEnabled ? transportColor : .gray)
                }
                
                // Transport info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(transport.displayName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isEnabled ? .white : .gray)
                        
                        if let priority = priority {
                            Text("#\(priority)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(transportColor)
                                )
                        }
                    }
                    
                    Text(transportDescription)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(isEnabled ? .white.opacity(0.7) : .gray.opacity(0.7))
                        .lineLimit(1)
                    
                    // Characteristics
                    HStack(spacing: 8) {
                        CharacteristicBadge(icon: "bolt.fill", text: speedText, color: speedColor)
                        CharacteristicBadge(icon: "antenna.radiowaves.left.and.right", text: rangeText, color: .blue)
                        CharacteristicBadge(icon: "battery.100", text: batteryText, color: batteryColor)
                    }
                    .opacity(isEnabled ? 1.0 : 0.5)
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isEnabled ? (isSelected ? transportColor : Color.gray.opacity(0.3)) : Color.gray.opacity(0.2), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(transportColor)
                    }
                }
            }
            .padding(.all, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? transportColor.opacity(0.5) : Color.gray.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            if isEnabled {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    // MARK: - Transport Properties
    
    private var transportDescription: String {
        switch transport {
        case .wifiAware: return "High speed, medium range"
        case .bluetooth: return "Low power, short range"
        case .multipeer: return "Fast, iOS devices only"
        case .airDrop: return "Very fast, Apple devices"
        }
    }
    
    private var transportIcon: String {
        switch transport {
        case .wifiAware: return "wifi.circle.fill"
        case .bluetooth: return "antenna.radiowaves.left.and.right.circle.fill"
        case .multipeer: return "network.circle.fill"
        case .airDrop: return "airplay.circle.fill"
        }
    }
    
    private var transportColor: Color {
        switch transport {
        case .wifiAware: return .cyan
        case .bluetooth: return .blue
        case .multipeer: return .purple
        case .airDrop: return .green
        }
    }
    
    private var speedText: String {
        switch transport {
        case .wifiAware: return "Fast"
        case .bluetooth: return "Medium"
        case .multipeer: return "Fast"
        case .airDrop: return "Very Fast"
        }
    }
    
    private var speedColor: Color {
        switch transport {
        case .wifiAware, .multipeer, .airDrop: return .green
        case .bluetooth: return .yellow
        }
    }
    
    private var rangeText: String {
        switch transport {
        case .wifiAware: return "Medium"
        case .bluetooth: return "Short"
        case .multipeer: return "Medium"
        case .airDrop: return "Short"
        }
    }
    
    private var batteryText: String {
        switch transport {
        case .wifiAware: return "Low"
        case .bluetooth: return "Very Low"
        case .multipeer: return "Medium"
        case .airDrop: return "Medium"
        }
    }
    
    private var batteryColor: Color {
        switch transport {
        case .wifiAware, .bluetooth: return .green
        case .multipeer, .airDrop: return .yellow
        }
    }
}

// MARK: - Characteristic Badge

struct CharacteristicBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
}

// MARK: - Preview

#Preview {
    TransportSelectionView()
        .environmentObject({
            let coordinator = AppCoordinator()
            coordinator.selectedDevice = DiscoveredDevice(
                id: "1",
                name: "John's iPhone",
                type: .iPhone,
                connectionType: .wifiAware,
                isAvailable: true,
                avatarIndex: nil
            )
            coordinator.transferMode = .send
            return coordinator
        }())
}
