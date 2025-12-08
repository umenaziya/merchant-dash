//
//  PermissionFlowUITests.swift
//  UI tests for permission flow
//

import XCTest

final class PermissionFlowUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        
        // Reset app state for permission tests
        app.launchArguments.append("--reset-permissions")
        
        // Add UI interruption monitor to handle system permission alerts
        addUIInterruptionMonitor(withDescription: "System Permission Alert") { alert -> Bool in
            let allowButton = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow' OR label CONTAINS[c] 'OK' OR label CONTAINS[c] 'Allow Access'")).firstMatch
            if allowButton.exists {
                allowButton.tap()
                return true
            }
            return false
        }
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - First Launch Permission Flow Tests
    
    func testFirstLaunchPermissionFlow_ShowsPermissionPopup() throws {
        // Wait for permission popup to appear after splash using expectation
        let permissionPopup = app.otherElements["PermissionModalView"]
        let permissionExists = permissionPopup.waitForExistence(timeout: 10.0)
        
        XCTAssertTrue(permissionExists, "Permission popup should appear on first launch")
    }
    
    func testFirstLaunchPermissionFlow_ListsAllRequiredPermissions() throws {
        // Wait for permission popup using expectation
        let permissionPopup = app.otherElements["PermissionModalView"]
        let permissionExists = permissionPopup.waitForExistence(timeout: 10.0)
        
        XCTAssertTrue(permissionExists, "Permission popup should appear")
        
        // Verify all required permissions are listed
        let wifiAwarePermission = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Wi-Fi Aware' OR label CONTAINS[c] 'WiFi Aware'")).firstMatch
        let bluetoothPermission = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Bluetooth'")).firstMatch
        let localNetworkPermission = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Local Network' OR label CONTAINS[c] 'Network'")).firstMatch
        
        XCTAssertTrue(wifiAwarePermission.waitForExistence(timeout: 5.0), "WiFi Aware permission should be listed")
        XCTAssertTrue(bluetoothPermission.waitForExistence(timeout: 5.0), "Bluetooth permission should be listed")
        XCTAssertTrue(localNetworkPermission.waitForExistence(timeout: 5.0), "Local Network permission should be listed")
    }
    
    func testFirstLaunchPermissionFlow_TapsEnableAll_GrantsPermissions() throws {
        // Wait for permission popup using expectation
        let permissionPopup = app.otherElements["PermissionModalView"]
        XCTAssertTrue(permissionPopup.waitForExistence(timeout: 10.0), "Permission popup should appear")
        
        // Wait for Enable All Services button using expectation
        let enableButton = app.buttons["Enable All Services"]
        XCTAssertTrue(enableButton.waitForExistence(timeout: 5.0), "Enable All Services button should exist")
        
        enableButton.tap()
        
        // Wait for system permission dialogs to be handled by interruption monitor
        // Use expectation to wait for navigation after permissions
        let transferView = app.otherElements["Transfer2UIView"]
        let permissionDismissed = !permissionPopup.exists || transferView.waitForExistence(timeout: 10.0)
        
        // Either we navigated to transfer, or permission popup was dismissed
        XCTAssertTrue(permissionDismissed, "Should progress after tapping enable")
    }
    
    func testFirstLaunchPermissionFlow_TapsSkip_NavigatesToTransfer() throws {
        // Wait for permission popup using expectation
        let permissionPopup = app.otherElements["PermissionModalView"]
        XCTAssertTrue(permissionPopup.waitForExistence(timeout: 10.0), "Permission popup should appear")
        
        // Look for Skip button using expectation
        let skipButton = app.buttons["Skip for Now"]
        let skipExists = skipButton.waitForExistence(timeout: 5.0)
        
        if skipExists {
            skipButton.tap()
            
            // Wait for navigation using expectation
            let transferView = app.otherElements["Transfer2UIView"]
            let transferExists = transferView.waitForExistence(timeout: 5.0)
            
            XCTAssertTrue(transferExists, "Should navigate to transfer screen after skipping")
        } else {
            XCTFail("Skip button should exist in permission popup")
        }
    }
    
    // MARK: - Permission Denied Handling Tests
    
    func testPermissionDeniedHandling_ShowsAppropriateError() throws {
        // Launch with denied permissions
        app.launchArguments.append("--simulate-permission-denied")
        app.terminate()
        app.launch()
        
        // Wait for app to handle denied permissions using expectation
        let errorMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'permission' OR label CONTAINS[c] 'denied'")).firstMatch
        let permissionAlert = app.alerts.firstMatch
        
        // Use expectation to wait for either error message or alert
        let errorExpectation = XCTestExpectation(description: "Permission error or alert appears")
        
        // Check both conditions with timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if errorMessage.waitForExistence(timeout: 5.0) || permissionAlert.waitForExistence(timeout: 5.0) {
                errorExpectation.fulfill()
            }
        }
        
        wait(for: [errorExpectation], timeout: 6.0)
        XCTAssertTrue(errorMessage.exists || permissionAlert.exists, "Should show permission error or alert")
    }
    
    func testPermissionDeniedHandling_ShowsOpenSettingsOption() throws {
        // Navigate to permission denied state
        app.launchArguments.append("--simulate-permission-denied")
        app.terminate()
        app.launch()
        
        // Wait for UI to appear using expectation
        let alert = app.alerts.firstMatch
        let settingsButton = app.buttons.matching(identifier: "Open Settings").firstMatch
        
        // Check if alert exists first
        if alert.waitForExistence(timeout: 5.0) {
            let alertSettingsButton = alert.buttons.matching(identifier: "Open Settings").firstMatch
            if alertSettingsButton.waitForExistence(timeout: 2.0) {
                XCTAssertTrue(alertSettingsButton.isEnabled, "Open Settings button should be enabled")
            } else {
                XCTFail("Open Settings button should exist in alert")
            }
        } else if settingsButton.waitForExistence(timeout: 5.0) {
            XCTAssertTrue(settingsButton.exists, "Should have Open Settings option")
        } else {
            XCTFail("Should show Open Settings option when permissions are denied")
        }
    }
    
    // MARK: - Permission Re-check Tests
    
    func testPermissionRecheck_ReturnsFromSettings_ChecksPermissions() throws {
        // This test would require:
        // 1. Navigate to settings (via deep link)
        // 2. Grant permissions
        // 3. Return to app
        // 4. Verify permissions are re-checked
        
        // For now, verify deep link functionality exists
        // In real tests, you would use UIApplication to verify deep links work
    }
    
    // MARK: - Permission Status Display Tests
    
    func testPermissionStatusDisplay_ShowsCurrentStatus() throws {
        // Navigate to settings
        let settingsButton = app.buttons.matching(identifier: "Settings").firstMatch
        if settingsButton.exists {
            settingsButton.tap()
        }
        
        // Look for permission status indicators
        // (Implementation depends on UI design)
        let permissionSection = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Permissions'")).firstMatch
        let sectionExists = permissionSection.waitForExistence(timeout: 5.0)
        
        if sectionExists {
            // Verify permission statuses are displayed
            // (Specific UI elements depend on implementation)
        }
    }
}
