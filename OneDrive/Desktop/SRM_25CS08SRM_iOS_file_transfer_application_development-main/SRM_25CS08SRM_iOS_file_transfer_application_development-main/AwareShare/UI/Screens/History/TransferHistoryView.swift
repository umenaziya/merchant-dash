import SwiftUI
import Combine

// MARK: - Transfer History View

struct TransferHistoryView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @ObservedObject private var benchmarkService = BenchmarkService.shared
    @State private var transfers: [TransferHistoryItem] = []
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ZStack {
            // Background - Pure black matching Figma (#010101)
            Color(red: 0.01, green: 0.01, blue: 0.01)
                .ignoresSafeArea()
            
            ScrollView {
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
                    Text("History")
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
                    
                    // Transfer List
                    VStack(spacing: 0) {
                        // Active/In Progress Transfers
                        ForEach(Array(coordinator.activeTransfers.values).sorted { $0.createdAt > $1.createdAt }, id: \.id) { transfer in
                            InProgressTransferCard(transfer: transfer)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 13)
                        }
                        
                        // Completed Transfers - Show all transfers, not limited to 3
                        ForEach(transfers, id: \.id) { transfer in
                            CompletedTransferHistoryCard(transfer: transfer)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 13)
                        }
                        
                        // Empty State
                        if coordinator.activeTransfers.isEmpty && transfers.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 64))
                                    .foregroundColor(.white.opacity(0.3))
                                
                                Text("No Transfer History")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Your transfer history will appear here")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 0)
                }
            }
        }
        .withGlassmorphismNavigation()
        .onAppear {
            setupHistoryObserver()
            loadTransferHistory()
        }
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func setupHistoryObserver() {
        // Observe real-time history updates from BenchmarkService
        benchmarkService.$history
            .receive(on: DispatchQueue.main)
            .sink { history in
                self.transfers = history.map { record in
                    TransferHistoryItem(
                        id: record.transferId,
                        fileName: record.fileName,
                        deviceName: record.deviceName,
                        date: record.startTime,
                        fileSize: record.fileSize,
                        duration: record.duration ?? 0,
                        speed: record.averageSpeed,
                        status: record.success ? .completed : .failed
                    )
                }
            }
            .store(in: &cancellables)
        
        // Also observe active transfers for real-time updates
        coordinator.$activeTransfers
            .receive(on: DispatchQueue.main)
            .sink { _ in
                // Trigger UI update when active transfers change
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func loadTransferHistory() {
        // Load initial history from BenchmarkService
        transfers = benchmarkService.history.map { record in
            TransferHistoryItem(
                id: record.transferId,
                fileName: record.fileName,
                deviceName: record.deviceName,
                date: record.startTime,
                fileSize: record.fileSize,
                duration: record.duration ?? 0,
                speed: record.averageSpeed,
                status: record.success ? .completed : .failed
            )
        }
    }
}

// MARK: - In Progress Transfer Card

struct InProgressTransferCard: View {
    let transfer: TransferOperation
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card
            HStack(spacing: 13) {
                // Avatar/Icon
                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.88, blue: 0.24)) // #ffe03c
                        .frame(width: 45, height: 45)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 21.75))
                        .foregroundColor(.white)
                }
                
                // Device name
                Text(transfer.deviceName)
                    .font(.system(size: 16.014, weight: .semibold))
                    .foregroundColor(Color(red: 0.98, green: 0.98, blue: 0.96)) // #faf9f6
                
                Spacer()
                
                // Status badge
                Text("In Progress")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 1.0, green: 0.61, blue: 0.29)) // #fe9c49
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.17), lineWidth: 1)
            )
            
            // Detailed progress card
            if transfer.progress > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 126) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sharing")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("56 Photos & 3 Videos")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(Color(red: 0.88, green: 0.88, blue: 0.88)) // #e1e1e1
                        }
                        
                        // Circular progress indicator
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 4)
                                .frame(width: 55.686, height: 55.686)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(transfer.progress))
                                .stroke(Color(red: 0.68, green: 0.44, blue: 1.0), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 55.686, height: 55.686)
                                .rotationEffect(.degrees(-90))
                        }
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.68, green: 0.44, blue: 1.0)) // #ae70ff
                                .frame(width: geometry.size.width * CGFloat(transfer.progress), height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    // Progress text
                    HStack(spacing: 4) {
                        Text("\(formatBytes(Int64(Double(transfer.fileSize) * transfer.progress)))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Text("of")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.white)
                        Text("\(formatBytes(transfer.fileSize))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Text("transferred")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 25)
                .padding(.vertical, 23)
                .frame(height: 150)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.09, green: 0.09, blue: 0.09), // #181818
                            Color(red: 0.05, green: 0.05, blue: 0.05) // #0c0c0c
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(20)
                .shadow(color: Color(red: 0.41, green: 0.41, blue: 0.41).opacity(0.21), radius: 0.413, x: 0.21, y: 0.21)
                .padding(.top, -8)
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Completed Transfer History Card

struct CompletedTransferHistoryCard: View {
    let transfer: TransferHistoryItem
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card - tappable to show details
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showDetails.toggle()
                }
            }) {
                HStack(spacing: 13) {
                    // Avatar/Icon based on device type
                    deviceIcon
                        .frame(width: 45, height: 45)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Device name
                        Text(transfer.deviceName)
                            .font(.system(size: 16.014, weight: .semibold))
                            .foregroundColor(Color(red: 0.98, green: 0.98, blue: 0.96)) // #faf9f6
                        
                        // File name
                        Text(transfer.fileName)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Status badge
                    Text(statusText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.17), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded details card
            if showDetails {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // Transfer details
                    DetailRow(label: "File Name", value: transfer.fileName)
                    DetailRow(label: "File Size", value: formatBytes(transfer.fileSize))
                    DetailRow(label: "Speed", value: formatSpeed(transfer.speed))
                    DetailRow(label: "Duration", value: formatDuration(transfer.duration))
                    DetailRow(label: "Date", value: formatDate(transfer.date))
                    DetailRow(label: "Status", value: statusText)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.09, green: 0.09, blue: 0.09))
                )
                .padding(.top, -8)
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s"
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else if duration < 3600 {
            return String(format: "%.1fm", duration / 60)
        } else {
            return String(format: "%.1fh", duration / 3600)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private var deviceIcon: some View {
        Group {
            if transfer.deviceName.contains("Macbook") || transfer.deviceName.contains("Mac") {
                // Purple laptop icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10.038)
                        .fill(Color(red: 0.22, green: 0.08, blue: 0.24)) // #38153d
                        .frame(width: 40.385, height: 40.385)
                    
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 22.888))
                        .foregroundColor(.white)
                }
            } else if transfer.deviceName.contains("iPhone") {
                // Blue phone icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10.038)
                        .fill(Color(red: 0.05, green: 0.16, blue: 0.24)) // #0c283e
                        .frame(width: 40.385, height: 40.385)
                    
                    Image(systemName: "iphone")
                        .font(.system(size: 21.75))
                        .foregroundColor(.white)
                }
            } else {
                // Default avatar
                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.88, blue: 0.24)) // #ffe03c
                        .frame(width: 45, height: 45)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 21.75))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var statusText: String {
        switch transfer.status {
        case .completed:
            return transfer.fileName.contains("Received") || transfer.deviceName.contains("Received") ? "Received" : "Sent"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }
}

// MARK: - Transfer History Item

struct TransferHistoryItem: Identifiable {
    let id: String
    let fileName: String
    let deviceName: String
    let date: Date
    let fileSize: Int64
    let duration: TimeInterval
    let speed: Double
    let status: HistoryTransferStatus
}

enum HistoryTransferStatus {
    case completed
    case failed
    case cancelled
}

// MARK: - Detail Row Component

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Preview

#Preview {
    TransferHistoryView()
        .environmentObject(AppCoordinator())
        .preferredColorScheme(.dark)
}
