import CoreData
import Foundation

/**
 * 履歴管理リポジトリ
 * - 最大50件の履歴を管理
 * - 51件目が追加される場合は最も古いものを削除
 * - 同一URLの場合はvisitCountをインクリメント
 * - Core DataのScanRecordEntityとドメインのScanRecordの変換を担当
 */
class HistoryRepository: HistoryRepositoryProtocol {
    // MARK: - 定数

    /// 履歴の最大保存件数
    private static let maxHistoryCount = 50

    // MARK: - プロパティ

    /// Core Dataスタック
    private let coreDataStack: CoreDataStack

    // MARK: - イニシャライザ

    /**
     * イニシャライザ
     * @param coreDataStack: Core Dataスタック（デフォルトは共有インスタンス）
     */
    init(coreDataStack: CoreDataStack = CoreDataStack.shared) {
        self.coreDataStack = coreDataStack
    }

    // MARK: - 公開メソッド

    /**
     * 新しいスキャン記録を保存
     * 既存の同一URLがある場合はvisitCountをインクリメントし、scannedAtを更新
     * @param scanRecord: 保存するスキャン記録
     */
    func upsertScanRecord(_ scanRecord: ScanRecord) {
        let context = coreDataStack.viewContext

        // 既存の同一URL記録を検索
        if let existingEntity = findExistingScanRecord(url: scanRecord.url, in: context) {
            // 既存レコードの更新
            updateExistingScanRecord(existingEntity, with: scanRecord)
        } else {
            // 新規レコードの追加
            createNewScanRecord(scanRecord, in: context)
        }

        // 最大件数チェック後、変更を保存
        enforceMaxHistoryLimit(in: context)
        coreDataStack.saveContext()
    }

