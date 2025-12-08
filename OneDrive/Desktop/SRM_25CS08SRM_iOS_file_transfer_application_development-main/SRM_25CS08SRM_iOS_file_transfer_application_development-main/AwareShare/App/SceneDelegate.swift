import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        
        // Create the main app view with user's preferred color scheme (nil = system default)
        let contentView: AnyView = {
            let baseView = AppCoordinatorView()
            if let colorScheme = SettingsService.shared.preferredColorScheme {
                return AnyView(baseView.preferredColorScheme(colorScheme))
            } else {
                return AnyView(baseView)
            }
        }()
        
        // Set the root view controller with user interface style override
        // This ensures both SwiftUI and UIKit components respect the preference
        let hostingController = UIHostingController(rootView: contentView)
        if let interfaceStyle = SettingsService.shared.preferredUserInterfaceStyle {
            hostingController.overrideUserInterfaceStyle = interfaceStyle
        }
        // If nil, don't set overrideUserInterfaceStyle - this allows system default
        
        window?.rootViewController = hostingController
        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
    }
}
