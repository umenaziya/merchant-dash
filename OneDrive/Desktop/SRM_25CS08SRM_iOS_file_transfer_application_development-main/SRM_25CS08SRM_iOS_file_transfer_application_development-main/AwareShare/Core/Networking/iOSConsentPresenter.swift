
import Foundation
import UIKit
import OSLog

/// iOS implementation of ConsentPresenter using UIKit
@MainActor
class iOSConsentPresenter: ConsentPresenter {
    
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "iOSConsentPresenter")
    
    func presentFileTransferConsent(
        fileName: String,
        fileSize: Int64,
        from device: ConnectedDevice,
        respond: @escaping (Bool, Bool) -> Void
    ) {
        // Create and show consent alert
        let alert = UIAlertController(
            title: "Incoming File",
            message: "\(device.name) wants to send you:\n\n\(fileName)\nSize: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))\n\nDo you want to accept this file?",
            preferredStyle: .alert
        )
        
        // Reject action
        alert.addAction(UIAlertAction(title: "Reject", style: .cancel) { _ in
            respond(false, false)
        })
        
        // Accept action
        alert.addAction(UIAlertAction(title: "Accept", style: .default) { _ in
            respond(true, false)
        })
        
        // Accept and Trust action
        alert.addAction(UIAlertAction(title: "Accept & Trust", style: .default) { _ in
            // Trust the device using its ID
            SettingsService.shared.addTrustedDevice(device.id)
            respond(true, true)
        })
        
        // Present the alert on the topmost view controller
        // Ensure we're on the main thread and handle all failure cases
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                respond(false, false)
                return
            }
            
            // Attempt to get UIWindowScene
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                self.logger.error("Failed to present consent alert: No UIWindowScene available")
                respond(false, false)
                return
            }
            
            // Attempt to get window and root view controller
            guard let window = windowScene.windows.first else {
                self.logger.error("Failed to present consent alert: No window available in UIWindowScene")
                respond(false, false)
                return
            }
            
            guard let rootViewController = window.rootViewController else {
                self.logger.error("Failed to present consent alert: No rootViewController available")
                respond(false, false)
                return
            }
            
            // Find the topmost presented view controller
            var topController = rootViewController
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            
            // Present the alert with completion handler to ensure callback is invoked
            topController.present(alert, animated: true) {
                // Presentation completed successfully
                // The respond callback will be invoked by the alert action handlers
            }
        }
    }
}
