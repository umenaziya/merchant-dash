import SwiftUI

struct BenchmarkHistoryView: View {
    @ObservedObject private var benchmarkService = BenchmarkService.shared
    @State private var selectedConnectionType: ConnectionType? = nil
    @State private var showingExportSheet = false
    @State private var exportFormat: ExportFormat = .json
    @State private var searchText = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Statistics Summary
                statisticsView
                
                // Filter and Search
                filterView
                
                // History List
                historyListView
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            exportSheet
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Text("Benchmark History")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Menu {
                Button(action: { exportFormat = .json; showingExportSheet = true }) {
                    Label("Export as JSON", systemImage: "doc.text")
                }
                
                Button(action: { exportFormat = .csv; showingExportSheet = true }) {
                    Label("Export as CSV", systemImage: "tablecells")
                }
                
                Divider()
                
                Button(role: .destructive, action: clearHistory) {
                    Label("Clear History", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }
    
    // MARK: - Statistics View
    
    private var statisticsView: some View {
        let stats = benchmarkService.getStatistics(for: selectedConnectionType)
        
        return VStack(spacing: 16) {
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Transfers",
                    value: "\(stats.totalTransfers)",
                    icon: "arrow.left.arrow.right",
                    color: .blue
                )
                
                StatCard(
                    title: "Success Rate",
                    value: stats.formattedSuccessRate,
                    icon: "checkmark.circle",
                    color: .green
                )
            }
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Avg Speed",
                    value: stats.formattedAverageSpeed,
                    icon: "speedometer",
                    color: .orange
                )
                
                StatCard(
                    title: "Total Data",
                    value: stats.formattedTotalBytes,
                    icon: "externaldrive",
                    color: .purple
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Filter View
    
    private var filterView: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                
                TextField("Search files or devices", text: $searchText)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            
            // Connection Type Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilterChip(
                        title: "All",
                        isSelected: selectedConnectionType == nil,
                        action: { selectedConnectionType = nil }
                    )
                    
                    FilterChip(
                        title: "Wi-Fi Aware",
                        isSelected: selectedConnectionType == .wifiAware,
                        action: { selectedConnectionType = .wifiAware }
                    )
                    
                    FilterChip(
                        title: "Bluetooth",
                        isSelected: selectedConnectionType == .bluetooth,
                        action: { selectedConnectionType = .bluetooth }
                    )
                    
                    FilterChip(
                        title: "AirDrop",
                        isSelected: selectedConnectionType == .airDrop,
                        action: { selectedConnectionType = .airDrop }
                    )
                    
                    FilterChip(
                        title: "Multipeer",
                        isSelected: selectedConnectionType == .multipeer,
                        action: { selectedConnectionType = .multipeer }
                    )
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - History List View
    
    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredRecords) { record in
                    TransferRecordRow(record: record)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    private var filteredRecords: [TransferRecord] {
        var records = benchmarkService.history
        
        // Filter by connection type
        if let connectionType = selectedConnectionType {
            records = records.filter { $0.connectionType == connectionType }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            records = records.filter {
                $0.fileName.localizedCaseInsensitiveContains(searchText) ||
                $0.deviceName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return records
    }
    
    // MARK: - Export Sheet
    
    private var exportSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export benchmark data")
                    .font(.headline)
                    .padding(.top, 20)
                
                let exportData = exportFormat == .json ?
                    benchmarkService.exportHistory() :
                    benchmarkService.exportHistoryAsCSV()
                
                ShareLink(
                    item: exportData,
                    preview: SharePreview(
                        "Benchmark History",
                        image: Image(systemName: "chart.bar")
                    )
                ) {
                    Label("Share \(exportFormat.rawValue.uppercased())", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingExportSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func clearHistory() {
        benchmarkService.clearHistory()
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.white : Color.white.opacity(0.1))
                .cornerRadius(20)
        }
    }
}

struct TransferRecordRow: View {
    let record: TransferRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(record.success ? .green : .red)
                
                Text(record.fileName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Text(connectionTypeIcon(record.connectionType))
                    .font(.system(size: 14))
            }
            
            // Details
            HStack(spacing: 16) {
                DetailItem(icon: "person", text: record.deviceName)
                DetailItem(icon: "clock", text: record.formattedDuration)
                DetailItem(icon: "speedometer", text: record.formattedSpeed)
            }
            
            // File Size and Date
            HStack {
                Text(record.formattedFileSize)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                Text(formatDate(record.startTime))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Error message if failed
            if !record.success, let error = record.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.8))
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func connectionTypeIcon(_ type: ConnectionType) -> String {
        switch type {
        case .wifiAware: return "wifi"
        case .bluetooth: return "🔵"
        case .airDrop: return "📡"
        case .multipeer: return "🔗"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct DetailItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

enum ExportFormat: String {
    case json
    case csv
}

// MARK: - Preview

#Preview {
    BenchmarkHistoryView()
}