    /**
     * 全ての履歴を取得（最新順）
     * @return: ScanRecordの配列（最新のスキャン日時順）
     */
    func getAllRecords() throws -> [ScanRecord] {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ScanRecordEntity> = ScanRecordEntity.fetchRequest()

        // 最新のスキャン日時順でソート
        request.sortDescriptors = [NSSortDescriptor(key: "scannedAt", ascending: false)]

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { convertToScanRecord($0) }
        } catch {
            print("履歴取得エラー: \(error)")
            return []
        }
    }

    /**
     * 特定のIDの履歴を取得
     * @param id: 取得するレコードのID
     * @return: 該当するScanRecord（見つからない場合はnil）
     */
    func fetchScanRecord(by id: UUID) -> ScanRecord? {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ScanRecordEntity> = ScanRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            let entities = try context.fetch(request)
            return entities.first.flatMap { convertToScanRecord($0) }
        } catch {
            print("履歴取得エラー: \(error)")
            return nil
        }
    }

    /**
     * 特定の履歴を削除
     * @param id: 削除するレコードのID
     */
    func deleteScanRecord(by id: UUID) {
        let context = coreDataStack.viewContext

        if let entity = findScanRecordEntity(by: id, in: context) {
            context.delete(entity)
            coreDataStack.saveContext()
        }
    }

    /**
     * 全ての履歴を削除
     */
    func deleteAllScanRecords() {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ScanRecordEntity> = ScanRecordEntity.fetchRequest()

        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            coreDataStack.saveContext()
        } catch {
            print("全履歴削除エラー: \(error)")
        }
    }

    /**
     * 履歴件数を取得
     * @return: 現在の履歴件数
     */
    func getHistoryCount() -> Int {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ScanRecordEntity> = ScanRecordEntity.fetchRequest()

        do {
            return try context.count(for: request)
        } catch {
            print("履歴件数取得エラー: \(error)")
            return 0
        }
    }

    // MARK: - プライベートメソッド

    /**
     * 既存の同一URL記録を検索
     * @param url: 検索するURL
     * @param context: Core Dataコンテキスト
     * @return: 見つかったScanRecordEntity（見つからない場合はnil）
     */
    private func findExistingScanRecord(url: String, in context: NSManagedObjectContext) -> ScanRecordEntity? {
        let request: NSFetchRequest<ScanRecordEntity> = ScanRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "url == %@", url)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            print("既存レコード検索エラー: \(error)")
            return nil
        }
    }

    /**
     * 既存のスキャン記録を更新
     * visitCountをインクリメントし、scannedAt（最終訪問日時）を更新
     * @param entity: 更新するScanRecordEntity
     * @param scanRecord: 新しいスキャン情報
     */
    private func updateExistingScanRecord(_ entity: ScanRecordEntity, with scanRecord: ScanRecord) {
        entity.visitCount += 1 // 訪問回数をインクリメント
        entity.scannedAt = scanRecord.scannedAt // 最終訪問日時を更新

        // タイトルが新しく取得された場合は更新
        if let newTitle = scanRecord.title {
            entity.title = newTitle
        }

        // ファビコンが新しく取得された場合は更新
        if let newFavicon = scanRecord.favicon {
            entity.favicon = newFavicon
        }
    }

    /**
     * 新しいスキャン記録を作成
     * @param scanRecord: 作成するスキャン記録
     * @param context: Core Dataコンテキスト
     */
    private func createNewScanRecord(_ scanRecord: ScanRecord, in context: NSManagedObjectContext) {
        let entity = ScanRecordEntity(context: context)

        // ドメインモデルからCore Dataエンティティに変換
        entity.id = scanRecord.id
        entity.url = scanRecord.url
        entity.title = scanRecord.title
        entity.domainHash = scanRecord.domainHash
        entity.safety = scanRecord.safety.rawValue
        entity.scannedAt = scanRecord.scannedAt
        entity.visitCount = scanRecord.visitCount
        entity.favicon = scanRecord.favicon
    }

    /**
     * 最大件数制限を適用
     * 50件を超える場合、最も古いレコードを削除
     * @param context: Core Dataコンテキスト
     */
    private func enforceMaxHistoryLimit(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<ScanRecordEntity> = ScanRecordEntity.fetchRequest()

        do {
            let count = try context.count(for: request)

            // 50件以下の場合は何もしない
            if count <= Self.maxHistoryCount {
                return
            }

            // 最も古いレコードから削除する件数を計算
            let deleteCount = count - Self.maxHistoryCount

            // 古い順でソート
            request.sortDescriptors = [NSSortDescriptor(key: "scannedAt", ascending: true)]
            request.fetchLimit = deleteCount

            let oldestRecords = try context.fetch(request)

            // 古いレコードを削除
            for record in oldestRecords {
                context.delete(record)
            }

        } catch {
            print("履歴制限適用エラー: \(error)")
        }
    }

    /**
     * ScanRecordEntityをScanRecordに変換
     * @param entity: 変換するScanRecordEntity
     * @return: 変換されたScanRecord（変換失敗時はnil）
     */
    private func convertToScanRecord(_ entity: ScanRecordEntity) -> ScanRecord? {
        // 必須プロパティのチェック
        guard let id = entity.id,
              let url = entity.url,
              let scannedAt = entity.scannedAt,
              let domainHash = entity.domainHash,
              let safetyLevel = SafetyLevel(rawValue: entity.safety) else {
            print("ScanRecord変換エラー: 必須プロパティが不足")
            return nil
        }

        return ScanRecord(
            id: id,
            url: url,
            title: entity.title,
            domainHash: domainHash,
            safety: safetyLevel,
            scannedAt: scannedAt,
            visitCount: entity.visitCount,
            favicon: entity.favicon
        )
    }

    /**
     * IDでScanRecordEntityを検索
     * @param id: 検索するID
     * @param context: Core Dataコンテキスト
     * @return: 見つかったScanRecordEntity（見つからない場合はnil）
     */
    private func findScanRecordEntity(by id: UUID, in context: NSManagedObjectContext) -> ScanRecordEntity? {
        let request: NSFetchRequest<ScanRecordEntity> = ScanRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            print("ScanRecordEntity検索エラー: \(error)")
            return nil
        }
    }

    /**
     * 指定URLのタイトルを更新
     * @param url: 更新対象のURL
     * @param title: 新しいタイトル
     */
    func updateTitle(url: String, title: String) throws {
        let context = coreDataStack.viewContext

        // URLに一致するレコードを検索
        let request: NSFetchRequest<ScanRecordEntity> = ScanRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "url == %@", url)
        request.fetchLimit = 1

        do {
            if let entity = try context.fetch(request).first {
                entity.title = title
                coreDataStack.saveContext()
                print("✅ タイトル更新成功: \(url) -> \(title)")
            } else {
                print("⚠️ タイトル更新: レコードが見つからない: \(url)")
            }
        } catch {
            print("❌ タイトル更新エラー: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Protocol Compliance Methods

    /**
     * 履歴記録の保存（プロトコル準拠）
     */
    func saveRecord(url: String, safetyLevel: SafetyLevel, title: String?) throws {
        let domainHash = ScanRecord.generateDomainHash(from: url)
        let scanRecord = ScanRecord(
            id: UUID(),
            url: url,
            title: title,
            domainHash: domainHash,
            safety: safetyLevel,
            scannedAt: Date(),
            visitCount: 1,
            favicon: nil
        )
        upsertScanRecord(scanRecord)
    }

    /**
     * 履歴の削除（プロトコル準拠）
     */
    func deleteRecord(with id: UUID) throws {
        deleteScanRecord(by: id)
    }

    /**
     * 全履歴の削除（プロトコル準拠）
     */
    func deleteAllRecords() throws {
        deleteAllScanRecords()
    }

    /**
     * 履歴件数の取得（プロトコル準拠）
     */
    func getRecordCount() throws -> Int {
        return getHistoryCount()
    }
}
