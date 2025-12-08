

import SwiftUI

struct LiquidGlassNavigationBar: View {
    
    // MARK: - Properties
    
    let title: String
    let subtitle: String?
    let showBackButton: Bool
    let showSettingsButton: Bool
    let showRefreshButton: Bool
    let customLeftButton: NavigationButton?
    let customRightButton: NavigationButton?
    let onBackTap: (() -> Void)?
    let onSettingsTap: (() -> Void)?
    let onRefreshTap: (() -> Void)?
    
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @State private var isScrolled = false
    @State private var isRefreshing = false
    
    // MARK: - Initialization
    
    init(
        title: String,
        subtitle: String? = nil,
        showBackButton: Bool = false,
        showSettingsButton: Bool = false,
        showRefreshButton: Bool = false,
        customLeftButton: NavigationButton? = nil,
        customRightButton: NavigationButton? = nil,
        onBackTap: (() -> Void)? = nil,
        onSettingsTap: (() -> Void)? = nil,
        onRefreshTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showBackButton = showBackButton
        self.showSettingsButton = showSettingsButton
        self.showRefreshButton = showRefreshButton
        self.customLeftButton = customLeftButton
        self.customRightButton = customRightButton
        self.onBackTap = onBackTap
        self.onSettingsTap = onSettingsTap
        self.onRefreshTap = onRefreshTap
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Safe area spacer for notch
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: geometry.safeAreaInsets.top)
                
                // Navigation content
                HStack(alignment: .center, spacing: 16) {
                    // Left side - Back button or custom
                    leftButtonView
                        .frame(width: 44, height: 44)
                    
                    // Center - Title and subtitle
                    centerContentView
                    
                    // Right side - Settings/Refresh or custom
                    rightButtonView
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(liquidGlassBackground)
            }
        }
        .frame(height: 64 + ((UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0))
    }
    
    // MARK: - Left Button View
    
    @ViewBuilder
    private var leftButtonView: some View {
        if let customButton = customLeftButton {
            navButton(icon: customButton.icon, action: customButton.action)
        } else if showBackButton {
            navButton(icon: "chevron.left", action: onBackTap ?? {})
        } else {
            Color.clear
        }
    }
    
    // MARK: - Center Content View
    
    private var centerContentView: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                .lineLimit(1)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Right Button View
    
    @ViewBuilder
    private var rightButtonView: some View {
        if let customButton = customRightButton {
            navButton(icon: customButton.icon, action: customButton.action)
        } else if showSettingsButton {
            navButton(icon: "gearshape.fill", action: onSettingsTap ?? {})
        } else if showRefreshButton {
            refreshButtonView
        } else {
            Color.clear
        }
    }
    
    // MARK: - Refresh Button View
    
    private var refreshButtonView: some View {
        Button(action: {
            isRefreshing = true
            onRefreshTap?()
            
            // Stop refreshing after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isRefreshing = false
            }
        }) {
            ZStack {
                // Enhanced 3D glass button background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        // Inner highlight
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: 22
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .shadow(color: Color.cyan.opacity(0.1), radius: 4, x: 0, y: 2)
                
                // Icon with rotation animation
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .white,
                                .white.opacity(0.95),
                                .white.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRefreshing)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(EnhancedNavButtonStyle())
        .disabled(isRefreshing)
    }
    
    // MARK: - Liquid Glass Background
    
    private var liquidGlassBackground: some View {
        ZStack {
            // Base ultra-thin material with enhanced blur
            Rectangle()
                .fill(.ultraThinMaterial)
                .blur(radius: 0.5)
            
            // Enhanced liquid glass gradient overlay with 3D depth
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.25), location: 0.0),
                    .init(color: Color.white.opacity(0.12), location: 0.3),
                    .init(color: Color.white.opacity(0.08), location: 0.5),
                    .init(color: Color.white.opacity(0.15), location: 0.7),
                    .init(color: Color.white.opacity(0.20), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Secondary depth layer
            LinearGradient(
                stops: [
                    .init(color: Color.cyan.opacity(0.08), location: 0.0),
                    .init(color: Color.clear, location: 0.4),
                    .init(color: Color.purple.opacity(0.06), location: 1.0)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            
            // Animated liquid shimmer effect
            AnimatedLiquidShimmer()
            
            // Enhanced border with 3D effect
            VStack {
                // Top highlight
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                
                Spacer()
                
                // Bottom shadow
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.black.opacity(0.1),
                                Color.black.opacity(0.2)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5)
            }
        }
        .shadow(color: Color.black.opacity(0.25), radius: 25, x: 0, y: 15)
        .shadow(color: Color.cyan.opacity(0.1), radius: 15, x: 0, y: 5)
    }
    
    // MARK: - Navigation Button
    
    private func navButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                // Enhanced 3D glass button background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        // Inner highlight
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: 22
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .shadow(color: Color.cyan.opacity(0.1), radius: 4, x: 0, y: 2)
                
                // Icon with enhanced styling
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .white,
                                .white.opacity(0.95),
                                .white.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(EnhancedNavButtonStyle())
    }
}

// MARK: - Enhanced Animated Liquid Shimmer

struct AnimatedLiquidShimmer: View {
    @State private var animationPhase: CGFloat = 0
    @State private var secondaryPhase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Primary cyan shimmer layer with enhanced movement
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.cyan.opacity(0.2),
                                Color.cyan.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .offset(
                        x: geometry.size.width * 0.4 * CGFloat(cos(Double(animationPhase))),
                        y: 25 * CGFloat(sin(Double(animationPhase * 2.2)))
                    )
                    .blur(radius: 45)
                    .opacity(0.8 + 0.2 * CGFloat(sin(Double(animationPhase * 3))))
                
                // Secondary purple shimmer layer
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.18),
                                Color.purple.opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .offset(
                        x: geometry.size.width * -0.35 * CGFloat(sin(Double(secondaryPhase))),
                        y: 30 * CGFloat(cos(Double(secondaryPhase * 1.8)))
                    )
                    .blur(radius: 40)
                    .opacity(0.7 + 0.3 * CGFloat(cos(Double(secondaryPhase * 2.5))))
                
                // Tertiary accent layer
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .offset(
                        x: geometry.size.width * 0.2 * CGFloat(cos(Double(animationPhase * 0.7))),
                        y: 15 * CGFloat(sin(Double(animationPhase * 1.3)))
                    )
                    .blur(radius: 30)
                    .opacity(0.6 + 0.4 * CGFloat(sin(Double(animationPhase * 1.5))))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            // Primary animation
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                animationPhase = .pi * 2
            }
            
            // Secondary animation with different timing
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                secondaryPhase = .pi * 2
            }
        }
    }
}

// MARK: - Enhanced Navigation Button Style

struct EnhancedNavButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Legacy Navigation Button Style (for backward compatibility)

struct NavButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Navigation Button Model

struct NavigationButton {
    let icon: String
    let action: () -> Void
}

// MARK: - Safe Area Insets Environment Key

private struct SafeAreaInsetsKey: EnvironmentKey {
    static let defaultValue: EdgeInsets = EdgeInsets()
}

extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        get { self[SafeAreaInsetsKey.self] }
        set { self[SafeAreaInsetsKey.self] = newValue }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            LiquidGlassNavigationBar(
                title: "AwareShare",
                subtitle: "3 devices nearby",
                showBackButton: false,
                showSettingsButton: true,
                showRefreshButton: true,
                onSettingsTap: { print("Settings") },
                onRefreshTap: { print("Refresh") }
            )
            
            Spacer()
        }
    }
}

