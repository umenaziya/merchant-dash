import SwiftUI

/// Demo view showcasing the new Glassmorphism Tab Bar
/// Compares it side-by-side with performance metrics from the reference screenshot
struct GlassmorphismDemoView: View {
    @State private var selectedTab = 2 // Start with "Benchmarks" selected (like screenshot)
    @State private var latency: String = "45ms"
    @State private var count: String = "1,247"
    
    var body: some View {
        ZStack {
            // Dark gradient background (modern iOS style)
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Performance metrics header (like screenshot)
                MetricsHeader(latency: latency, count: count)
                    .padding(.top, 60)
                
                Spacer()
                
                // Content area showing current tab
                TabContentView(selectedTab: selectedTab)
                
                Spacer()
                
                // Progress indicator (optional)
                ProgressBar(value: 0.7)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 100)
            }
        }
        .glassmorphismTabBar(
            tabs: [
                TabItem(title: "Devices", iconName: "antenna.radiowaves.left.and.right"),
                TabItem(title: "Transfer", iconName: "clock.fill"),
                TabItem(title: "Benchmarks", iconName: "airplayaudio"),
                TabItem(title: "Settings", iconName: "gearshape.fill")
            ],
            selection: $selectedTab
        )
    }
}

// MARK: - Metrics Header

struct MetricsHeader: View {
    let latency: String
    let count: String
    
    var body: some View {
        HStack {
            // Latency (left)
            Text(latency)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color.white.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            Spacer()
            
            // Count (right)
            Text(count)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color.white.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal, 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Latency \(latency), Count \(count)")
    }
}

// MARK: - Tab Content View

struct TabContentView: View {
    let selectedTab: Int
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: iconForTab(selectedTab))
                .font(.system(size: 80, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.cyan,
                            Color.blue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.cyan.opacity(0.5), radius: 20, x: 0, y: 10)
            
            // Title
            Text(titleForTab(selectedTab))
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color.white.opacity(0.9)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // Subtitle
            Text(subtitleForTab(selectedTab))
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
    }
    
    private func iconForTab(_ tab: Int) -> String {
        switch tab {
        case 0: return "antenna.radiowaves.left.and.right"
        case 1: return "clock.fill"
        case 2: return "airplayaudio"
        case 3: return "gearshape.fill"
        default: return "questionmark"
        }
    }
    
    private func titleForTab(_ tab: Int) -> String {
        switch tab {
        case 0: return "Devices"
        case 1: return "Transfer"
        case 2: return "Benchmarks"
        case 3: return "Settings"
        default: return "Unknown"
        }
    }
    
    private func subtitleForTab(_ tab: Int) -> String {
        switch tab {
        case 0: return "Discover nearby iOS devices using Wi‑Fi Aware, Bluetooth, and Multipeer Connectivity"
        case 1: return "View active transfers and manage file sharing across all connection types"
        case 2: return "Monitor performance metrics, speeds, and connection quality in real-time"
        case 3: return "Configure app preferences, privacy, and connection settings"
        default: return ""
        }
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let value: Double // 0.0 to 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)
                
                // Progress fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.cyan,
                                Color.blue
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * value, height: 4)
                    .shadow(color: Color.cyan.opacity(0.5), radius: 4, x: 0, y: 0)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Preview

#Preview {
    GlassmorphismDemoView()
}

