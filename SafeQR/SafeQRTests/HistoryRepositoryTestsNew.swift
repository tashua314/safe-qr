import CoreData
@testable import SafeQR
import XCTest

/**
 * HistoryRepository のユニットテスト（リファクタリング版）
 * 現在のAPI実装に合わせて作り直し
 */
class HistoryRepositoryTestsNew: XCTestCase {
    // MARK: - Properties

    /// テスト対象のHistoryRepository
    private var storedRepository: HistoryRepository?
    private var repository: HistoryRepository {
        guard let repository = storedRepository else { preconditionFailure("テストのsetUpが必要です") }
        return repository
    }

    /// テスト用のCore Dataスタック
    private var storedCoreDataStack: TestCoreDataStack?
    private var testCoreDataStack: TestCoreDataStack {
        guard let stack = storedCoreDataStack else { preconditionFailure("テストのsetUpが必要です") }
        return stack
    }

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // テスト用のインメモリCore Dataスタックを作成
        storedCoreDataStack = TestCoreDataStack()

        // テスト対象を初期化
        storedRepository = HistoryRepository(coreDataStack: testCoreDataStack)
    }

    override func tearDown() {
        storedRepository = nil
        storedCoreDataStack = nil
        super.tearDown()
    }

    // MARK: - 基本的なCRUD操作のテスト

    /**
     * 新しいスキャンレコードの保存テスト
     */
    func testUpsertNewScanRecord() throws {
        // テストデータの作成
        let scanRecord = createTestScanRecord(url: "https://example.com", safety: .safe)

        // 保存実行
        repository.upsertScanRecord(scanRecord)

        // 保存確認
        let fetchedRecords = try repository.getAllRecords()
        XCTAssertEqual(fetchedRecords.count, 1, "Should have 1 record after inserting")

        let fetchedRecord = try XCTUnwrap(fetchedRecords.first)
        XCTAssertEqual(fetchedRecord.url, "https://example.com")
        XCTAssertEqual(fetchedRecord.safety, .safe)
        XCTAssertEqual(fetchedRecord.visitCount, 1)
    }

    /**
     * 既存レコードの更新（同一URL）テスト
     */
    func testUpsertExistingRecord() throws {
        let url = "https://example.com"

        // 1回目の保存
        let firstRecord = createTestScanRecord(url: url, safety: .safe)
        repository.upsertScanRecord(firstRecord)

        // 2回目の保存（同一URL）
        let secondRecord = createTestScanRecord(url: url, safety: .caution)
        repository.upsertScanRecord(secondRecord)

        // 確認：レコード数は1件のまま、visitCountが増加
        let fetchedRecords = try repository.getAllRecords()
        XCTAssertEqual(fetchedRecords.count, 1, "Should still have only 1 record")

        let fetchedRecord = try XCTUnwrap(fetchedRecords.first)
        XCTAssertEqual(fetchedRecord.url, url)
        XCTAssertEqual(fetchedRecord.visitCount, 2, "Visit count should be incremented")
    }

    /**
     * 全履歴取得テスト（最新順）
     */
    func testGetAllRecords() throws {
        // 複数のレコードを時間差で保存
        let record1 = createTestScanRecord(url: "https://first.com", safety: .safe)
        repository.upsertScanRecord(record1)

        // 少し時間をおいて2つ目を保存
        Thread.sleep(forTimeInterval: 0.1)
        let record2 = createTestScanRecord(url: "https://second.com", safety: .caution)
        repository.upsertScanRecord(record2)

        // 取得してソート順を確認
        let fetchedRecords = try repository.getAllRecords()
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
    func testDeleteScanRecord() throws {
        // レコード保存
        let scanRecord = createTestScanRecord(url: "https://example.com", safety: .safe)
        repository.upsertScanRecord(scanRecord)

        // 削除実行
        repository.deleteScanRecord(by: scanRecord.id)

        // 削除確認
        let fetchedRecords = try repository.getAllRecords()
        XCTAssertEqual(fetchedRecords.count, 0, "Should have no records after deletion")
    }

    /**
     * 全履歴削除テスト
     */
    func testDeleteAllScanRecords() throws {
        // 複数レコード保存
        for index in 1 ... 5 {
            let record = createTestScanRecord(url: "https://example\(index).com", safety: .safe)
            repository.upsertScanRecord(record)
        }

        // 保存確認
        XCTAssertEqual(try (repository.getAllRecords()).count, 5)

        // 全削除実行
        repository.deleteAllScanRecords()

        // 削除確認
        let fetchedRecords = try repository.getAllRecords()
        XCTAssertEqual(fetchedRecords.count, 0, "Should have no records after delete all")
    }

    // MARK: - 最大50件制限のテスト

    /**
     * 最大50件制限のテスト
     */
    func testMaxHistoryLimit() throws {
        // 51件のレコードを保存
        for index in 1 ... 51 {
            let record = createTestScanRecord(url: "https://example\(index).com", safety: .safe)
            repository.upsertScanRecord(record)

            // 少しずつ時間をずらして保存順序を明確にする
            Thread.sleep(forTimeInterval: 0.01)
        }

        // 50件のみ保持されていることを確認
        let fetchedRecords = try repository.getAllRecords()
        XCTAssertEqual(fetchedRecords.count, 50, "Should maintain maximum of 50 records")

        // 最も古いレコード（1件目）が削除され、2件目〜51件目が残っていることを確認
        let urls = fetchedRecords.map { $0.url }
        XCTAssertFalse(urls.contains("https://example1.com"), "Oldest record should be deleted")
        XCTAssertTrue(urls.contains("https://example51.com"), "Newest record should be kept")
        XCTAssertTrue(urls.contains("https://example2.com"), "Second oldest should be kept")
    }

    // MARK: - 重複URL処理のテスト

    /**
     * 同一URL繰り返し保存時のvisitCount増加テスト
     */
    func testVisitCountIncrement() throws {
        let url = "https://example.com"

        // 同じURLを5回保存
        for _ in 1 ... 5 {
            let record = createTestScanRecord(url: url, safety: .safe)
            repository.upsertScanRecord(record)
        }

        // 1つのレコードのvisitCountが5になることを確認
        let fetchedRecords = try repository.getAllRecords()
        XCTAssertEqual(fetchedRecords.count, 1, "Should have only 1 record for duplicate URLs")

        let record = try XCTUnwrap(fetchedRecords.first)
        XCTAssertEqual(record.visitCount, 5, "Visit count should be incremented to 5")
        XCTAssertEqual(record.url, url)
    }

    /**
     * 重複URL保存時のタイムスタンプ更新テスト
     */
    func testTimestampUpdateOnDuplicate() throws {
        let url = "https://example.com"

        // 1回目の保存
        let firstRecord = createTestScanRecord(url: url, safety: .safe)
        repository.upsertScanRecord(firstRecord)

        let firstFetch = try try XCTUnwrap((repository.getAllRecords()).first)
        let firstTimestamp = firstFetch.scannedAt

        // 時間をおいて2回目の保存
        Thread.sleep(forTimeInterval: 0.1)
        let secondRecord = createTestScanRecord(url: url, safety: .safe)
        repository.upsertScanRecord(secondRecord)

        // タイムスタンプが更新されていることを確認
        let secondFetch = try try XCTUnwrap((repository.getAllRecords()).first)
        let secondTimestamp = secondFetch.scannedAt

        XCTAssertGreaterThan(
            secondTimestamp,
            firstTimestamp,
            "Timestamp should be updated on duplicate URL save"
        )
    }

    // MARK: - 履歴件数取得のテスト

    /**
     * 履歴件数取得テスト
     */
    func testGetHistoryCount() throws {
        // 初期状態は0件
        XCTAssertEqual(repository.getHistoryCount(), 0, "Initial count should be 0")

        // 3件追加
        for index in 1 ... 3 {
            let record = createTestScanRecord(url: "https://example\(index).com", safety: .safe)
            repository.upsertScanRecord(record)
        }

        // 件数確認
        XCTAssertEqual(repository.getHistoryCount(), 3, "Count should be 3 after adding 3 records")

        // 1件削除
        let records = try repository.getAllRecords()
        try repository.deleteScanRecord(by: XCTUnwrap(records.first?.id))

        // 件数確認
        XCTAssertEqual(repository.getHistoryCount(), 2, "Count should be 2 after deleting 1 record")
    }

    // MARK: - プロトコル準拠メソッドのテスト

    /**
     * saveRecord プロトコルメソッドのテスト
     */
    func testSaveRecord() throws {
        // プロトコル準拠メソッドで保存
        try repository.saveRecord(url: "https://test.com", safetyLevel: .safe, title: "Test Page")

        // 保存確認
        let fetchedRecords = try repository.getAllRecords()
        XCTAssertEqual(fetchedRecords.count, 1)

        let record = try XCTUnwrap(fetchedRecords.first)
        XCTAssertEqual(record.url, "https://test.com")
        XCTAssertEqual(record.safety, .safe)
        XCTAssertEqual(record.title, "Test Page")
    }

    /**
     * getRecordCount プロトコルメソッドのテスト
     */
    func testGetRecordCount() throws {
        // 初期状態
        XCTAssertEqual(try repository.getRecordCount(), 0)

        // レコード追加
        try repository.saveRecord(url: "https://test.com", safetyLevel: .safe, title: nil)
        XCTAssertEqual(try repository.getRecordCount(), 1)
    }

    /**
     * deleteRecord プロトコルメソッドのテスト
     */
    func testDeleteRecord() throws {
        // レコード保存
        let scanRecord = createTestScanRecord(url: "https://example.com", safety: .safe)
        repository.upsertScanRecord(scanRecord)

        // プロトコル準拠メソッドで削除
        try repository.deleteRecord(with: scanRecord.id)

        // 削除確認
        let fetchedRecords = try repository.getAllRecords()
        XCTAssertEqual(fetchedRecords.count, 0)
    }

    /**
     * deleteAllRecords プロトコルメソッドのテスト
     */
    func testDeleteAllRecords() throws {
        // 複数レコード保存
        for index in 1 ... 3 {
            try repository.saveRecord(url: "https://example\(index).com", safetyLevel: .safe, title: nil)
        }

        // 全削除
        try repository.deleteAllRecords()

        // 削除確認
        let fetchedRecords = try repository.getAllRecords()
        XCTAssertEqual(fetchedRecords.count, 0)
    }

    // MARK: - ヘルパーメソッド

    /**
     * テスト用のScanRecordを作成
     */
    private func createTestScanRecord(url: String, safety: SafetyLevel) -> ScanRecord {
        let domainHash = ScanRecord.generateDomainHash(from: url)
        return ScanRecord(
            url: url,
            safety: safety,
            domainHash: domainHash
        )
    }
}

// MARK: - TestCoreDataStack

/**
 * テスト用のCore Dataスタック
 * 独立したインメモリストアを使用
 */
class TestCoreDataStack: CoreDataStack {
    private var _persistentContainer = NSPersistentContainer(name: "SafeQR")

    override init() {
        super.init()
        setupInMemoryPersistentContainer()
    }

    private func setupInMemoryPersistentContainer() {
        let container = NSPersistentContainer(name: "SafeQR")

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.url = nil

        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if let error = loadError {
            fatalError("Test Core Data setup failed: \(error)")
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        _persistentContainer = container
    }

    override var viewContext: NSManagedObjectContext {
        return _persistentContainer.viewContext
    }

    override func saveContext() {
        let context = _persistentContainer.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("❌ Test Core Data save error: \(error)")
            }
        }
    }
}
