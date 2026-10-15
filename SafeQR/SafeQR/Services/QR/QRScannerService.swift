import AVFoundation
import Combine
import UIKit

protocol QRScannerServiceDelegate: AnyObject {
    func qrScannerService(_ service: QRScannerService, didDetectQRCode code: String)
    func qrScannerService(_ service: QRScannerService, didFailWithError error: QRScannerServiceError)
}

enum QRScannerServiceError: Error {
    case cameraNotAvailable
    case permissionDenied
    case sessionSetupFailed

    var localizedDescription: String {
        switch self {
        case .cameraNotAvailable:
            return "カメラが利用できません"
        case .permissionDenied:
            return "カメラの使用許可が必要です"
        case .sessionSetupFailed:
            return "カメラの設定に失敗しました"
        }
    }
}

class QRScannerService: NSObject {
    weak var delegate: QRScannerServiceDelegate?

    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var isScanning = false

    // MARK: - Published Properties for Protocol Conformance

    private let scanResultSubject = PassthroughSubject<String, Never>()

    var scanResult: AnyPublisher<String, Never> {
        return scanResultSubject.eraseToAnyPublisher()
    }

    override init() {
        super.init()
    }

    func setupCaptureSession(in view: UIView) {
        #if targetEnvironment(simulator)
            // シミュレータではモックカメラを設定
            setupMockCamera(in: view)
        #else
            _requestCameraPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureCameraSession(in: view)
                    } else {
                        guard let self else { return }
                        self.delegate?.qrScannerService(self, didFailWithError: .permissionDenied)
                    }
                }
            }
        #endif
    }

    #if targetEnvironment(simulator)
        private func setupMockCamera(in view: UIView) {
            // シミュレータ用のプレースホルダービュー
            let mockView = UIView()
            mockView.backgroundColor = .black
            mockView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(mockView)

            // mockView を view に完全にフィットさせる
            NSLayoutConstraint.activate([
                mockView.topAnchor.constraint(equalTo: view.topAnchor),
                mockView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                mockView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                mockView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])

            let label = UILabel()
            label.text = "シミュレータではカメラは利用できません\n\n下のボタンでテストしてください"
            label.textColor = .white
            label.textAlignment = .center
            label.numberOfLines = 0
            label.font = UIFont.systemFont(ofSize: 16)
            label.translatesAutoresizingMaskIntoConstraints = false
            mockView.addSubview(label)

            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: mockView.centerXAnchor),
                label.topAnchor.constraint(equalTo: mockView.safeAreaLayoutGuide.topAnchor, constant: 100),
                label.leadingAnchor.constraint(equalTo: mockView.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(equalTo: mockView.trailingAnchor, constant: -20)
            ])

            // テストボタンのスタックビューを作成
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.distribution = .fillEqually
            stackView.spacing = 12
            stackView.translatesAutoresizingMaskIntoConstraints = false

            // 安全なURLテストボタン
            let safeButton = createTestButton(title: "安全URL テスト", color: .systemGreen, tag: 0)

            // 注意URLテストボタン
            let cautionButton = createTestButton(title: "注意URL テスト", color: .systemOrange, tag: 1)

            // 危険URLテストボタン
            let dangerButton = createTestButton(title: "危険URL テスト", color: .systemRed, tag: 2)

            stackView.addArrangedSubview(safeButton)
            stackView.addArrangedSubview(cautionButton)
            stackView.addArrangedSubview(dangerButton)

            // タッチイベントを確実に受け取るための設定
            mockView.isUserInteractionEnabled = true

            mockView.addSubview(stackView)

            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 40),
                stackView.centerXAnchor.constraint(equalTo: mockView.centerXAnchor),
                stackView.widthAnchor.constraint(equalToConstant: 200),
                stackView.heightAnchor.constraint(equalToConstant: 156), // 3つのボタン × 44pt + spacing × 2
                // Safe Area を考慮して、下からも十分な余白を確保
                stackView.bottomAnchor.constraint(lessThanOrEqualTo: mockView.safeAreaLayoutGuide.bottomAnchor, constant: -50)
            ])

            // レイアウト後にボタンの情報を出力（最前面移動は削除）
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // mockView内でスタックビューだけを最前面に（他のビューは影響しない）
                mockView.bringSubviewToFront(stackView)

                print("📱 テストボタン設定完了:")
                print("  - StackView Frame: \(stackView.frame)")
                print("  - StackView Bounds: \(stackView.bounds)")
                print("  - StackView isUserInteractionEnabled: \(stackView.isUserInteractionEnabled)")
                print("  - StackView arrangedSubviews count: \(stackView.arrangedSubviews.count)")
                print("  - mockView.frame: \(mockView.frame)")
                print("  - mockView.isUserInteractionEnabled: \(mockView.isUserInteractionEnabled)")

                // 各ボタンの情報も出力
                for (index, button) in stackView.arrangedSubviews.enumerated() {
                    if let btn = button as? UIButton {
                        print("  - Button[\(index)] tag: \(btn.tag), title: \(btn.title(for: .normal) ?? "no title")")
                    }
                }

                // 親ビューのsubviews確認
                if let parentView = mockView.superview {
                    print("  - 親ビューのsubviews数: \(parentView.subviews.count)")
                    for (index, subview) in parentView.subviews.enumerated() {
                        print("    \(index): \(type(of: subview)) - isUserInteractionEnabled: \(subview.isUserInteractionEnabled)")
                    }
                }

                // タッチ可能かテスト（最初のボタンでテスト）
                if let firstButton = stackView.arrangedSubviews.first {
                    let testPoint = CGPoint(x: firstButton.frame.midX, y: firstButton.frame.midY)
                    if let hitView = mockView.hitTest(testPoint, with: nil) {
                        print("  - hitTest結果: \(type(of: hitView))")
                    } else {
                        print("  - hitTest結果: nil（タッチ不可）")
                    }
                }
            }
        }

        @objc private func buttonTouchDown() {
            // ボタンの視覚的フィードバック (sender経由でボタンにアクセス)
        }

        @objc private func simulateQRDetection(_ sender: UIButton? = nil) {
            // ボタンのアニメーション（senderがある場合）
            if let button = sender {
                UIView.animate(withDuration: 0.1, animations: {
                    button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                }, completion: { _ in
                    UIView.animate(withDuration: 0.1) {
                        button.transform = CGAffineTransform.identity
                    }
                })
            }

            // .invalidを使い、Simulatorのテストで実在のスキャン先へ接続しない。
            let testURL: String
            let buttonTag = sender?.tag ?? 0

            switch buttonTag {
            case 0: // 安全URL
                testURL = "https://example.invalid"
                print("🟢 テスト: 安全URL")
            case 1: // 注意URL（ブランド偽装3点）
                testURL = "https://paypal.example.invalid"
                print("🟡 テスト: 注意URL")
            case 2: // 危険URL（Punycodeとブランド偽装の複合加点）
                testURL = "https://xn--e1afmkfd-paypal.example.invalid/login"
                print("🔴 テスト: 危険URL")
            default:
                testURL = "https://example.invalid"
                print("🟢 テスト: デフォルト安全URL")
            }

            // ViewControllerが監視するpublisherへ実機と同じ経路で配信する。
            scanResultSubject.send(testURL)
        }

        #if targetEnvironment(simulator)
            /// テストボタン作成ヘルパーメソッド
            private func createTestButton(title: String, color: UIColor, tag: Int) -> UIButton {
                let button = UIButton(type: .system)
                button.setTitle(title, for: .normal)
                button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
                button.setTitleColor(.white, for: .normal)
                button.backgroundColor = color
                button.layer.cornerRadius = 8
                button.tag = tag
                button.translatesAutoresizingMaskIntoConstraints = false
                button.isUserInteractionEnabled = true

                button.addTarget(self, action: #selector(simulateQRDetection(_:)), for: .touchUpInside)
                button.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)

                // 固定高さを設定（少し小さく）
                button.heightAnchor.constraint(equalToConstant: 44).isActive = true

                return button
            }
        #endif
    #endif

    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        _requestCameraPermission(completion: completion)
    }

    private func _requestCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private func configureCameraSession(in view: UIView) {
        print("📷 カメラセッション設定開始")
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("❌ カメラデバイス取得失敗")
            delegate?.qrScannerService(self, didFailWithError: .cameraNotAvailable)
            return
        }

        print("✅ カメラデバイス取得成功: \(videoCaptureDevice.localizedName)")

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)

            let captureSession = AVCaptureSession()

            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            } else {
                delegate?.qrScannerService(self, didFailWithError: .sessionSetupFailed)
                return
            }

            let metadataOutput = AVCaptureMetadataOutput()

            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            } else {
                delegate?.qrScannerService(self, didFailWithError: .sessionSetupFailed)
                return
            }

            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)

            print("📺 プレビューレイヤー設定完了: frame=\(previewLayer.frame)")

            self.captureSession = captureSession
            videoPreviewLayer = previewLayer

            // カメラ設定完了後、自動的にスキャンを開始
            DispatchQueue.main.async { [weak self] in
                self?.startScanning()
            }

        } catch {
            delegate?.qrScannerService(self, didFailWithError: .sessionSetupFailed)
        }
    }

    func startScanning() {
        guard let captureSession = captureSession else {
            print("⚠️ startScanning: captureSession is nil")
            return
        }

        if !captureSession.isRunning {
            // バックグラウンドスレッドでセッション開始（重い処理のため）
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                captureSession.startRunning()
                DispatchQueue.main.async {
                    self?.isScanning = true
                    print("📷 カメラスキャン開始")
                }
            }
        }
    }

    func stopScanning() {
        guard let captureSession = captureSession else { return }

        if captureSession.isRunning {
            captureSession.stopRunning()
            isScanning = false
        }
    }

    func updatePreviewLayer(frame: CGRect) {
        videoPreviewLayer?.frame = frame
    }

    func setTorchEnabled(_ enabled: Bool) {
        #if targetEnvironment(simulator)
            // シミュレータでは何もしない
            print("🔦 シミュレータ: トーチ設定 \(enabled ? "ON" : "OFF")")
            return
        #else
            guard let device = AVCaptureDevice.default(for: .video) else {
                print("⚠️ トーチ設定: デバイス取得失敗")
                return
            }

            guard device.hasTorch else {
                print("⚠️ トーチ設定: フラッシュ未対応デバイス")
                return
            }

            do {
                try device.lockForConfiguration()

                if enabled {
                    if device.torchMode == .off {
                        try device.setTorchModeOn(level: 1.0)
                        print("🔦 フラッシュライト ON")
                    }
                } else {
                    if device.torchMode == .on {
                        device.torchMode = .off
                        print("🔦 フラッシュライト OFF")
                    }
                }

                device.unlockForConfiguration()
            } catch {
                print("❌ フラッシュライト制御エラー: \(error.localizedDescription)")
            }
        #endif
    }

    func getPreviewLayer() -> CALayer? {
        return videoPreviewLayer
    }
}

extension QRScannerService: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from _: AVCaptureConnection) {
        guard isScanning else { return }

        for metadataObject in metadataObjects {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  readableObject.type == .qr,
                  let stringValue = readableObject.stringValue else {
                continue
            }

            // 一度検出したら一時的に停止
            isScanning = false

            // プロトコル対応：Publisherにも通知
            scanResultSubject.send(stringValue)

            // 既存の通知経路も保持する。publisherへの配信は一度だけ。
            NotificationCenter.default.post(
                name: .qrCodeDetected,
                object: stringValue
            )

            // 1秒後に再度スキャンを有効化
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.isScanning = true
            }

            break
        }
    }
}
