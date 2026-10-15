import Foundation
import OSLog

/// URL・タイトル・NSError説明を引数に取らない。Debug/Releaseで同じ最小限の診断情報だけを残す。
enum AppLog {
    enum Event: String {
        case historyReadFailed, historyDeleteFailed, historyCountFailed, historyLookupFailed, historyLimitFailed
        case historyRecordInvalid, historySaveFailed, titleUpdateFailed, titleRecordMissing
        case coreDataLoadFailed, coreDataSaveFailed, coreDataDeleteFailed
        case externalCheckFailed, externalCheckFinished, titleParseFailed, reputationParseFailed
        case torchFailed, cameraUnavailable
    }

    private static let logger = Logger(subsystem: "jp.techguide.SafeQR", category: "diagnostics")

    static func error(_ event: Event, code: Int) {
        logger.error("event=\(event.rawValue, privacy: .public) code=\(code, privacy: .public)")
    }

    static func duration(_ event: Event, milliseconds: Double) {
        guard milliseconds.isFinite, milliseconds >= 0 else { return }
        let elapsed = Int(min(milliseconds.rounded(), 86_400_000))
        logger.notice("event=\(event.rawValue, privacy: .public) elapsed_ms=\(elapsed, privacy: .public)")
    }
}
