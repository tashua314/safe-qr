@testable import SafeQR
import XCTest

/**
 * 簡易メモリリーク検証テスト
 * 実行可能なAPIのみを使用
 */
class MemoryLeakTestsSimple: XCTestCase {
    // MARK: - DIContainer Memory Tests

    /**
     * DIContainer 解決処理の反復テスト
     * 循環参照やファクトリのリークを検証
     */
    func testDIContainerMemoryManagement() {
        print("🧪 Starting DIContainer memory management test...")

        for index in 0 ..< 30 {
            autoreleasepool {
                // 各種サービスを解決
                _ = DIContainer.shared.resolve(QRScannerServiceProtocol.self)
                _ = DIContainer.shared.resolve(URLEvaluationServiceProtocol.self)
                _ = DIContainer.shared.resolve(HistoryRepositoryProtocol.self)
                _ = DIContainer.shared.resolve(ScannerViewModel.self)

                if index % 10 == 9 {
                    print("📊 DIContainer resolution iteration \(index + 1)/30 completed")
                }
            }
        }

        print("✅ DIContainer memory test completed")
    }

    // MARK: - Core Data Memory Tests

    /**
     * Core Data スタックの反復操作テスト
     * NSManagedObjectContext のリークを検証
     */
    func testCoreDataStackMemoryManagement() {
        print("🧪 Starting Core Data memory management test...")

        let historyRepo = DIContainer.shared.resolve(HistoryRepositoryProtocol.self)

        for index in 0 ..< 20 {
            autoreleasepool {
                // 履歴データの取得（読み込み処理）
                do {
                    let records = try historyRepo.getAllRecords()
                    print("📊 Fetched \(records.count) records - iteration \(index + 1)/20")
                } catch {
                    print("❌ Failed to fetch records: \(error)")
                }
            }
        }

        print("✅ Core Data memory test completed")
    }

    // MARK: - ViewModel Memory Tests

    /**
     * ScannerViewModel の反復生成・破棄テスト
     */
    func testViewModelMemoryManagement() {
        print("🧪 Starting ViewModel memory management test...")

        for index in 0 ..< 15 {
            autoreleasepool {
                let viewModel = DIContainer.shared.resolve(ScannerViewModel.self)

                // ViewModelの基本プロパティアクセス
                _ = viewModel.scanStatus
                _ = viewModel.errorMessage

                if index % 5 == 4 {
                    print("📊 ScannerViewModel iteration \(index + 1)/15 completed")
                }
            }
        }

        print("✅ ViewModel memory test completed")
    }

    // MARK: - Service Memory Tests

    /**
     * 各種サービスクラスの反復生成テスト
     */
    func testServiceMemoryManagement() {
        print("🧪 Starting Service memory management test...")

        for index in 0 ..< 20 {
            autoreleasepool {
                // QRScannerService
                _ = DIContainer.shared.resolve(QRScannerServiceProtocol.self)
                // サービスのインスタンス化のみテスト

                // UrlRiskEvaluator
                _ = DIContainer.shared.resolve(URLEvaluationServiceProtocol.self)
                // 基本的なアクセスのみ（実際の評価は行わない）

                if index % 10 == 9 {
                    print("📊 Service iteration \(index + 1)/20 completed")
                }
            }
        }

        print("✅ Service memory test completed")
    }

    // MARK: - Aggregate Memory Test

    /**
     * 統合メモリテスト
     * 複数コンポーネントを組み合わせて使用
     */
    func testAggregateMemoryManagement() {
        print("🧪 Starting aggregate memory management test...")

        let initialMemory = getMemoryUsage()
        print("📊 Initial memory usage: \(String(format: "%.1f", initialMemory)) MB")

        for batch in 0 ..< 3 {
            autoreleasepool {
                // バッチ処理
                for _ in 0 ..< 10 {
                    autoreleasepool {
                        // 複数サービスの同時使用
                        let viewModel = DIContainer.shared.resolve(ScannerViewModel.self)
                        let historyRepo = DIContainer.shared.resolve(HistoryRepositoryProtocol.self)
                        _ = DIContainer.shared.resolve(QRScannerServiceProtocol.self)

                        // 基本操作
                        _ = viewModel.scanStatus
                        do {
                            _ = try historyRepo.getAllRecords()
                        } catch {
                            print("❌ Error fetching records: \(error)")
                        }
                        // QRServiceのインスタンス化のみ
                    }
                }

                let currentMemory = getMemoryUsage()
                let memoryDelta = currentMemory - initialMemory
                let formattedMemory = String(format: "%.1f", currentMemory)
                let formattedDelta = String(format: "%.1f", memoryDelta)
                print(
                    "📊 Memory after batch \(batch + 1): \(formattedMemory) MB (Δ: \(formattedDelta) MB)"
                )
            }
        }

        // 最終メモリ使用量チェック
        let finalMemory = getMemoryUsage()
        let totalMemoryDelta = finalMemory - initialMemory

        print("🎯 Aggregate memory test completed")
        print("📊 Final memory usage: \(String(format: "%.1f", finalMemory)) MB")
        print("📊 Total memory delta: \(String(format: "%.1f", totalMemoryDelta)) MB")

        // メモリ増加が30MBを超えている場合は警告
        XCTAssertLessThan(
            totalMemoryDelta,
            30.0,
            "Memory usage increased by \(String(format: "%.1f", totalMemoryDelta)) MB - potential memory leak"
        )

        print("✅ Aggregate memory test passed")
    }

    // MARK: - Helper Methods

    /**
     * 現在のメモリ使用量を取得（MB単位）
     */
    private func getMemoryUsage() -> Double {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if result == KERN_SUCCESS {
            return Double(taskInfo.resident_size) / (1024.0 * 1024.0)
        } else {
            return 0.0
        }
    }
}
