

import SwiftUI

struct SendReceiveOptionsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var selectedOption: TransferMode?
    @State private var showingSelection = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        // Device info
                        if let device = coordinator.selectedDevice {
                            VStack(spacing: 8) {
                                // Device avatar/icon
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.blue.opacity(0.8),
                                                    Color.blue.opacity(0.6)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 80, height: 80)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                        )
                                    
                                    Image(systemName: deviceIcon(for: device.type))
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                
                                Text(device.name)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Connected via \(device.connectionType.displayName)")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                // Connection status indicator
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(coordinator.connectionStateManager.isDeviceConnected(device.id) ? Color.green : Color.orange)
                                        .frame(width: 8, height: 8)
                                    
                                    Text(coordinator.connectionStateManager.isDeviceConnected(device.id) ? "Connected" : "Connecting...")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.top, 4)
                            }
                        }
                        
                        Text("Choose Transfer Mode")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.top, 32)
                    }
                    .padding(.top, geometry.safeAreaInsets.top + 40)
                    
                    Spacer()
                    
                    // Transfer options
                    VStack(spacing: 24) {
                        // Send option
                        if let device = coordinator.selectedDevice {
                            let canProceed = !coordinator.requiresExplicitConnection(device.connectionType) || coordinator.connectionStateManager.isDeviceConnected(device.id)
                            
                            TransferOptionCard(
                                mode: .send,
                                title: "Send",
                                description: "Share files, photos & videos",
                                icon: "arrow.up.circle.fill",
                                color: .blue,
                                isSelected: selectedOption == .send,
                                isDisabled: !canProceed
                            ) {
                                selectedOption = .send
                                coordinator.transferMode = .send
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    showingSelection = true
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    coordinator.showTransportSelection()
                                }
                            }
                            
                            // Receive option
                            TransferOptionCard(
                                mode: .receive,
                                title: "Receive",
                                description: "Accept incoming transfers",
                                icon: "arrow.down.circle.fill",
                                color: .green,
                                isSelected: selectedOption == .receive,
                                isDisabled: !canProceed
                            ) {
                                guard let device = coordinator.selectedDevice else {
                                    return
                                }
                                
                                // Use centralized connection requirement logic
                                if coordinator.requiresExplicitConnection(device.connectionType) && !coordinator.connectionStateManager.isDeviceConnected(device.id) {
                                    return
                                }
                                
                                selectedOption = .receive
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    showingSelection = true
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    coordinator.showFileSelection(mode: .receive)
                                }
                            }
                            .disabled(!canProceed)
                            .opacity(canProceed ? 1 : 0.5)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    // Back button
                    Button(action: {
                        coordinator.showTransfer2()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back to Devices")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 32)
                }
            }
        }
    }
    
    private func deviceIcon(for type: DeviceType) -> String {
        switch type {
        case .iPhone:
            return "iphone"
        case .iPad:
            return "ipad"
        case .mac:
            return "laptopcomputer"
        case .android:
            return "smartphone"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
}

// MARK: - Transfer Option Card
struct TransferOptionCard: View {
    let mode: TransferMode
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(isDisabled ? 0.1 : 0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(isDisabled ? color.opacity(0.5) : color)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isDisabled ? .white.opacity(0.5) : .white)
                    
                    Text(description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(isDisabled ? .white.opacity(0.4) : .white.opacity(0.7))
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isDisabled ? .white.opacity(0.2) : (isSelected ? color : .white.opacity(0.3)))
            }
            .padding(.all, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isDisabled ? Color.gray.opacity(0.1) : (isSelected ? color.opacity(0.6) : Color.gray.opacity(0.2)),
                                lineWidth: isDisabled ? 1 : (isSelected ? 2 : 1)
                            )
                    )
            )
            .scaleEffect(isDisabled ? 1.0 : (isPressed ? 0.96 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            if !isDisabled {
                isPressed = pressing
            }
        }, perform: {})
    }
}

#Preview {
    SendReceiveOptionsView()
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
            return coordinator
        }())
}
