import SwiftUI
import Combine

/// Enhanced Receive Screen with full backend functionality
struct ReceiveScreenView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var receiveManager = ReceiveManager.shared
    @State private var isReceiving = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    // Status Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: receiveManager.isReceiving ? 
                                        [Color.blue.opacity(0.3), Color.blue.opacity(0.15)] :
                                        [Color.green.opacity(0.3), Color.green.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .blur(radius: 20)
                        
                        Image(systemName: receiveManager.isReceiving ? "arrow.down.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(receiveManager.isReceiving ? .blue : .green)
                    }
                    .padding(.top, 60)
                    
                    Text(receiveManager.isReceiving ? "Receiving Files" : "Ready to Receive")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(receiveManager.isReceiving ? 
                         "Waiting for files from \(coordinator.selectedDevice?.name ?? "device")" :
                         "Tap to start receiving files")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Active Receives List
                if !receiveManager.activeReceives.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(receiveManager.activeReceives) { receive in
                                ReceiveCard(receive: receive)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    }
                } else {
                    // Empty State
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 64))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("No Active Receives")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Files will appear here when received")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                    }
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    if !isReceiving {
                        Button(action: {
                            startReceiving()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Start Receiving")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 24)
                    } else {
                        Button(action: {
                            stopReceiving()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Stop Receiving")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Back button
                    Button(action: {
                        coordinator.showSendReceiveOptions()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .liquidGlassNavigationBar(
            title: "Receive Files",
            subtitle: coordinator.selectedDevice?.name ?? "Unknown Device",
            showBackButton: true,
            onBackTap: {
                coordinator.showSendReceiveOptions()
            }
        )
        .onAppear {
            setupObservers()
            // Auto-start receiving if auto-accept is enabled
            if SettingsService.shared.autoAcceptTransfers {
                startReceiving()
            }
        }
        .onDisappear {
            cancellables.removeAll()
        }
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe receive manager state
        receiveManager.$isReceiving
            .receive(on: DispatchQueue.main)
            .sink { receiving in
                self.isReceiving = receiving
            }
            .store(in: &cancellables)
        
        // Observe completed receives
        receiveManager.$completedReceives
            .receive(on: DispatchQueue.main)
            .sink { completed in
                if !completed.isEmpty {
                    // Show completion notification
                    // Note: Using print for now since AppError doesn't have info case
                    print("Received \(completed.count) file(s) successfully")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    private func startReceiving() {
        guard let device = coordinator.selectedDevice,
              let connectedDevice = coordinator.connectionStateManager.getConnectedDevice(for: device) else {
            coordinator.showError(.deviceNotFound)
            return
        }
        
        isReceiving = true
        receiveManager.startReceiving(from: connectedDevice)
        
        // Navigate to transfer progress
        coordinator.transferMode = .receive
        coordinator.showTransferProgress()
        
        // Start receiving files
        Task {
            await coordinator.receiveFiles(from: connectedDevice)
        }
    }
    
    private func stopReceiving() {
        isReceiving = false
        receiveManager.stopReceiving()
    }
}

// MARK: - Receive Card

struct ReceiveCard: View {
    let receive: ActiveReceive
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(receive.fileName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("From: \(receive.deviceName)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                statusIndicator
            }
            
            // Progress Bar
            if receive.status == .receiving {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: receive.progress)
                        .tint(.blue)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    HStack {
                        Text("\(Int(receive.progress * 100))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        if receive.speed > 0 {
                            Text(formatSpeed(receive.speed))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var statusIndicator: some View {
        Group {
            switch receive.status {
            case .waiting:
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text("Waiting")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange)
            case .receiving:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Receiving")
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
            }
        }
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s"
    }
}

// MARK: - Receive Manager

@MainActor
class ReceiveManager: ObservableObject {
    static let shared = ReceiveManager()
    
    @Published var isReceiving = false
    @Published var activeReceives: [ActiveReceive] = []
    @Published var completedReceives: [ActiveReceive] = []
    
    private var currentDevice: ConnectedDevice?
    private var receiveTask: Task<Void, Never>?
    
    private init() {}
    
    func startReceiving(from device: ConnectedDevice) {
        guard !isReceiving else { return }
        
        currentDevice = device
        isReceiving = true
        activeReceives.removeAll()
        completedReceives.removeAll()
    }
    
    func stopReceiving() {
        isReceiving = false
        receiveTask?.cancel()
        receiveTask = nil
        currentDevice = nil
    }
    
    func addActiveReceive(_ receive: ActiveReceive) {
        activeReceives.append(receive)
    }
    
    func updateReceiveProgress(_ transferId: String, progress: Double, speed: Double = 0) {
        if let index = activeReceives.firstIndex(where: { $0.transferId == transferId }) {
            activeReceives[index].progress = progress
            activeReceives[index].speed = speed
        }
    }
    
    func completeReceive(_ transferId: String, success: Bool) {
        if let index = activeReceives.firstIndex(where: { $0.transferId == transferId }) {
            var receive = activeReceives.remove(at: index)
            receive.status = success ? .completed : .failed
            completedReceives.append(receive)
        }
    }
}

// MARK: - Active Receive Model

struct ActiveReceive: Identifiable {
    let id: String
    let transferId: String
    let fileName: String
    let deviceName: String
    var progress: Double
    var speed: Double
    var status: ReceiveStatus
    
    init(transferId: String, fileName: String, deviceName: String) {
        self.id = transferId
        self.transferId = transferId
        self.fileName = fileName
        self.deviceName = deviceName
        self.progress = 0.0
        self.speed = 0.0
        self.status = .waiting
    }
}

enum ReceiveStatus {
    case waiting
    case receiving
    case completed
    case failed
}

