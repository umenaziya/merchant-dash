import SwiftUI
import UIKit

// MARK: - Tab Item Model

struct TabItem: Identifiable {
    let id = UUID()
    let title: String
    let iconName: String
}

// MARK: - Glassmorphism Tab Bar

struct GlassmorphismTabBar: View {
    let tabs: [TabItem]
    @Binding var selection: Int
    @AppStorage("interface.navigationBarTransparency") private var transparency: Double = 0.7
    
    @State private var selectedPillOffset: CGFloat = 0
    @Namespace private var animation
    @State private var impactGenerator = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        GeometryReader { geometry in
            // Calculate tab width correctly (accounting for horizontal padding)
            let availableWidth = geometry.size.width - 32 // 16 padding on each side
            let tabWidth = availableWidth / CGFloat(tabs.count)
            let pillWidth = tabWidth - 16 // Pill is slightly narrower than tab
            
            ZStack(alignment: .leading) {
                // Background glass container
                GlassBackground()
                    .frame(height: 64)
                    .clipShape(Capsule())
                
                // Selected pill indicator (sliding capsule) - perfectly centered
                SelectedPill()
                    .frame(width: pillWidth, height: 52)
                    .offset(x: calculatePillOffset(for: selection, tabWidth: tabWidth, pillWidth: pillWidth))
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: selectedPillOffset)
                
                // Tab buttons
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                        TabButton(
                            tab: tab,
                            isSelected: selection == index,
                            action: {
                                impactGenerator.impactOccurred()
                                
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                    selection = index
                                    selectedPillOffset = calculatePillOffset(for: index, tabWidth: tabWidth, pillWidth: pillWidth)
                                }
                            }
                        )
                        .frame(width: tabWidth)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .onAppear {
                selectedPillOffset = calculatePillOffset(for: selection, tabWidth: tabWidth, pillWidth: pillWidth)
            }
            .onChange(of: selection) { _, newValue in
                selectedPillOffset = calculatePillOffset(for: newValue, tabWidth: tabWidth, pillWidth: pillWidth)
            }
        }
        .frame(height: 64)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Pill Offset Calculation
    
    /// Calculates the perfect center offset for the pill indicator
    private func calculatePillOffset(for index: Int, tabWidth: CGFloat, pillWidth: CGFloat) -> CGFloat {
        // Center of the tab: index * tabWidth + tabWidth/2
        // Center of pill: offset + pillWidth/2
        // We want: offset + pillWidth/2 = index * tabWidth + tabWidth/2
        // Therefore: offset = index * tabWidth + tabWidth/2 - pillWidth/2
        // Simplifying: offset = index * tabWidth + (tabWidth - pillWidth) / 2
        
        let tabCenter = CGFloat(index) * tabWidth + tabWidth / 2
        let pillCenterOffset = pillWidth / 2
        return tabCenter - pillCenterOffset
    }
}

// MARK: - Glass Background

struct GlassBackground: View {
    @AppStorage("interface.navigationBarTransparency") private var transparency: Double = 0.7
    @AppStorage("interface.navigationBarStyle") private var navigationBarStyle: String = "liquid"
    
    var body: some View {
        ZStack {
            // Base material blur - changes based on style setting
            // Apply opacity overlay to ensure visibility
            Capsule()
                .fill(glassMaterial)
                .opacity(materialOpacity)
            
            // Translucent dark fill with adjustable opacity
            // This ensures the glass effect is visible even at low transparency
            Capsule()
                .fill(
                    Color.black.opacity(darkFillOpacity)
                )
                .blendMode(.multiply)
            
            // Tinted overlay for "tinted" style
            if navigationBarStyle == "tinted" {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.08 * transparency),
                                Color.blue.opacity(0.05 * transparency)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.overlay)
            }
            
