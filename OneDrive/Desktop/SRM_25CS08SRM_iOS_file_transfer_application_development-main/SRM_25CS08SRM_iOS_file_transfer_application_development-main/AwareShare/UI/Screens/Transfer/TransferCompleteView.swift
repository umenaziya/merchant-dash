

import SwiftUI

struct TransferCompleteView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var benchmarkService = BenchmarkService.shared
    @State private var showingCelebration = false
    @State private var showingDetails = false
    @State private var latestRecord: TransferRecord?
    @State private var showFileViewer = false
    @State private var aggregatedSize: Int64 = 0
    @State private var aggregatedDuration: TimeInterval = 0
    @State private var aggregatedCount: Int = 0
    @State private var relevantRecords: [TransferRecord] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Success animation and content
                    VStack(spacing: 32) {
                        // Success icon with animation
                        ZStack {
                            // Background circle with pulse effect
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: showingCelebration ? 160 : 120, height: showingCelebration ? 160 : 120)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showingCelebration)
                            
                            Circle()
                                .fill(Color.green.opacity(0.1))
                                .frame(width: showingCelebration ? 200 : 160, height: showingCelebration ? 200 : 160)
                                .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.1), value: showingCelebration)
                            
                            // Success checkmark
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 64, weight: .medium))
                                .foregroundColor(.green)
                                .scaleEffect(showingCelebration ? 1.0 : 0.5)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showingCelebration)
                        }
                        
                        // Success message
                        VStack(spacing: 16) {
                            Text("Transfer Complete!")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                                .opacity(showingDetails ? 1.0 : 0.0)
                                .animation(.easeInOut(duration: 0.5).delay(0.4), value: showingDetails)
                            
                            if let device = coordinator.selectedDevice {
                                Text(coordinator.transferMode == .send ? 
                                    "Successfully sent files to \(device.name)" : 
                                    "Successfully received files from \(device.name)")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .opacity(showingDetails ? 1.0 : 0.0)
                                    .animation(.easeInOut(duration: 0.5).delay(0.6), value: showingDetails)
                            }
                        }
                        
                        // Transfer summary with aggregated data
                        VStack(spacing: 16) {
                            HStack(spacing: 40) {
                                VStack(spacing: 8) {
                                    Text("\(aggregatedCount)")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.blue)
                                    
                                    Text("Files")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                VStack(spacing: 8) {
                                    Text(ByteCountFormatter.string(fromByteCount: aggregatedSize, countStyle: .file))
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.blue)
                                    
                                    Text("Total Size")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                VStack(spacing: 8) {
                                    Text(String(format: "%.1fs", aggregatedDuration))
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.blue)
                                    
                                    Text("Duration")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding(.all, 24)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .opacity(showingDetails ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.5).delay(0.8), value: showingDetails)

                            // Details list for per-file outcomes
                            if !relevantRecords.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Details")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    ForEach(relevantRecords, id: \.id) { record in
                                        HStack(spacing: 12) {
                                            Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                                .foregroundColor(record.success ? .green : .red)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(record.fileName)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.white)
                                                HStack(spacing: 8) {
                                                    Text(ByteCountFormatter.string(fromByteCount: record.fileSize, countStyle: .file))
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.white.opacity(0.7))
                                                    if let duration = record.duration {
                                                        Text(String(format: "%.1fs", duration))
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.white.opacity(0.7))
                                                    }
                                                    Text(record.success ? "Success" : (record.errorMessage ?? "Failed"))
                                                        .font(.system(size: 12))
                                                        .foregroundColor(record.success ? .green : .red)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                                    }
                                }
                                .padding(.horizontal, 8)
                                .opacity(showingDetails ? 1.0 : 0.0)
                                .animation(.easeInOut(duration: 0.5).delay(0.9), value: showingDetails)
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        // Transfer Another button
                        Button(action: {
                            coordinator.showTransfer2()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 18, weight: .semibold))
                                
                                Text("Transfer Another")
                                    .font(.system(size: 18, weight: .semibold))
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
                        .opacity(showingDetails ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.5).delay(1.0), value: showingDetails)
                        
                        // View Files button (for receive mode)
                        if coordinator.transferMode == .receive {
                            Button(action: {
                                showFileViewer = true
                            }) {
                                HStack {
                                    Image(systemName: "folder")
                                        .font(.system(size: 16, weight: .semibold))
                                    
                                    Text("View Received Files")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .opacity(showingDetails ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.5).delay(1.1), value: showingDetails)
                        }
                        
                        // Done button
                        Button(action: {
                            coordinator.showTransfer2()
                        }) {
                            Text("Done")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .opacity(showingDetails ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.5).delay(1.2), value: showingDetails)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 32)
                }
                
                // Celebration particles (optional enhancement)
                if showingCelebration {
                    CelebrationParticles()
                }
            }
        }
        .sheet(isPresented: $showFileViewer) {
            ReceivedFilesListView()
        }
        .onAppear {
            // Load latest transfer record
            latestRecord = benchmarkService.history.first
            // Aggregate metrics for relevant transfer IDs provided by coordinator
            let ids = coordinator.completedTransferIds
            let records = benchmarkService.history.filter { ids.contains($0.transferId) }
            self.relevantRecords = records
            self.aggregatedCount = records.count
            self.aggregatedSize = records.reduce(0) { $0 + $1.fileSize }
            self.aggregatedDuration = records.compactMap { $0.duration }.reduce(0, +)
            
            // Trigger animations
            withAnimation {
                showingCelebration = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    showingDetails = true
                }
                
                // Post accessibility announcement when details are shown
                let fileCountText = aggregatedCount == 1 ? "1 file" : "\(aggregatedCount) files"
                let sizeText = ByteCountFormatter.string(fromByteCount: aggregatedSize, countStyle: .file)
                let announcement = "Transfer complete. Successfully \(coordinator.transferMode == .send ? "sent" : "received") \(fileCountText), total size \(sizeText)."
                UIAccessibility.post(notification: .announcement, argument: announcement)
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - Received Files List View
struct ReceivedFilesListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var receivedFiles: [URL] = []
    
    var body: some View {
        NavigationView {
            List {
                if receivedFiles.isEmpty {
                    Text("No received files")
                        .foregroundColor(.gray)
                } else {
                    ForEach(receivedFiles, id: \.path) { fileURL in
                        HStack {
                            Image(systemName: iconForFile(fileURL))
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(fileURL.lastPathComponent)
                                    .font(.body)
                                if let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 {
                                    Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            Spacer()
                            Button(action: {
                                shareFile(fileURL)
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Received Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadReceivedFiles()
        }
    }
    
    private func loadReceivedFiles() {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            receivedFiles = files.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
        } catch {
            print("Error loading received files: \(error)")
        }
    }
    
    private func iconForFile(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic":
            return "photo"
        case "mp4", "mov", "avi":
            return "video"
        case "pdf":
            return "doc.text"
        case "txt":
            return "doc.plaintext"
        case "zip":
            return "doc.zipper"
        default:
            return "doc"
        }
    }
    
    private func shareFile(_ url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Celebration Particles
struct CelebrationParticles: View {
    @State private var animate = false
    @State private var particleColors: [Color] = []
    
    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(index < particleColors.count ? particleColors[index] : Color.white)
                    .frame(width: 8, height: 8)
                    .offset(
                        x: animate ? CGFloat.random(in: -200...200) : 0,
                        y: animate ? CGFloat.random(in: -300...100) : 0
                    )
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.5)
                        .delay(Double(index) * 0.1),
                        value: animate
                    )
            }
        }
        .onAppear {
            // Generate stable colors once
            if particleColors.isEmpty {
                particleColors = (0..<12).map { _ in
                    Color(
                        red: Double.random(in: 0...1),
                        green: Double.random(in: 0...1),
                        blue: Double.random(in: 0...1)
                    )
                }
            }
            animate = true
        }
    }
}

// MARK: - Color Extension
extension Color {
    static var random: Color {
        return Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
    }
}

#Preview {
    TransferCompleteView()
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
