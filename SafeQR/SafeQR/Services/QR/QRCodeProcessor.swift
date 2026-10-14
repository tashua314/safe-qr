import Combine
import Foundation

/*
 * QRコード処理専用サービス
 * - QRコードの検証とフォーマット処理
 * - 重複検出防止
 * - URL形式の妥当性チェック
 */

// MARK: - Protocol Definition

protocol QRCodeProcessorProtocol {
    var processingResult: AnyPublisher<QRProcessingResult, Never> { get }

    func validateQRCode(_ qrCode: String) -> QRValidationResult
    func setLightEnabled(_ enabled: Bool)
    func resetProcessedURLs()
}

// MARK: - Implementation

class QRCodeProcessor: QRCodeProcessorProtocol {
    // MARK: - Published Properties

    private let processingResultSubject = PassthroughSubject<QRProcessingResult, Never>()

    var processingResult: AnyPublisher<QRProcessingResult, Never> {
        return processingResultSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private var processedURLs: Set<String> = []
    private let qrScannerService: QRScannerServiceProtocol

    // MARK: - Initialization

    init(qrScannerService: QRScannerServiceProtocol) {
        self.qrScannerService = qrScannerService
    }

    // MARK: - Public Methods

    /**
     * QRコードの基本検証
     * @param qrCode: 検証対象のQRコード文字列
     * @return: 検証結果
     */
    func validateQRCode(_ qrCode: String) -> QRValidationResult {
        // 1. 基本的な文字列チェック
        guard !qrCode.isEmpty, qrCode.count <= AppConstants.QR.maxLength else {
            return .invalid(.invalidFormat)
        }

        // 2. URL形式の検証
        guard let url = URL(string: qrCode) else {
            return .invalid(.malformed)
        }

        // 3. スキーマの検証（HTTP/HTTPS のみ許可）
        guard isValidURLScheme(url.scheme) else {
            return .invalid(.unsupportedScheme)
        }

        // 4. ホスト名の存在チェック
        guard let host = url.host, !host.isEmpty else {
            return .invalid(.malformed)
        }

        // 5. 重複チェック
        if processedURLs.contains(qrCode) {
            print("🔄 重複URL検出: \(qrCode)")
            return .duplicate
        }

        print("✅ QRコード検証成功: \(qrCode)")
        return .valid(qrCode)
    }

    /**
     * フラッシュライトの設定
     */
    func setLightEnabled(_ enabled: Bool) {
        qrScannerService.setTorchEnabled(enabled)
        print("🔦 ライト設定: \(enabled ? "ON" : "OFF")")
    }

    /**
     * 処理済みURLリストのリセット
     */
    func resetProcessedURLs() {
        processedURLs.removeAll()
        print("🗑️ 処理済みURLリストをリセット")
    }

    // MARK: - Private Methods

    /**
     * URLスキーマの妥当性チェック
     */
    private func isValidURLScheme(_ scheme: String?) -> Bool {
        guard let scheme = scheme?.lowercased() else { return false }
        return AppConstants.QR.allowedSchemes.contains(scheme)
    }

    /**
     * URLの詳細検証（セキュリティチェック）
     */
    private func performSecurityValidation(_ url: URL) -> QRValidationResult {
        // 1. 危険なポート番号のチェック
        if let port = url.port, AppConstants.Security.dangerousPorts.contains(port) {
            return .invalid(.unsupportedScheme)
        }

        // 2. ローカルネットワークアドレスのチェック
        if let host = url.host, isLocalNetworkAddress(host) {
            print("⚠️ ローカルネットワークアドレス検出: \(host)")
            // 設定に応じて許可/拒否
            return AppConstants.Security.allowLocalNetwork ? .valid(url.absoluteString) : .invalid(.unsupportedScheme)
        }

        // 3. パス長の制限チェック
        let pathAndQuery = url.path + (url.query ?? "")
        if pathAndQuery.count > AppConstants.QR.maxPathLength {
            return .invalid(.malformed)
        }

        return .valid(url.absoluteString)
    }

    /**
     * ローカルネットワークアドレスの判定
     */
    private func isLocalNetworkAddress(_ host: String) -> Bool {
        // IPv4のローカルアドレス範囲をチェック
        let localRanges = [
            "127.", // localhost
            "192.168.", // プライベートネットワーク
            "10.", // プライベートネットワーク
            "172.16.", // プライベートネットワーク
            "172.17.", // プライベートネットワーク
            "172.18.", // プライベートネットワーク
            "172.19.", // プライベートネットワーク
            "172.2", // プライベートネットワーク (172.20-172.31)
            "172.30.", // プライベートネットワーク
            "172.31." // プライベートネットワーク
        ]

        return localRanges.contains { host.hasPrefix($0) } || host == "localhost"
    }
}

// MARK: - Supporting Types

/// QR検証結果
enum QRValidationResult {
    case valid(String) // 有効なURL
    case invalid(QRProcessingError) // 無効（エラー理由付き）
    case duplicate // 重複検出
}

// MARK: - Mock Implementation for Testing

#if DEBUG
    class MockQRCodeProcessor: QRCodeProcessorProtocol {
        private let processingResultSubject = PassthroughSubject<QRProcessingResult, Never>()

        var processingResult: AnyPublisher<QRProcessingResult, Never> {
            return processingResultSubject.eraseToAnyPublisher()
        }

        // テスト用の設定
        var shouldReturnError = false
        var mockError: QRProcessingError = .invalidFormat
        var lightEnabled = false

        func validateQRCode(_ qrCode: String) -> QRValidationResult {
            if shouldReturnError {
                return .invalid(mockError)
            }

            // テスト用の簡単な検証
            if qrCode.isEmpty {
                return .invalid(.invalidFormat)
            }

            if !qrCode.hasPrefix("http") {
                return .invalid(.unsupportedScheme)
            }

            return .valid(qrCode)
        }

        func setLightEnabled(_ enabled: Bool) {
            lightEnabled = enabled
        }

        func resetProcessedURLs() {
            // Mock implementation
        }

        /// テストヘルパーメソッド
        func simulateProcessingResult(_ result: QRProcessingResult) {
            processingResultSubject.send(result)
        }
    }
#endif
