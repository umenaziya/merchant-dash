
import SwiftUI

// MARK: - Navigation Bar Modifier

/// View modifier to attach liquid glass navigation bar to any view
struct LiquidGlassNavigationModifier: ViewModifier {
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
    
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            // Liquid glass navigation bar
            LiquidGlassNavigationBar(
                title: title,
                subtitle: subtitle,
                showBackButton: showBackButton,
                showSettingsButton: showSettingsButton,
                showRefreshButton: showRefreshButton,
                customLeftButton: customLeftButton,
                customRightButton: customRightButton,
                onBackTap: onBackTap,
                onSettingsTap: onSettingsTap,
                onRefreshTap: onRefreshTap
            )
            .zIndex(100)
            
            // Content
            content
        }
    }
}

// MARK: - View Extension

extension View {
    /// Adds a liquid glass navigation bar to the view
    func liquidGlassNavigationBar(
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
    ) -> some View {
        modifier(LiquidGlassNavigationModifier(
            title: title,
            subtitle: subtitle,
            showBackButton: showBackButton,
            showSettingsButton: showSettingsButton,
            showRefreshButton: showRefreshButton,
            customLeftButton: customLeftButton,
            customRightButton: customRightButton,
            onBackTap: onBackTap,
            onSettingsTap: onSettingsTap,
            onRefreshTap: onRefreshTap
        ))
    }
}

