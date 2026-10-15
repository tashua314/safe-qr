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
    func testApprovedScanAndHistoryResumeAfterBrowserCloses() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["設定"].waitForExistence(timeout: 10))
        app.buttons["設定"].tap()
        app.segmentedControls.buttons["標準"].tap()
        if app.switches.firstMatch.value as? String != "0" { app.switches.firstMatch.tap() }
        app.buttons["閉じる"].tap()
        app.buttons["注意URL テスト"].tap()
        XCTAssertTrue(app.buttons["続行する"].waitForExistence(timeout: 5))
        app.buttons["続行する"].tap()
        closeBrowser(app)
        app.buttons["注意URL テスト"].tap()
        XCTAssertTrue(app.buttons["やめる（推奨）"].waitForExistence(timeout: 5))
        app.buttons["やめる（推奨）"].tap()
        app.buttons["履歴"].tap()
        let row = app.staticTexts["paypal.example.invalid"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["続行する"].waitForExistence(timeout: 5))
        app.buttons["続行する"].tap()
        closeBrowser(app)
        row.tap()
        XCTAssertTrue(app.buttons["やめる（推奨）"].waitForExistence(timeout: 5))
        app.buttons["やめる（推奨）"].tap()
        app.buttons["閉じる"].tap()
    }

    @MainActor
    func testWarningLayoutEvidence() {
        let app = XCUIApplication()
        for (orientation, name) in [(UIDeviceOrientation.portrait, "Portrait details"), (.landscapeLeft, "Landscape details")] {
            XCUIDevice.shared.orientation = orientation
            app.launch()
            XCTAssertTrue(app.buttons["設定"].waitForExistence(timeout: 10))
            app.buttons["設定"].tap()
            app.segmentedControls.buttons["標準"].tap()
            if app.switches.firstMatch.value as? String != "0" { app.switches.firstMatch.tap() }
            app.buttons["閉じる"].tap()
            app.buttons["危険URL テスト"].tap()
            XCTAssertTrue(app.staticTexts["危険な可能性があります"].waitForExistence(timeout: 5))
            let toggle = app.buttons["詳細を確認 ▼"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            let scroll = app.scrollViews["開封確認"]
            for _ in 0 ..< 4 where !toggle.isHittable {
                scroll.swipeUp()
            }
            XCTAssertTrue(toggle.isHittable)
            toggle.tap()
            let block = app.buttons["ブロックする（推奨）"]
            for _ in 0 ..< 5 where !block.isHittable {
                scroll.swipeUp()
            }
            XCTAssertTrue(block.isHittable)
            capture(app, name: name)
            block.tap()
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testHistoryDeleteConfirmationAndEmptyState() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["設定"].waitForExistence(timeout: 10))
        app.buttons["設定"].tap()
        app.segmentedControls.buttons["標準"].tap()
        if app.switches.firstMatch.value as? String != "0" { app.switches.firstMatch.tap() }
        app.buttons["閉じる"].tap()
        app.buttons["危険URL テスト"].tap()
        XCTAssertTrue(app.buttons["ブロックする（推奨）"].waitForExistence(timeout: 5))
        app.buttons["ブロックする（推奨）"].tap()
        app.buttons["履歴"].tap()
        let record = app.staticTexts["xn--e1afmkfd-paypal.example.invalid"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        app.buttons["編集"].tap()
        app.buttons["すべて削除"].tap()
        let alert = app.alerts["すべて削除"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["すべての履歴を削除しますか？\nこの操作は取り消せません。"].exists)
        capture(app, name: "History delete confirmation")
        alert.buttons["キャンセル"].tap()
        XCTAssertTrue(record.exists, "キャンセルでは履歴を残す")
        app.buttons["すべて削除"].tap()
        alert.buttons["削除"].tap()
        XCTAssertTrue(record.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["編集"].isEnabled)
        capture(app, name: "History empty after deletion")
        app.buttons["閉じる"].tap()
        app.buttons["履歴"].tap()
        XCTAssertFalse(record.exists, "再表示後も削除を保持する")
        app.buttons["閉じる"].tap()
    }

    @MainActor
    private func closeBrowser(_ app: XCUIApplication) {
        let done = app.otherElements["TopBrowserBar"].buttons.matching(NSPredicate(format: "label IN %@", ["Done", "完了", "閉じる", "Close"]))
            .firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        // iOS26のSafariはURL欄とAX領域が重なるため、角ではなく丸い閉じるボタンの中心を押す。
        done.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 10))
    }

    @MainActor
    private func prepareNonDefaultSettings(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["設定"].waitForExistence(timeout: 10))
        app.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textViews["外部チェックの説明"].exists, "利用開始前にGoogle出典と精度の限界を表示する")
        app.segmentedControls.buttons["強"].tap()
        if app.switches.firstMatch.value as? String != "1" { app.switches.firstMatch.tap() }
        app.buttons["閉じる"].tap()
    }

    @MainActor
    private func capture(_: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) { XCUIApplication().launch() }
    }
}