            // Vertical gradient overlay (top lighter, bottom darker)
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.08 * transparency), location: 0.0),
                    .init(color: Color.white.opacity(0.02 * transparency), location: 0.5),
                    .init(color: Color.black.opacity(0.12 * transparency), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(Capsule())
            .blendMode(.overlay)
            
            // Subtle noise texture
            NoiseTexture()
                .opacity(0.05 * transparency)
                .clipShape(Capsule())
                .blendMode(.overlay)
            
            // Specular highlight on top curve
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.15 * transparency), location: 0.0),
                    .init(color: Color.clear, location: 0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(Capsule())
            .frame(height: 20)
            .offset(y: -22)
            
            // Inner stroke (hairline border)
            Capsule()
                .strokeBorder(
                    Color.white.opacity(0.2 * transparency),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.3 * transparency), radius: 12, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.15 * transparency), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Style-Based Material
    
    private var glassMaterial: Material {
        switch navigationBarStyle {
        case "clear":
            return .ultraThinMaterial
        case "tinted":
            return .regularMaterial
        default: // "liquid"
            return .thinMaterial
        }
    }
    
    // MARK: - Style-Based Opacity
    
    private var darkFillOpacity: Double {
        switch navigationBarStyle {
        case "clear":
            // Clear style: More transparent but still visible (min 0.5, max 0.7)
            return 0.5 + (0.2 * transparency)
        case "tinted":
            // Tinted style: Medium opacity with tint visible (min 0.6, max 0.8)
            return 0.6 + (0.2 * transparency)
        default: // "liquid"
            // Liquid Glass: Balanced opacity for glass effect (min 0.7, max 0.85)
            return 0.7 + (0.15 * transparency)
        }
    }
    
    // MARK: - Material Opacity Overlay
    
    /// Ensures material has minimum opacity for visibility
    private var materialOpacity: Double {
        switch navigationBarStyle {
        case "clear":
            return 0.6 + (0.4 * transparency) // 0.6 to 1.0
        case "tinted":
            return 0.7 + (0.3 * transparency) // 0.7 to 1.0
        default: // "liquid"
            return 0.8 + (0.2 * transparency) // 0.8 to 1.0
        }
    }
}

// MARK: - Selected Pill (Sliding Indicator)

struct SelectedPill: View {
    @AppStorage("interface.navigationBarTransparency") private var transparency: Double = 0.7
    @AppStorage("interface.navigationBarStyle") private var navigationBarStyle: String = "liquid"
    
    var body: some View {
        ZStack {
            // Brighter glass background - adapts to style
            Capsule()
                .fill(selectedPillMaterial)
                .opacity(selectedPillOpacity)
            
            // Inner glow
            Capsule()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(0.25 * transparency),
                            Color.blue.opacity(0.1 * transparency),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 50
                    )
                )
                .blendMode(.screen)
            
