import Combine
@testable import SafeQR
import UIKit
import XCTest

final class ScannerLayoutTests: XCTestCase {
    @MainActor
    func testIdleScannerLayoutSettlesWithoutReschedulingItself() async throws {
        let service = InertScanner()
        let controller = LayoutCountingScanner(qrScannerService: service)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)
        let settledPasses = controller.layoutPasses
        XCTAssertGreaterThan(settledPasses, 0)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertLessThanOrEqual(
            controller.layoutPasses - settledPasses, 1,
            "待機画面はレイアウト完了を起点に次のレイアウトを要求し続けない"
        )
    }

    @MainActor
    func testPreviewFrameFollowsViewportBoundsChange() async throws {
        let service = InertScanner()
        let manager = ScannerUIManager()
        let controller = LayoutCountingScanner(uiManager: manager, qrScannerService: service)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)
        let portraitWidth = manager.cameraPreviewView.bounds.width
        XCTAssertGreaterThan(portraitWidth, 0)
        XCTAssertEqual(service.lastPreviewFrame, manager.cameraPreviewView.bounds)

        window.frame = CGRect(x: 0, y: 0, width: 844, height: 390)
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertGreaterThan(manager.cameraPreviewView.bounds.width, portraitWidth)
        XCTAssertEqual(service.lastPreviewFrame, manager.cameraPreviewView.bounds)
    }

    private final class LayoutCountingScanner: ScannerViewController {
        private(set) var layoutPasses = 0

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            layoutPasses += 1
        }
    }

    private final class InertScanner: QRScannerServiceProtocol {
        let scanResult = Empty<String, Never>(completeImmediately: false).eraseToAnyPublisher()
        private(set) var lastPreviewFrame: CGRect?

        func requestCameraPermission(completion: @escaping (Bool) -> Void) {
            completion(true)
        }

        func setupCaptureSession(in _: UIView) {}
        func startScanning() {}
        func stopScanning() {}
        func setTorchEnabled(_: Bool) {}
        func getPreviewLayer() -> CALayer? {
            nil
        }

        func updatePreviewLayer(frame: CGRect) {
            lastPreviewFrame = frame
        }
    }
}
