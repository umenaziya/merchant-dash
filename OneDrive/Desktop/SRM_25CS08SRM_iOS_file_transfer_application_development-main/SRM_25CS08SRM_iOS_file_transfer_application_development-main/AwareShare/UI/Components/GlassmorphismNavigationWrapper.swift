import SwiftUI


struct GlassmorphismNavigationWrapper<Content: View>: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @ViewBuilder let content: Content
    
    // Tab mapping to AppScreen
    private var tabToScreen: [AppScreen] {
        [.transfer2, .history, .airDrop, .settings]
    }
    
    private var currentTabIndex: Int {
        tabToScreen.firstIndex(of: coordinator.currentScreen) ?? 0
    }
    
    var body: some View {
        content
            .glassmorphismTabBar(
                tabs: [
                    TabItem(title: "Home", iconName: "antenna.radiowaves.left.and.right"),
                    TabItem(title: "History", iconName: "clock.fill"),
                    TabItem(title: "AirDrop", iconName: "airplayaudio"),
                    TabItem(title: "Settings", iconName: "gearshape.fill")
                ],
                selection: Binding(
                    get: { currentTabIndex },
                    set: { newTab in
                        handleTabSelection(newTab)
                    }
                )
            )
    }
    
    private func handleTabSelection(_ tabIndex: Int) {
        guard tabIndex < tabToScreen.count else { return }
        
        let targetScreen = tabToScreen[tabIndex]
        
        switch targetScreen {
        case .transfer2:
            coordinator.showTransfer2()
        case .history:
            coordinator.showHistory()
        case .airDrop:
            coordinator.showAirDrop()
        case .settings:
            coordinator.showSettings()
        default:
            break
        }
    }
}

// MARK: - View Extension

extension View {
    /// Adds glassmorphism navigation bar with automatic coordinator integration
    func withGlassmorphismNavigation() -> some View {
        GlassmorphismNavigationWrapper {
            self
        }
    }
}

