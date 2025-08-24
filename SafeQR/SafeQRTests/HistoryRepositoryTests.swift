import XCTest
import CoreData
@testable import SafeQR

/**
 * HistoryRepository のユニットテスト
 * 履歴管理の主要機能をテスト
 * - 最大50件制限
 * - 重複URL時のvisitCount増加
 * - CRUD操作
 */
class HistoryRepositoryTests: XCTestCase {
    
    // MARK: - Properties
    
    /// テスト対象のHistoryRepository
    private var repository: HistoryRepository!
    
    /// テスト用のCore Dataスタック
    private var testCoreDataStack: TestCoreDataStack!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // テスト用のインメモリCore Dataスタックを作成
        testCoreDataStack = TestCoreDataStack()
        
        // テスト対象を初期化
        repository = HistoryRepository(coreDataStack: testCoreDataStack)
    }
    
    override func tearDown() {
        repository = nil
        testCoreDataStack = nil
        super.tearDown()
    }
    
    // MARK: - 基本的なCRUD操作のテスト
    
    /**
     * 新しいスキャンレコードの保存テスト
     */
    func testUpsertNewScanRecord() {
        // テストデータの作成
        let scanRecord = createTestScanRecord(url: "https://example.com", safety: .safe)
        
        // 保存実行
        repository.upsertScanRecord(scanRecord)
        
        // 保存確認
        let fetchedRecords = repository.fetchAllScanRecords()
        XCTAssertEqual(fetchedRecords.count, 1, "Should have 1 record after inserting")
        
        let fetchedRecord = fetchedRecords.first!
        XCTAssertEqual(fetchedRecord.url, "https://example.com")
        XCTAssertEqual(fetchedRecord.safety, .safe)
        XCTAssertEqual(fetchedRecord.visitCount, 1)
    }
    
    /**
     * 既存レコードの更新（同一URL）テスト
     */
    func testUpsertExistingRecord() {
        let url = "https://example.com"
        
        // 1回目の保存
        let firstRecord = createTestScanRecord(url: url, safety: .safe)
        repository.upsertScanRecord(firstRecord)
        
        // 2回目の保存（同一URL）
        let secondRecord = createTestScanRecord(url: url, safety: .caution)
        repository.upsertScanRecord(secondRecord)
        
        // 確認：レコード数は1件のまま、visitCountが増加
        let fetchedRecords = repository.fetchAllScanRecords()
        XCTAssertEqual(fetchedRecords.count, 1, "Should still have only 1 record")
        
        let fetchedRecord = fetchedRecords.first!
        XCTAssertEqual(fetchedRecord.url, url)
        XCTAssertEqual(fetchedRecord.visitCount, 2, "Visit count should be incremented")
    }
    
    /**
     * 全履歴取得テスト（最新順）
     */
    func testFetchAllScanRecords() {
        // 複数のレコードを時間差で保存
        let record1 = createTestScanRecord(url: "https://first.com", safety: .safe)
        repository.upsertScanRecord(record1)
        
        // 少し時間をおいて2つ目を保存
        Thread.sleep(forTimeInterval: 0.1)
        let record2 = createTestScanRecord(url: "https://second.com", safety: .caution)
        repository.upsertScanRecord(record2)
        
        // 取得してソート順を確認
        let fetchedRecords = repository.fetchAllScanRecords()
        XCTAssertEqual(fetchedRecords.count, 2)
        
        // 最新のものが最初に来ることを確認
        XCTAssertEqual(fetchedRecords[0].url, "https://second.com")
        XCTAssertEqual(fetchedRecords[1].url, "https://first.com")
    }
    
    /**
     * ID指定での履歴取得テスト
     */
    func testFetchScanRecordById() {
        // レコード保存
        let scanRecord = createTestScanRecord(url: "https://example.com", safety: .safe)
        repository.upsertScanRecord(scanRecord)
        
        // ID指定で取得
        let fetchedRecord = repository.fetchScanRecord(by: scanRecord.id)
        
        XCTAssertNotNil(fetchedRecord, "Should fetch record by ID")
        XCTAssertEqual(fetchedRecord?.url, "https://example.com")
        XCTAssertEqual(fetchedRecord?.id, scanRecord.id)
    }
    
    /**
     * 存在しないIDでの取得テスト
     */
    func testFetchNonexistentRecord() {
        let nonexistentId = UUID()
        let fetchedRecord = repository.fetchScanRecord(by: nonexistentId)
        
        XCTAssertNil(fetchedRecord, "Should return nil for nonexistent ID")
    }
    
    // MARK: - 履歴削除のテスト
    
    /**
     * 個別レコード削除テスト
     */
    func testDeleteScanRecord() {
        // レコード保存
        let scanRecord = createTestScanRecord(url: "https://example.com", safety: .safe)
        repository.upsertScanRecord(scanRecord)
        
        // 削除実行
        repository.deleteScanRecord(by: scanRecord.id)
        
        // 削除確認
        let fetchedRecords = repository.fetchAllScanRecords()
        XCTAssertEqual(fetchedRecords.count, 0, "Should have no records after deletion")
    }
    
    /**
     * 全履歴削除テスト
     */
    func testDeleteAllScanRecords() {
        // 複数レコード保存
        for i in 1...5 {
            let record = createTestScanRecord(url: "https://example\(i).com", safety: .safe)
            repository.upsertScanRecord(record)
        }
        
        // 保存確認
        XCTAssertEqual(repository.fetchAllScanRecords().count, 5)
        
        // 全削除実行
        repository.deleteAllScanRecords()
        
        // 削除確認
        let fetchedRecords = repository.fetchAllScanRecords()
        XCTAssertEqual(fetchedRecords.count, 0, "Should have no records after delete all")
    }
    
    // MARK: - 最大50件制限のテスト
    
    /**
     * 最大50件制限のテスト
     * 51件目を追加した時に最も古いものが削除されることを確認
     */
    func testMaxHistoryLimit() {
        // 51件のレコードを保存
        var savedRecords: [ScanRecord] = []
        for i in 1...51 {
            let record = createTestScanRecord(url: "https://example\(i).com", safety: .safe)
            repository.upsertScanRecord(record)
            savedRecords.append(record)
            
            // 少しずつ時間をずらして保存順序を明確にする
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        // 50件のみ保持されていることを確認
        let fetchedRecords = repository.fetchAllScanRecords()
        XCTAssertEqual(fetchedRecords.count, 50, "Should maintain maximum of 50 records")
        
        // 最も古いレコード（1件目）が削除され、2件目〜51件目が残っていることを確認
        let urls = fetchedRecords.map { $0.url }
        XCTAssertFalse(urls.contains("https://example1.com"), "Oldest record should be deleted")
        XCTAssertTrue(urls.contains("https://example51.com"), "Newest record should be kept")
        XCTAssertTrue(urls.contains("https://example2.com"), "Second oldest should be kept")
    }
    
    /**
     * 制限内（50件以下）では削除されないことをテスト
     */
    func testNoDeleteionUnderLimit() {
        // 30件のレコードを保存
        for i in 1...30 {
            let record = createTestScanRecord(url: "https://example\(i).com", safety: .safe)
            repository.upsertScanRecord(record)
        }
        
        // 全て保持されていることを確認
        let fetchedRecords = repository.fetchAllScanRecords()
        XCTAssertEqual(fetchedRecords.count, 30, "All records should be kept under the limit")
    }
    
    // MARK: - 重複URL処理のテスト
    
    /**
     * 同一URL繰り返し保存時のvisitCount増加テスト
     */
    func testVisitCountIncrement() {
        let url = "https://example.com"
        
        // 同じURLを5回保存
        for _ in 1...5 {
            let record = createTestScanRecord(url: url, safety: .safe)
            repository.upsertScanRecord(record)
        }
        
        // 1つのレコードのvisitCountが5になることを確認
        let fetchedRecords = repository.fetchAllScanRecords()
        XCTAssertEqual(fetchedRecords.count, 1, "Should have only 1 record for duplicate URLs")
        
        let record = fetchedRecords.first!
        XCTAssertEqual(record.visitCount, 5, "Visit count should be incremented to 5")
        XCTAssertEqual(record.url, url)
    }
    
    /**
     * 重複URL保存時のタイムスタンプ更新テスト
     */
    func testTimestampUpdateOnDuplicate() {
        let url = "https://example.com"
        
        // 1回目の保存
        let firstRecord = createTestScanRecord(url: url, safety: .safe)
        repository.upsertScanRecord(firstRecord)
        
        let firstFetch = repository.fetchAllScanRecords().first!
        let firstTimestamp = firstFetch.scannedAt
        
        // 時間をおいて2回目の保存
        Thread.sleep(forTimeInterval: 0.1)
        let secondRecord = createTestScanRecord(url: url, safety: .safe)
        repository.upsertScanRecord(secondRecord)
        
        // タイムスタンプが更新されていることを確認
        let secondFetch = repository.fetchAllScanRecords().first!
        let secondTimestamp = secondFetch.scannedAt
        
        XCTAssertGreaterThan(secondTimestamp, firstTimestamp, 
                           "Timestamp should be updated on duplicate URL save")
    }
    
    // MARK: - 履歴件数取得のテスト
    
    /**
     * 履歴件数取得テスト
     */
    func testGetHistoryCount() {
        // 初期状態は0件
        XCTAssertEqual(repository.getHistoryCount(), 0, "Initial count should be 0")
        
        // 3件追加
        for i in 1...3 {
            let record = createTestScanRecord(url: "https://example\(i).com", safety: .safe)
            repository.upsertScanRecord(record)
        }
        
        // 件数確認
        XCTAssertEqual(repository.getHistoryCount(), 3, "Count should be 3 after adding 3 records")
        
        // 1件削除
        let records = repository.fetchAllScanRecords()
        repository.deleteScanRecord(by: records.first!.id)
        
        // 件数確認
        XCTAssertEqual(repository.getHistoryCount(), 2, "Count should be 2 after deleting 1 record")
    }
    
    // MARK: - エラーケースのテスト
    
    /**
     * Core Dataエラー時の動作テスト
     * ここでは基本的にクラッシュしないことを確認
     */
    func testErrorHandling() {
        // 無効なデータでもクラッシュしないことを確認
        XCTAssertNoThrow({ [self] in
            let record = createTestScanRecord(url: "", safety: .safe) // 空URL
            repository.upsertScanRecord(record)
        }, "Should handle empty URL gracefully")
        
        // 存在しないIDの削除でもクラッシュしないことを確認
        XCTAssertNoThrow({ [self] in
            repository.deleteScanRecord(by: UUID())
        }, "Should handle deletion of nonexistent record gracefully")
    }
    
    // MARK: - ヘルパーメソッド
    
    /**
     * テスト用のScanRecordを作成
     * @param url: URL文字列
     * @param safety: 安全性レベル
     * @return: ScanRecordインスタンス
     */
    private func createTestScanRecord(url: String, safety: SafetyLevel) -> ScanRecord {
        let domainHash = ScanRecord.generateDomainHash(from: url)
        return ScanRecord(url: url, safety: safety, domainHash: domainHash)
    }
}

// MARK: - TestCoreDataStack

/**
 * テスト用のCore Dataスタック
 * インメモリストアを使用してテストの独立性を保つ
 */
class TestCoreDataStack: CoreDataStack {
    
    override init() {
        super.init()
        
        // インメモリストアとして設定
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        // 同期的に読み込み
        var loadError: Error?
        persistentContainer.loadPersistentStores { _, error in
            loadError = error
        }
        
        if let error = loadError {
            fatalError("Test Core Data setup failed: \(error)")
        }
    }
}

// MARK: - Test Utilities

extension ScanRecord {
    /**
     * テスト用のイコール比較
     * 主要なプロパティが一致するかを確認
     */
    func isEqualForTesting(to other: ScanRecord) -> Bool {
        return self.url == other.url &&
               self.safety == other.safety &&
               self.domainHash == other.domainHash
    }
}