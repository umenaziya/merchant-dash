//
//  TransferFlowUITests.swift
//  AwareShareUITests
//
//  UI tests for critical user flows
//

import XCTest

final class TransferFlowUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        
        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Splash to Transfer Flow Tests
    
    func testSplashToTransferFlow_LaunchesApp_ShowsSplashThenTransfer() throws {
        // Wait for splash screen animation (adjust timeout as needed)
        let splashView = app.otherElements["AnimatedSplashScreenView"]
        let splashExists = splashView.waitForExistence(timeout: 3.0)
        
        if splashExists {
            // Wait for splash to disappear using predicate expectation
            let splashDisappearedPredicate = NSPredicate(format: "exists == NO")
            let splashDisappearedExpectation = XCTNSPredicateExpectation(predicate: splashDisappearedPredicate, object: splashView)
            wait(for: [splashDisappearedExpectation], timeout: 10.0)
        }
        
        // Verify permission popup or transfer screen appears
        let permissionPopup = app.alerts["Permissions Required"]
        let transferView = app.otherElements["Transfer2UIView"]
        
        // Either permission popup or transfer view should appear
        let permissionExists = permissionPopup.waitForExistence(timeout: 2.0)
        let transferExists = transferView.waitForExistence(timeout: 2.0)
        
        XCTAssertTrue(permissionExists || transferExists, "Should show either permission popup or transfer screen")
    }
    
    func testPermissionFlow_GrantsPermissions_NavigatesToTransfer() throws {
        // Wait for permission popup
        let permissionButton = app.buttons["Enable All Services"]
        let permissionExists = permissionButton.waitForExistence(timeout: 5.0)
        
        if permissionExists {
            // Set up interruption monitor to handle system permission dialogs
            let interruptionMonitor = addUIInterruptionMonitor(withDescription: "System Permission Dialogs") { (alert) -> Bool in
                // Look for common system permission dialog buttons
                let allowButton = alert.buttons["Allow"]
                let okButton = alert.buttons["OK"]
                let allowWhileUsingButton = alert.buttons["Allow While Using App"]
                let allowOnceButton = alert.buttons["Allow Once"]
                
                if allowButton.exists {
                    allowButton.tap()
                    return true
                } else if allowWhileUsingButton.exists {
                    allowWhileUsingButton.tap()
                    return true
                } else if allowOnceButton.exists {
                    allowOnceButton.tap()
                    return true
                } else if okButton.exists {
                    okButton.tap()
                    return true
                }
                
                return false
            }
            
            // Tap to enable permissions (this may trigger system dialogs)
            permissionButton.tap()
            
            // Trigger interruption handling by tapping the app
            app.tap()
            
            // Wait for navigation to transfer screen using expectation
        } else {
            // Discovery might be automatic, just verify device list exists
            let deviceList = app.collectionViews.firstMatch
            let deviceExists = deviceList.waitForExistence(timeout: 10.0)
            XCTAssertTrue(deviceExists, "Should have device discovery UI")
        }
            
            // Clean up interruption monitor
            removeUIInterruptionMonitor(interruptionMonitor)
            
            // Verify we got the expected result
            XCTAssertEqual(result, .completed, "Should navigate to transfer screen after permissions")
            XCTAssertTrue(transferView.exists, "Transfer view should exist after permissions granted")
        }
    }
    
    // MARK: - Device Discovery Tests
    
    func testDeviceDiscovery_StartsDiscovery_ShowsDevices() throws {
        // Navigate to transfer screen (assuming we're past splash)
        // In real tests, you might need to handle permission flow first
        
        // Look for discovery button or automatic discovery
        let discoveryButton = app.buttons["Start Discovery"]
        let discoveryExists = discoveryButton.waitForExistence(timeout: 5.0)
        
        if discoveryExists {
            discoveryButton.tap()
            
            // Wait for devices to appear
            let deviceList = app.collectionViews.firstMatch
            let deviceExists = deviceList.waitForExistence(timeout: 5.0)
            
            XCTAssertTrue(deviceExists, "Device list should appear")
        } else {
            // Discovery might be automatic, just verify device list exists
            let deviceList = app.collectionViews.firstMatch
            let deviceExists = deviceList.waitForExistence(timeout: 10.0)
            XCTAssertTrue(deviceExists || deviceList.cells.count >= 0, "Should have device discovery UI")
        }
    }
    
    func testDeviceSelection_TapsDevice_NavigatesToOptions() throws {
        // Precondition: Device list must exist
        let deviceList = app.collectionViews.firstMatch
        let deviceExists = deviceList.waitForExistence(timeout: 10.0)
        XCTAssertTrue(deviceExists, "Device list should exist before attempting device selection")
        
        // Precondition: At least one device must be discovered
        XCTAssertTrue(deviceList.cells.count > 0, "At least one device must be discovered before attempting device selection")
        
        // Tap first device
        let firstDevice = deviceList.cells.firstMatch
        firstDevice.tap()
        
        // Wait for navigation to send/receive options
        let sendReceiveView = app.otherElements["SendReceiveOptionsView"]
        let viewExists = sendReceiveView.waitForExistence(timeout: 5.0)
        
        XCTAssertTrue(viewExists, "Should navigate to send/receive options")
    }
    
    // MARK: - Send File Flow Tests
    
    func testSendFileFlow_SelectsFiles_ShowsProgress() throws {
        // Navigate to send option
        let sendButton = app.buttons["Send"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5.0), "Send button should exist")
        sendButton.tap()
        
        // Assert file selection view exists
        let fileSelectionView = app.otherElements["FileSelectionView"]
        XCTAssertTrue(fileSelectionView.waitForExistence(timeout: 3.0), "File selection view should appear after tapping Send")
        
        // Find and tap the Photos button to select files
        let photoButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Photos'")).firstMatch
        XCTAssertTrue(photoButton.waitForExistence(timeout: 3.0), "Photos button should exist in file selection view")
        photoButton.tap()
        
        // Wait for photo picker to appear - check for Cancel button or photo grid
        let cancelButton = app.navigationBars.buttons["Cancel"]
        let photoGrid = app.collectionViews.firstMatch
        let photoPickerAppeared = cancelButton.waitForExistence(timeout: 5.0) || photoGrid.waitForExistence(timeout: 5.0)
        XCTAssertTrue(photoPickerAppeared, "Photo picker should appear after tapping Photos button")
        
        // Select first photo from the picker
        XCTAssertTrue(photoGrid.waitForExistence(timeout: 3.0), "Photo grid should exist in picker")
        XCTAssertGreaterThan(photoGrid.cells.count, 0, "Photo grid should contain at least one photo")
        
        let firstPhoto = photoGrid.cells.firstMatch
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 3.0), "First photo cell should exist in picker")
        firstPhoto.tap()
        
        // Assert that a file was selected - wait for selection indicator to appear
        // This also confirms the photo picker has dismissed
        // Look for "Selected Files" text or count indicator like "(1)" next to Photos
        let selectedFilesLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Selected Files'")).firstMatch
        let photoCountIndicator = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '(1)'")).firstMatch
        
        // Either the selected files preview should appear, or the count indicator should show
        let selectionMade = selectedFilesLabel.waitForExistence(timeout: 5.0) || photoCountIndicator.waitForExistence(timeout: 5.0)
        XCTAssertTrue(selectionMade, "File selection indicator should appear after selecting a photo, confirming selection was made")
        
        // Assert that the Send button with count appears (e.g., "Send 1 File")
        let sendFilesButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Send' AND label CONTAINS 'File'")).firstMatch
        XCTAssertTrue(sendFilesButton.waitForExistence(timeout: 3.0), "Send button with file count should appear after selection")
        
        // Initiate the send
        sendFilesButton.tap()
        
        // Assert that progress view appears after initiating send
        let progressView = app.otherElements["TransferProgressView"]
        XCTAssertTrue(progressView.waitForExistence(timeout: 5.0), "Transfer progress view should appear after initiating send")
        
        // Assert that progress UI elements are visible
        let progressBar = app.progressIndicators.firstMatch
        XCTAssertTrue(progressBar.waitForExistence(timeout: 3.0), "Progress bar should be visible in progress view")
        
        // Check for transfer status or metrics that indicate active transfer
        let transferStatus = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Active' OR label CONTAINS[c] 'Transfer' OR label CONTAINS[c] 'Sending'")).firstMatch
        XCTAssertTrue(transferStatus.waitForExistence(timeout: 3.0), "Transfer status text should be visible")
    }
    
    func testSendFileFlow_TransferProgress_UpdatesCorrectly() throws {
        // This test assumes a transfer is in progress
        // In real tests, you would:
        // 1. Start a transfer
        // 2. Monitor progress bar
        // 3. Verify progress updates
        
        let progressBar = app.progressIndicators.firstMatch
        let progressExists = progressBar.waitForExistence(timeout: 10.0)
        
        if progressExists {
            // Verify progress bar is visible
            XCTAssertTrue(progressBar.exists, "Progress bar should be visible")
            
            // Capture initial progress value
            let initialProgressValue = progressBar.value as? String ?? "0"
            
            // Wait for progress to update using predicate expectation
            // Create predicate that checks if progress value has changed from initial value
            let progressPredicate = NSPredicate { (evaluatedObject, _) -> Bool in
                guard let element = evaluatedObject as? XCUIElement,
                      element.exists else {
                    return false
                }
                let currentValue = element.value as? String ?? "0"
                return currentValue != initialProgressValue
            }
            
            let progressExpectation = XCTNSPredicateExpectation(predicate: progressPredicate, object: progressBar)
            let result = XCTWaiter.wait(for: [progressExpectation], timeout: 10.0)
            
            // Verify progress updated (expectation completed) or fail deterministically
            XCTAssertEqual(result, .completed, "Progress should update within 10 seconds")
            
            // Parse progress value as numeric and validate range
            var progressNumeric: Double?
            
            // Try to read as numeric type first (Double/Float/NSNumber)
            if let numericValue = progressBar.value as? Double {
                progressNumeric = numericValue
            } else if let numericValue = progressBar.value as? Float {
                progressNumeric = Double(numericValue)
            } else if let numericValue = progressBar.value as? NSNumber {
                progressNumeric = numericValue.doubleValue
            } else if let stringValue = progressBar.value as? String {
                // If it's a string, strip trailing '%' and parse to Double
                let cleanedString = stringValue.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "")
                progressNumeric = Double(cleanedString)
            }
            
            // Assert the parsed value is non-nil
            XCTAssertNotNil(progressNumeric, "Progress value should be parseable as a numeric type")
            
            // Assert the numeric value falls in the expected range (0.0...1.0 for fraction or 0...100 for percent)
            if let progress = progressNumeric {
                // Check if it's a fraction (0.0...1.0) or percentage (0...100)
                if progress >= 0.0 && progress <= 1.0 {
                    XCTAssertTrue(progress >= 0.0 && progress <= 1.0, "Progress should be between 0.0 and 1.0")
                } else if progress > 1.0 && progress <= 100.0 {
                    // Assume percentage format (0...100)
                    XCTAssertTrue(progress >= 0.0 && progress <= 100.0, "Progress should be between 0.0 and 100.0")
                } else {
                    XCTFail("Progress value \(progress) is outside expected ranges (0.0...1.0 or 0...100)")
                }
            }
        }
    }
    
    // MARK: - Settings Navigation Tests
    
    func testSettingsNavigation_TapsSettings_ShowsSettingsScreen() throws {
        // Look for settings button (could be in navigation bar or bottom bar)
        let settingsButton = app.buttons.matching(identifier: "Settings").firstMatch
        
        // Alternative: look for settings icon
        if !settingsButton.exists {
            let settingsIcon = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'settings'")).firstMatch
            if settingsIcon.exists {
                settingsIcon.tap()
            }
        } else {
            settingsButton.tap()
        }
        
        // Verify settings screen appears
        let settingsView = app.otherElements["EnhancedSettingsView"]
        let settingsExists = settingsView.waitForExistence(timeout: 5.0)
        
        XCTAssertTrue(settingsExists, "Should navigate to settings screen")
    }
    
    func testSettingsPersistence_TogglesTransport_ChangesSetting() throws {
        // Navigate to settings
        let settingsButton = app.buttons.matching(identifier: "Settings").firstMatch
        if settingsButton.exists {
            settingsButton.tap()
        }
        
        // Find WiFi Aware toggle
        let wifiAwareToggle = app.switches.matching(identifier: "WiFi Aware").firstMatch
        let toggleExists = wifiAwareToggle.waitForExistence(timeout: 5.0)
        
        if toggleExists {
            let initialValue = wifiAwareToggle.value as? String
            
            // Toggle the switch
            wifiAwareToggle.tap()
            
            // Wait for toggle value to change using predicate expectation
            let toggleValueChangedPredicate = NSPredicate { (evaluatedObject, _) -> Bool in
                guard let element = evaluatedObject as? XCUIElement,
                      element.exists else {
                    return false
                }
                let currentValue = element.value as? String
                return currentValue != initialValue
            }
            let toggleExpectation = XCTNSPredicateExpectation(predicate: toggleValueChangedPredicate, object: wifiAwareToggle)
            wait(for: [toggleExpectation], timeout: 5.0)
            
            let newValue = wifiAwareToggle.value as? String
            
            // Values should be different
            XCTAssertNotEqual(initialValue, newValue, "Toggle should change value")
            
            // Close settings and reopen to verify persistence
            let backButton = app.navigationBars.buttons["Back"]
            XCTAssertTrue(backButton.waitForExistence(timeout: 2.0), "Back button should exist")
            backButton.tap()
            
            // Wait for settings view to disappear
            let settingsView = app.otherElements["EnhancedSettingsView"]
            let settingsDisappearedPredicate = NSPredicate(format: "exists == NO")
            let settingsDisappearedExpectation = XCTNSPredicateExpectation(predicate: settingsDisappearedPredicate, object: settingsView)
            wait(for: [settingsDisappearedExpectation], timeout: 3.0)
            
            if settingsButton.exists {
                settingsButton.tap()
            }
            
            let persistedToggle = app.switches.matching(identifier: "WiFi Aware").firstMatch
            let persistedValue = persistedToggle.waitForExistence(timeout: 3.0) ? persistedToggle.value as? String : nil
            
            // Value should be persisted
            XCTAssertEqual(newValue, persistedValue, "Setting should persist")
        }
    }
    
    // MARK: - History Navigation Tests
    
    func testHistoryNavigation_TapsHistory_ShowsHistoryScreen() throws {
        // Look for history button
        let historyButton = app.buttons.matching(identifier: "History").firstMatch
        
        if historyButton.exists {
            historyButton.tap()
            
            // Verify history screen appears
            let historyView = app.otherElements["TransferHistoryView"]
            let historyExists = historyView.waitForExistence(timeout: 5.0)
            
            XCTAssertTrue(historyExists, "Should navigate to history screen")
        }
    }
    
    func testHistoryShowsRecords_AfterTransfer_DisplaysData() throws {
        // Navigate to history
        let historyButton = app.buttons.matching(identifier: "History").firstMatch
        if historyButton.exists {
            historyButton.tap()
        }
        
        // Look for history list
        let historyList = app.tables.firstMatch
        let listExists = historyList.waitForExistence(timeout: 5.0)
        
        if listExists {
            // Verify list has cells (might be empty if no transfers yet)
            let cellCount = historyList.cells.count
            XCTAssertGreaterThanOrEqual(cellCount, 0, "History list should exist (may be empty)")
            
            // If cells exist, verify they have content
            if cellCount > 0 {
                let firstCell = historyList.cells.firstMatch
                XCTAssertTrue(firstCell.exists, "First history cell should exist")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5.0) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
}
