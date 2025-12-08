

import SwiftUI
import UniformTypeIdentifiers

struct TransferProgressView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Active Transfers List
                    if coordinator.activeTransfers.isEmpty {
                        emptyStateView
                    } else {
                        activeTransfersListView
                    }
                    
                    // Back button
                    Button(action: {
                        coordinator.showTransfer2()
                    }) {
                        Text("Back to Discovery")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 32)
                }
                .padding(.top, 80)
            }
        }
        .liquidGlassNavigationBar(
            title: "Transfers",
            subtitle: "\(coordinator.activeTransfers.count) active",
            showBackButton: true,
            onBackTap: {
                coordinator.showTransfer2()
            }
        )
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "arrow.up.arrow.down.circle")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No Active Transfers")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Start a transfer to see progress here")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
        }
    }
    
    // MARK: - Active Transfers List View
    
    private var activeTransfersListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(coordinator.getActiveTransfersList()) { transfer in
                    TransferCard(
                        transfer: transfer,
                        progress: coordinator.transferProgress[transfer.id] ?? 0.0,
                        metrics: coordinator.getTransferMetrics(for: transfer.id)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
    
}

// MARK: - Transfer Card Component

struct TransferCard: View {
    let transfer: TransferOperation
    let progress: Double
    let metrics: TransferMetrics?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Section
            HStack(alignment: .top, spacing: 12) {
                // File icon/type indicator
                fileTypeIcon
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(transfer.fileName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .accessibilityLabel(transfer.fileName)
                    
                    HStack(spacing: 8) {
                        Text(transfer.type == .send ? "To:" : "From:")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(transfer.deviceName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                stateIndicator
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 20)
            
            // Progress Section
            VStack(alignment: .leading, spacing: 12) {
                // Progress percentage and file size
                HStack {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(ByteCountFormatter.string(fromByteCount: Int64(transfer.fileSize), countStyle: .file))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Enhanced Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 10)
                        
                        // Progress fill with enhanced gradient
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.04, green: 0.52, blue: 1.0),
                                        Color(red: 0.04, green: 0.68, blue: 0.94),
                                        Color(red: 0.0, green: 0.78, blue: 1.0)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 10)
                            .shadow(color: Color(red: 0.04, green: 0.68, blue: 0.94).opacity(0.5), radius: 4, x: 0, y: 0)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                        
                        // Animated shimmer effect for active transfers
                        if transfer.state == .active && progress > 0 {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.clear,
                                            Color.white.opacity(0.3),
                                            Color.clear
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress, height: 10)
                                .opacity(0.5)
                        }
                    }
                }
                .frame(height: 10)
                .padding(.horizontal, 20)
                .accessibilityLabel("Transfer progress")
                .accessibilityValue("\(Int(progress * 100)) percent complete")
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityHint(accessibilityProgressHint)
                
                // Metrics Row
                if let metrics = metrics {
                    HStack(spacing: 0) {
                        MetricItem(
                            icon: "speedometer",
                            value: metrics.formattedSpeed,
                            label: "Speed",
                            color: .cyan
                        )
                        
                        Spacer()
                        
                        MetricItem(
                            icon: "clock",
                            value: metrics.formattedETA,
                            label: "ETA",
                            color: .blue
                        )
                        
                        Spacer()
                        
                        MetricItem(
                            icon: "tray.and.arrow.down",
                            value: ByteCountFormatter.string(fromByteCount: Int64(Double(transfer.fileSize) * progress), countStyle: .file),
                            label: "Transferred",
                            color: .green
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - File Type Icon
    
    private var fileTypeIcon: some View {
        let iconName: String
        let color: Color
        
        // Get file extension using proper parsing
        let fileExtension = (transfer.fileName as NSString).pathExtension.lowercased()
        
        // Use UTType to identify file type, fallback to extension check
        if let utType = UTType(filenameExtension: fileExtension) {
            if utType.conforms(to: .image) {
                iconName = "photo.fill"
                color = .orange
            } else if utType.conforms(to: .movie) || utType.conforms(to: .video) {
                iconName = "video.fill"
                color = .red
            } else {
                // Fallback to default for unrecognized UTType
                iconName = "doc.fill"
                color = .blue
            }
        } else {
            // Fallback to extension-based check if UTType resolution fails
            let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic"]
            let videoExtensions: Set<String> = ["mp4", "mov"]
            
            if imageExtensions.contains(fileExtension) {
                iconName = "photo.fill"
                color = .orange
            } else if videoExtensions.contains(fileExtension) {
                iconName = "video.fill"
                color = .red
            } else {
                // Fallback to default for unrecognized extensions
                iconName = "doc.fill"
                color = .blue
            }
        }
        
        return ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
        }
    }
    
    // MARK: - Accessibility Helpers
    
    private var accessibilityProgressHint: String {
        switch transfer.state {
        case .active:
            return "Transfer in progress"
        case .completed:
            return "Transfer completed"
        case .failed:
            return "Transfer failed"
        case .queued:
            return "Transfer queued, waiting to start"
        case .cancelled:
            return "Transfer cancelled"
        }
    }
    
    private var stateIndicator: some View {
        Group {
            switch transfer.state {
            case .queued:
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text("Queued")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange)
            case .active:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Active")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
            case .completed:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Done")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.green)
            case .failed:
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                    Text("Failed")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.red)
            case .cancelled:
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle")
                    Text("Cancelled")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            }
        }
    }
}

struct MetricItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    init(icon: String, value: String, label: String, color: Color = .blue) {
        self.icon = icon
        self.value = value
        self.label = label
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

#Preview {
    TransferProgressView()
        .environmentObject({
            let coordinator = AppCoordinator()
            coordinator.transferMode = .send
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
