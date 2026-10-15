import XCTest

final class SafeQRUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSettingsHistoryAndMockScanWarnings() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        prepareNonDefaultSettings(app)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["設定"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["注意URL テスト"].waitForExistence(timeout: 10))
        capture(app, name: "Scanner")

        app.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["外部安全性チェック"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["強"].isSelected, "再起動後も強設定が保存される")
        let externalSwitch = app.switches.firstMatch
        XCTAssertEqual(externalSwitch.value as? String, "1")
        app.segmentedControls.buttons["標準"].tap()
        externalSwitch.tap()
        XCTAssertTrue(app.segmentedControls.buttons["標準"].isSelected)
        XCTAssertEqual(externalSwitch.value as? String, "0")
        capture(app, name: "Settings")
        app.buttons["閉じる"].tap()

        app.buttons["注意URL テスト"].tap()
        XCTAssertTrue(app.staticTexts["不審な可能性があります"].waitForExistence(timeout: 5))
        capture(app, name: "Caution warning")
        app.buttons["やめる（推奨）"].tap()
        XCTAssertTrue(app.buttons["危険URL テスト"].waitForExistence(timeout: 5))

        app.buttons["危険URL テスト"].tap()
        XCTAssertTrue(app.staticTexts["危険な可能性があります"].waitForExistence(timeout: 5))
        capture(app, name: "Danger warning")
        app.buttons["ブロックする（推奨）"].tap()

        app.buttons["履歴"].tap()
        XCTAssertTrue(app.navigationBars["履歴"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["paypal.example.invalid"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["xn--e1afmkfd-paypal.example.invalid"].firstMatch.exists)
        capture(app, name: "History after mock scans")
        app.staticTexts["xn--e1afmkfd-paypal.example.invalid"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["危険な可能性があります"].waitForExistence(timeout: 5))
        capture(app, name: "History revisit warning")
        app.buttons["ブロックする（推奨）"].tap()
        app.buttons["閉じる"].tap()
        XCTAssertTrue(app.buttons["注意URL テスト"].exists)

        // CIはAPIキー未設定。未照会をsafeとして自動開封しないことを画面でも確認する。
        app.buttons["設定"].tap()
        if app.switches.firstMatch.value as? String != "1" { app.switches.firstMatch.tap() }
        app.buttons["閉じる"].tap()
        app.buttons["安全URL テスト"].tap()
        XCTAssertTrue(app.staticTexts["外部チェックは未確認です"].waitForExistence(timeout: 10))
        capture(app, name: "Unverified external warning")
        app.buttons["やめる（推奨）"].tap()
        app.buttons["設定"].tap()
        if app.switches.firstMatch.value as? String != "0" { app.switches.firstMatch.tap() }
        app.buttons["閉じる"].tap()
    }

    @MainActor
    private func prepareNonDefaultSettings(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["設定"].waitForExistence(timeout: 10))
        app.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["強"].tap()
        if app.switches.firstMatch.value as? String != "1" { app.switches.firstMatch.tap() }
        app.buttons["閉じる"].tap()
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) { XCUIApplication().launch() }
    }
}
