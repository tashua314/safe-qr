import XCTest

final class CameraPermissionUITests: XCTestCase {
    @MainActor
    func testDeniedCameraStillAllowsHistoryAndSettings() throws {
        guard ProcessInfo.processInfo.environment["SAFEQR_TEST_CAMERA_DENIED"] == "1" else {
            throw XCTSkip("専用Simulatorでcameraをrevokeした個別検証として実行する")
        }
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        let alert = app.alerts["カメラへのアクセス許可が必要です"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "Camera permission denied"
        capture.lifetime = .keepAlways
        add(capture)
        alert.buttons["キャンセル"].tap()
        app.buttons["設定"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
        app.buttons["閉じる"].tap()
        app.buttons["履歴"].tap()
        XCTAssertTrue(app.navigationBars["履歴"].waitForExistence(timeout: 5))
        app.buttons["閉じる"].tap()
    }
}
