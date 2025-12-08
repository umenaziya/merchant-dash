
import SwiftUI

// MARK: - Animated Splash Screen View

struct AnimatedSplashScreenView: View {
    
    // MARK: - Environment Objects
    
    @EnvironmentObject private var coordinator: AppCoordinator
    
    // MARK: - State Properties
    
    @State private var textAnimationProgress: CGFloat = 0.0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0.0
    @State private var backgroundOpacity: Double = 0.0
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0.0
    @State private var isAnimating = false
    @State private var textHoverOffset: CGFloat = 0.0
    @State private var textHoverScale: CGFloat = 1.0
    @State private var isTextTouched: Bool = false
    @State private var textShadowRadius: CGFloat = 0.0
    
    // MARK: - Task Properties for Cancellable Animations
    
    @State private var animationTask: Task<Void, Never>?
    @State private var touchTask: Task<Void, Never>?
    
    // MARK: - Animation Properties
    
    private let animationDuration: Double = 2.5
    private let textAnimationDuration: Double = 1.8
    private let ringAnimationDuration: Double = 2.0
    private let hoverAnimationDuration: Double = 3.0
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with gradient and vignette
                backgroundView
                
                // Main content with centered icon and rings
                mainContentView
                
                // Home indicator
                homeIndicatorView
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            // Cancel all tasks when view disappears
            animationTask?.cancel()
            touchTask?.cancel()
            animationTask = nil
            touchTask = nil
        }
    }
    
    // MARK: - Background View
    
    private var backgroundView: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient background
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 0.16, green: 0.16, blue: 0.16), location: 0.0),
                        .init(color: Color(red: 0.07, green: 0.06, blue: 0.07), location: 1.0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: max(geometry.size.width, geometry.size.height)
                )
                .opacity(backgroundOpacity)
                .animation(.easeInOut(duration: 1.0), value: backgroundOpacity)
                
                // Vignette overlay
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: Color.black.opacity(0.3), location: 0.7),
                        .init(color: Color.black.opacity(0.6), location: 1.0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.8
                )
                .opacity(backgroundOpacity)
                .animation(.easeInOut(duration: 1.2), value: backgroundOpacity)
            }
        }
    }
    
    // MARK: - Concentric Rings View
    
    private var concentricRingsView: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .stroke(
                        Color.white.opacity(ringOpacity(for: index)),
                        lineWidth: 1.5
                    )
                    .frame(width: ringSize(for: index), height: ringSize(for: index))
                    .scaleEffect(ringScale)
                    .opacity(ringOpacity)
                    .animation(
                        .easeInOut(duration: ringAnimationDuration)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: ringScale
                    )
            }
        }
    }
    
    // MARK: - Main Content View
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Centered content with icon in the middle of rings
            ZStack {
                // Concentric rings centered
                concentricRingsView
                
                // App logo/icon centered within rings
                appLogoView
            }
            .frame(height: 300) // Fixed height to center the rings and icon
            
            Spacer()
            
            // App name with flowing text animation and hovering effect
            appNameView
            
            Spacer()
        }
    }
    
    // MARK: - App Logo View
    
    private var appLogoView: some View {
        ZStack {
            // Logo background circle with gentle pulsing
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(red: 0.24, green: 0.24, blue: 0.24), location: 0.0),
                            .init(color: Color(red: 0.12, green: 0.12, blue: 0.12), location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 80, height: 80)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .animation(
                    .spring(response: 0.8, dampingFraction: 0.7)
                    .delay(0.3),
                    value: logoScale
                )
                .animation(
                    .easeInOut(duration: 0.8)
                    .delay(0.3),
                    value: logoOpacity
                )
                .overlay(
                    // Subtle glow effect
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .frame(width: 80, height: 80)
                        .scaleEffect(logoScale * 1.1)
                        .opacity(logoOpacity * 0.5)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                            .delay(0.5),
                            value: logoScale
                        )
                )
            
            // Logo icon with gentle scaling
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.white)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .animation(
                    .spring(response: 0.8, dampingFraction: 0.7)
                    .delay(0.3),
                    value: logoScale
                )
                .animation(
                    .easeInOut(duration: 0.8)
                    .delay(0.3),
                    value: logoOpacity
                )
                .shadow(color: .white.opacity(0.3), radius: 2, x: 0, y: 0)
        }
    }
    
    // MARK: - App Name View (Smooth Hovering & Dynamic Shadow)
    
    private var appNameView: some View {
        Text("AwareLink")
            .font(.system(size: 36, weight: .regular, design: .default))
            .foregroundStyle(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.white.opacity(0.9), location: 0.0),
                        .init(color: Color.white.opacity(0.7), location: 0.5),
                        .init(color: Color.white.opacity(0.9), location: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(
                color: isTextTouched ? Color.cyan.opacity(0.8) : Color.white.opacity(0.3),
                radius: textShadowRadius,
                x: 0,
                y: 0
            )
            .scaleEffect(textHoverScale)
            .offset(y: textHoverOffset)
            .mask(
                // Flowing text animation mask
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.clear, location: 0.0),
                                .init(color: Color.black, location: textAnimationProgress),
                                .init(color: Color.clear, location: min(textAnimationProgress + 0.4, 1.0))
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .animation(
                        .easeInOut(duration: textAnimationDuration)
                        .delay(0.8),
                        value: textAnimationProgress
                    )
            )
            .opacity(logoOpacity)
            .animation(
                .easeInOut(duration: 0.8)
                .delay(0.8),
                value: logoOpacity
            )
            .animation(
                .easeInOut(duration: hoverAnimationDuration)
                .repeatForever(autoreverses: true)
                .delay(1.2),
                value: textHoverOffset
            )
            .animation(
                .easeInOut(duration: hoverAnimationDuration)
                .repeatForever(autoreverses: true)
                .delay(1.2),
                value: textHoverScale
            )
            .animation(
                .spring(response: 0.3, dampingFraction: 0.6),
                value: textShadowRadius
            )
            .onTapGesture {
                handleTextTouch()
            }
    }
    
    // MARK: - Home Indicator View
    
    private var homeIndicatorView: some View {
        VStack {
            Spacer()
            
            RoundedRectangle(cornerRadius: 100)
                .fill(Color.white.opacity(0.6))
                .frame(width: 134, height: 5)
                .padding(.bottom, 8)
                .opacity(backgroundOpacity)
                .animation(.easeInOut(duration: 1.0).delay(1.5), value: backgroundOpacity)
        }
    }
    
    // MARK: - Helper Methods
    
    private func ringSize(for index: Int) -> CGFloat {
        switch index {
        case 0: return 120
        case 1: return 200
        case 2: return 280
        case 3: return 360
        case 4: return 440
        default: return 120
        }
    }
    
    private func ringOpacity(for index: Int) -> Double {
        switch index {
        case 0: return 0.8
        case 1: return 0.6
        case 2: return 0.4
        case 3: return 0.2
        case 4: return 0.1
        default: return 0.8
        }
    }
    
    private func handleTextTouch() {
        // Cancel any existing touch task
        touchTask?.cancel()
        
        // Haptic feedback for touch
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Dynamic shadow appears on touch
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isTextTouched = true
            textShadowRadius = 12.0
        }
        
        // Create a new task for touch animations
        touchTask = Task { @MainActor in
            // Restart flowing animation on touch
            guard !Task.isCancelled else { return }
            
            withAnimation(.easeInOut(duration: 0.8)) {
                textAnimationProgress = 0.0
            }
            
            // Wait 0.1 seconds before restarting animation
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            guard !Task.isCancelled else { return }
            
            withAnimation(.easeInOut(duration: 1.0)) {
                textAnimationProgress = 1.0
            }
            
            // Wait 0.4 seconds before removing shadow
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
            
            guard !Task.isCancelled else { return }
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isTextTouched = false
                textShadowRadius = 0.0
            }
        }
    }
    
    private func startAnimations() {
        // Cancel any existing animation task
        animationTask?.cancel()
        
        isAnimating = true
        
        // Background fade in
        withAnimation(.easeInOut(duration: 1.0)) {
            backgroundOpacity = 1.0
        }
        
        // Logo entrance animation with gentle scaling
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Ring animations with gentle scaling and opacity changes
        withAnimation(.easeInOut(duration: ringAnimationDuration).repeatForever(autoreverses: true).delay(0.5)) {
            ringScale = 1.05 // Reduced from 1.1 for gentler effect
            ringOpacity = 1.0
        }
        
        // Text flowing animation
        withAnimation(.easeInOut(duration: textAnimationDuration).delay(0.8)) {
            textAnimationProgress = 1.0
        }
        
        // Smooth continuous hovering animation
        withAnimation(.easeInOut(duration: hoverAnimationDuration).repeatForever(autoreverses: true).delay(1.2)) {
            textHoverOffset = -4.0 // Gentle upward floating
            textHoverScale = 1.03 // Subtle scaling
        }
        
        // Text is now interactive with touch effects
        
        // Navigate to permission popup after delay
        animationTask = Task { @MainActor in
            // Convert animationDuration (seconds) to nanoseconds
            let nanoseconds = UInt64(animationDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            
            // Check if task was cancelled before navigating
            guard !Task.isCancelled else { return }
            
            coordinator.showStartTransfer()
        }
    }
}

// MARK: - Preview

#Preview {
    AnimatedSplashScreenView()
        .environmentObject(AppCoordinator())
        .preferredColorScheme(.dark)
}
