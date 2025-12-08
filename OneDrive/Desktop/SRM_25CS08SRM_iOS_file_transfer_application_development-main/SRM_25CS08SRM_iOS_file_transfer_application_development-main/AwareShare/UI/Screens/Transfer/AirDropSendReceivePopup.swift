import SwiftUI

// MARK: - AirDrop Send/Receive Popup

struct AirDropSendReceivePopup: View {
    let files: [URL]
    let discoveredDevices: [DiscoveredDevice]
    let onSend: (DiscoveredDevice) -> Void
    let onReceive: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(.green)
                    
                    Text("AirDrop")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("\(files.count) file\(files.count == 1 ? "" : "s") selected")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 24)
                .padding(.bottom, 20)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Options
                VStack(spacing: 0) {
                    // Send Option
                    if !discoveredDevices.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Send To")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                            
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(discoveredDevices, id: \.id) { device in
                                        Button(action: {
                                            onSend(device)
                                        }) {
                                            HStack(spacing: 12) {
                                                // Device icon
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.green.opacity(0.2))
                                                        .frame(width: 44, height: 44)
                                                    
                                                    Image(systemName: device.type == .iPhone ? "iphone" : "laptopcomputer")
                                                        .font(.system(size: 20, weight: .medium))
                                                        .foregroundColor(.green)
                                                }
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(device.name)
                                                        .font(.system(size: 16, weight: .semibold))
                                                        .foregroundColor(.white)
                                                    
                                                    Text("AirDrop")
                                                        .font(.system(size: 12, weight: .regular))
                                                        .foregroundColor(.white.opacity(0.6))
                                                }
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(.white.opacity(0.5))
                                            }
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(0.05))
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                            }
                            .frame(maxHeight: 200)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                    }
                    
                    // Receive Option
                    Button(action: {
                        onReceive()
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Receive Files")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Wait for incoming transfers")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // Cancel Button
                    Button(action: {
                        onCancel()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.09, green: 0.09, blue: 0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
            .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
        }
    }
}

// MARK: - AirDrop Device Row

struct AirDropDeviceRow: View {
    let device: DiscoveredDevice
    
    var body: some View {
        HStack(spacing: 12) {
            // Device icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: device.type == .iPhone ? "iphone" : "laptopcomputer")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Ready to receive")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    AirDropSendReceivePopup(
        files: [],
        discoveredDevices: [
            DiscoveredDevice(
                id: "1",
                name: "John's iPhone",
                type: .iPhone,
                connectionType: .airDrop,
                isAvailable: true,
                avatarIndex: nil
            )
        ],
        onSend: { _ in },
        onReceive: { },
        onCancel: { }
    )
    .preferredColorScheme(.dark)
}

