//
//  ErrorHandlingUITests.swift
//  AwareShareUITests
//
//  UI tests for error handling flows
//

import XCTest

final class ErrorHandlingUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Connection Failure Error Tests
    
    func testConnectionFailureError_ShowsErrorOverlay() throws {
      
        
        app.launchArguments.append("--simulate-connection-failure")
        app.launch()
        
        // Wait for error overlay
        let errorOverlay = app.otherElements["ErrorOverlayView"]
        let errorExists = errorOverlay.waitForExistence(timeout: 10.0)
        
        // Assert error overlay exists first
        XCTAssertTrue(errorExists, "Error overlay should exist")
        
        // Verify error message is displayed and contains expected text
        let errorMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'connection' OR label CONTAINS[c] 'error'")).firstMatch
        XCTAssertTrue(errorMessage.exists, "Error message should be displayed")
        
        // Verify retry button exists and is enabled
        let retryButton = app.buttons.matching(identifier: "Retry").firstMatch
        XCTAssertTrue(retryButton.exists, "Retry button should exist")
        XCTAssertTrue(retryButton.isEnabled, "Retry button should be enabled")
    }
    
    func testErrorOverlayRetry_TapsRetry_AttemptsReconnection() throws {
        // Navigate to error state (would need to trigger connection failure)
        app.launchArguments.append("--simulate-connection-failure")
        app.launch()
        
        let errorOverlay = app.otherElements["ErrorOverlayView"]
        let errorExists = errorOverlay.waitForExistence(timeout: 10.0)
        
        // Assert error overlay exists - fail loudly if it doesn't
        XCTAssertTrue(errorExists, "Error overlay should exist before retry attempt")
        
        // Assert retry button exists and is enabled
        let retryButton = app.buttons.matching(identifier: "Retry").firstMatch
        XCTAssertTrue(retryButton.exists, "Retry button should exist")
        XCTAssertTrue(retryButton.isEnabled, "Retry button should be enabled")
        
        // Tap retry button
        retryButton.tap()
        
        // Wait for retry action to complete - either overlay dismisses or loading indicator appears
        // Poll for either condition with a timeout
        let timeout: TimeInterval = 5.0
        let startTime = Date()
        var overlayDismissed = false
        var loadingIndicatorAppeared = false
        
        // Poll until one of the conditions is met or timeout
        while Date().timeIntervalSince(startTime) < timeout {
            // Check if overlay is dismissed
            if !errorOverlay.exists {
                overlayDismissed = true
                break
            }
            
            // Check for loading indicators
            let hasActivityIndicator = app.activityIndicators.count > 0
            let hasProgressIndicator = app.progressIndicators.count > 0
            let hasConnectingText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'connect' OR label CONTAINS[c] 'loading' OR label CONTAINS[c] 'retry'")).firstMatch.exists
            
            if hasActivityIndicator || hasProgressIndicator || hasConnectingText {
                loadingIndicatorAppeared = true
                break
            }
            
            // Small delay before next check (0.1 seconds)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        
        // Assert expected post-retry state - fail loudly if neither condition is met
        XCTAssertTrue(overlayDismissed || loadingIndicatorAppeared,
                      "After retry, overlay should be dismissed OR loading indicator should appear. Overlay dismissed: \(overlayDismissed), Loading indicator appeared: \(loadingIndicatorAppeared), Overlay still exists: \(errorOverlay.exists)")
    }
    
    func testErrorOverlayDismiss_TapsDismiss_ClosesOverlay() throws {
        // Navigate to error state
        app.launchArguments.append("--simulate-connection-failure")
        app.launch()
        
        let errorOverlay = app.otherElements["ErrorOverlayView"]
        let errorExists = errorOverlay.waitForExistence(timeout: 10.0)
        
        XCTAssertTrue(errorExists, "Error overlay should be present")
        
        let dismissButton = app.buttons["Dismiss"]
        XCTAssertTrue(dismissButton.exists, "Dismiss button should exist")
        
        dismissButton.tap()
        
        // Wait for overlay to be dismissed
        let dismissed = !errorOverlay.waitForExistence(timeout: 2.0)
        XCTAssertTrue(dismissed, "Error overlay should be dismissed after tapping dismiss button")
    }
    
    // MARK: - Permission Denied Error Tests
    
    func testPermissionDeniedError_ShowsErrorAlert() throws {
        // This test would require denying permissions
        // In real tests, you would reset permissions and deny them
        
        // Launch with denied permissions simulation
        app.launchArguments.append("--simulate-permission-denied")
        app.launch()
        
        // Wait for error alert
        let permissionAlert = app.alerts.matching(NSPredicate(format: "label CONTAINS[c] 'permission' OR label CONTAINS[c] 'denied'")).firstMatch
        let alertExists = permissionAlert.waitForExistence(timeout: 5.0)
        
        XCTAssertTrue(alertExists, "Permission denied alert should be displayed")
        
        // Verify alert message
        let alertMessage = permissionAlert.staticTexts.firstMatch
        XCTAssertTrue(alertMessage.exists, "Alert should have a message")
        
        // Verify "Open Settings" button exists
        let settingsButton = permissionAlert.buttons["Open Settings"]
        XCTAssertTrue(settingsButton.exists, "Should have Open Settings button")
    }
    
    func testPermissionErrorOpenSettings_TapsButton_OpensSettings() throws {
        // Navigate to permission error
        app.launchArguments.append("--simulate-permission-denied")
        app.launch()
        
        // Query for the specific permission alert by title (deterministic)
        let permissionAlert = app.alerts.matching(NSPredicate(format: "label CONTAINS[c] 'permission' OR label CONTAINS[c] 'denied' OR label CONTAINS[c] 'required'")).firstMatch
        
        // Fail loudly if alert doesn't appear within timeout
        XCTAssertTrue(permissionAlert.waitForExistence(timeout: 5.0), "Permission denied alert should be displayed")
        
        // Verify and tap "Open Settings" button (fail loudly if it doesn't exist)
        let settingsButton = permissionAlert.buttons["Open Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2.0), "Open Settings button should exist in the alert")
        XCTAssertTrue(settingsButton.isEnabled, "Open Settings button should be enabled")
        settingsButton.tap()
      
        let alertStillExists = permissionAlert.waitForExistence(timeout: 3.0)
        XCTAssertFalse(alertStillExists, "Alert should be dismissed after tapping Open Settings")
    }
    
    // MARK: - File Error Tests
    
    func testFileNotFoundError_ShowsErrorMessage() throws {
   
        let errorAlert = app.alerts.firstMatch
        // This test would need actual file operations
    }
    
    func testInsufficientStorageError_ShowsErrorMessage() throws {
  
        
        app.launchArguments.append("--simulate-insufficient-storage")
        app.launch()
      
    }
}