            // Gradient overlay
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.12 * transparency), location: 0.0),
                    .init(color: Color.white.opacity(0.05 * transparency), location: 0.5),
                    .init(color: Color.clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(Capsule())
            .blendMode(.overlay)
            
            // Inner shadow effect
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3 * transparency),
                            Color.white.opacity(0.15 * transparency),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            
            // Outer glow
            Capsule()
                .stroke(Color.blue.opacity(0.3 * transparency), lineWidth: 2)
                .blur(radius: 4)
        }
        .shadow(color: Color.blue.opacity(0.2 * transparency), radius: 8, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.2 * transparency), radius: 4, x: 0, y: 1)
    }
    
    // MARK: - Style-Based Material
    
    private var selectedPillMaterial: Material {
        switch navigationBarStyle {
        case "clear":
            return .ultraThinMaterial
        case "tinted":
            return .regularMaterial
        default: // "liquid"
            return .regularMaterial
        }
    }
    
    // MARK: - Style-Based Opacity
    
    private var selectedPillOpacity: Double {
        switch navigationBarStyle {
        case "clear":
            // Clear style: Minimum 0.6 opacity for visibility
            return 0.6 + (0.4 * transparency)
        case "tinted":
            // Tinted style: Medium-high opacity to show tint
            return 0.75 + (0.25 * transparency)
        default: // "liquid"
            // Liquid Glass: Balanced opacity for glass effect
            return 0.8 + (0.2 * transparency)
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    @AppStorage("interface.navigationBarTransparency") private var transparency: Double = 0.7
    
    var body: some View {
        Button(action: {
            isPressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }) {
            VStack(spacing: 4) {
                // Icon
                Image(systemName: tab.iconName)
                    .font(.system(size: isSelected ? 24 : 22, weight: .semibold))
                    .foregroundStyle(
                        isSelected ?
                            LinearGradient(
                                colors: [
                                    Color.blue,
                                    Color.blue.opacity(0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.85 * transparency),
                                    Color.white.opacity(0.7 * transparency)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .shadow(color: isSelected ? Color.blue.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                
                // Label (only for selected tab)
                if isSelected {
                    Text(tab.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.blue,
                                    Color.blue.opacity(0.9)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                // Hover effect background
                Group {
                    if !isSelected && isHovered {
                        Circle()
                            .fill(Color.white.opacity(0.1 * transparency))
                            .frame(width: 44, height: 44)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            )
            .scaleEffect(isPressed ? 0.95 : (isSelected ? 1.05 : (isHovered ? 1.03 : 1.0)))
            .opacity(isPressed ? 0.8 : (isHovered && !isSelected ? 0.95 : 1.0))
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 44, height: 44)
        .onLongPressGesture(minimumDuration: 0) {
            // Touch feedback
        } onPressingChanged: { pressing in
            isHovered = pressing
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isHovered {
                        isHovered = true
                    }
                }
                .onEnded { _ in
                    isHovered = false
                }
        )
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select \(tab.title)")
    }
}

// MARK: - Noise Texture

struct NoiseTexture: View {
    // Cache for precomputed noise dots to avoid regenerating on every redraw
    private static var dotCache: [String: [(x: CGFloat, y: CGFloat, opacity: Double)]] = [:]
    private static let cacheLock = NSLock()
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Use cached dots if available, otherwise generate and cache
                let dots = getOrGenerateDots(for: size)
                
                for dot in dots {
                    context.fill(
                        Path(ellipseIn: CGRect(x: dot.x, y: dot.y, width: 1, height: 1)),
                        with: .color(.white.opacity(dot.opacity))
                    )
                }
            }
        }
    }
    
    private func getOrGenerateDots(for size: CGSize) -> [(x: CGFloat, y: CGFloat, opacity: Double)] {
        // Create a cache key based on size (rounded to avoid too many cache entries)
        let cacheKey = "\(Int(size.width / 10))x\(Int(size.height / 10))"
        
        // Check cache
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }
        
        if let cached = Self.dotCache[cacheKey] {
            return cached
        }
        
        // Generate new dots using a seeded random number generator
        var generator = SeededRandomNumberGenerator(seed: 42)
        let dotCount = Int(size.width * size.height / 100)
        var dots: [(x: CGFloat, y: CGFloat, opacity: Double)] = []
        
        for _ in 0..<dotCount {
            let x = CGFloat.random(in: 0...size.width, using: &generator)
            let y = CGFloat.random(in: 0...size.height, using: &generator)
            let opacity = Double.random(in: 0.3...1.0, using: &generator)
            dots.append((x: x, y: y, opacity: opacity))
        }
        
        // Cache the generated dots
        Self.dotCache[cacheKey] = dots
        return dots
    }
}

// MARK: - Seeded Random Number Generator

/// A deterministic random number generator that produces the same sequence
/// for a given seed, ensuring stable noise patterns across redraws.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        // Linear congruential generator (LCG) for deterministic randomness
        state = (state &* 1103515245 &+ 12345) & 0x7fffffff
        return state
    }
}

// MARK: - Random Number Extensions

extension CGFloat {
    static func random(in range: ClosedRange<CGFloat>, using generator: inout SeededRandomNumberGenerator) -> CGFloat {
        let randomValue = Double(generator.next()) / Double(UInt64.max)
        return range.lowerBound + CGFloat(randomValue) * (range.upperBound - range.lowerBound)
    }
}

extension Double {
    static func random(in range: ClosedRange<Double>, using generator: inout SeededRandomNumberGenerator) -> Double {
        let randomValue = Double(generator.next()) / Double(UInt64.max)
        return range.lowerBound + randomValue * (range.upperBound - range.lowerBound)
    }
}

// MARK: - View Extension

extension View {
    func glassmorphismTabBar(
        tabs: [TabItem],
        selection: Binding<Int>
    ) -> some View {
        ZStack(alignment: .bottom) {
            self
            
            VStack(spacing: 0) {
                Spacer()
                
                // Navigation bar aligned to bottom edge with safe area padding
                GlassmorphismTabBar(tabs: tabs, selection: selection)
                    .padding(.bottom, 8) // Above home indicator (matches screenshot alignment)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        // Dark gradient background
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.12),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        
        // Preview content
        VStack {
            Spacer()
            
            Text("Glassmorphism Tab Bar")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("iOS 26 Liquid Glass Effect")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
        }
        .glassmorphismTabBar(
            tabs: [
                TabItem(title: "Home", iconName: "antenna.radiowaves.left.and.right"),
                TabItem(title: "History", iconName: "clock.fill"),
                TabItem(title: "AirDrop", iconName: "airplayaudio"),
                TabItem(title: "Settings", iconName: "gearshape.fill")
            ],
            selection: .constant(2)
        )
    }
}

