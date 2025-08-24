import AVFoundation
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
    
    override init() {
        super.init()
    }
    
    func setupCamera(in view: UIView) {
        #if targetEnvironment(simulator)
        // シミュレータではモックカメラを設定
        setupMockCamera(in: view)
        #else
        requestCameraPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.configureCameraSession(in: view)
                } else {
                    self?.delegate?.qrScannerService(self!, didFailWithError: .permissionDenied)
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
        label.text = "シミュレータではカメラは利用できません\n\nテスト用QRをタップしてください"
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        mockView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: mockView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: mockView.centerYAnchor, constant: -50),
            label.leadingAnchor.constraint(equalTo: mockView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: mockView.trailingAnchor, constant: -20)
        ])
        
        // テスト用ボタンを追加
        let testButton = UIButton(type: .system)
        testButton.setTitle("テスト QR スキャン", for: .normal)
        testButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        testButton.setTitleColor(.white, for: .normal)
        testButton.backgroundColor = UIColor.systemBlue
        testButton.layer.cornerRadius = 8
        testButton.translatesAutoresizingMaskIntoConstraints = false
        
        // タッチイベントを確実に受け取るための設定
        testButton.isUserInteractionEnabled = true
        mockView.isUserInteractionEnabled = true
        
        testButton.addTarget(self, action: #selector(simulateQRDetection), for: .touchUpInside)
        
        // デバッグ用：タッチダウンイベントも追加
        testButton.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        
        mockView.addSubview(testButton)
        
        NSLayoutConstraint.activate([
            testButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 30),
            testButton.centerXAnchor.constraint(equalTo: mockView.centerXAnchor),
            testButton.widthAnchor.constraint(equalToConstant: 200),
            testButton.heightAnchor.constraint(equalToConstant: 50),
            // Safe Area を考慮して、少なくとも下から100pt以上の余白を確保
            testButton.bottomAnchor.constraint(lessThanOrEqualTo: mockView.bottomAnchor, constant: -100)
        ])
    }
    
    @objc private func buttonTouchDown() {
        print("🔘 ボタンがタッチされました")
    }
    
    @objc private func simulateQRDetection() {
        print("🎯 simulateQRDetection が呼ばれました")
        // テスト用のURL
        let testURL = "https://www.google.com"
        delegate?.qrScannerService(self, didDetectQRCode: testURL)
    }
    #endif
    
    private func requestCameraPermission(completion: @escaping (Bool) -> Void) {
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
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.qrScannerService(self, didFailWithError: .cameraNotAvailable)
            return
        }
        
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
            
            self.captureSession = captureSession
            self.videoPreviewLayer = previewLayer
            
        } catch {
            delegate?.qrScannerService(self, didFailWithError: .sessionSetupFailed)
        }
    }
    
    func startScanning() {
        guard let captureSession = captureSession else { return }
        
        if !captureSession.isRunning {
            captureSession.startRunning()
            isScanning = true
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
}

extension QRScannerService: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        guard isScanning else { return }
        
        for metadataObject in metadataObjects {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  readableObject.type == .qr,
                  let stringValue = readableObject.stringValue else {
                continue
            }
            
            // 一度検出したら一時的に停止
            isScanning = false
            
            delegate?.qrScannerService(self, didDetectQRCode: stringValue)
            
            // 1秒後に再度スキャンを有効化
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.isScanning = true
            }
            
            break
        }
    }
}