import CoreData
import Foundation

/**
 * Core Dataスタック管理クラス
 * iOS 18.5+対応、NSPersistentContainerを使用
 * シングルトンパターンでアプリ全体からアクセス
 */
class CoreDataStack {
    // MARK: - シングルトンインスタンス

    static let shared = CoreDataStack()

    // MARK: - プライベートイニシャライザ（テスト用にinternal）

    init() {}

    // MARK: - Core Data Stack

    /**
     * NSPersistentContainer
     * iOS 18.5+で利用可能なCore Dataスタック管理方式
     */
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         NSPersistentContainerは.xcdatamodeldファイルを自動で見つけて読み込む
         SafeQRという名前でxcdatamodeldファイルを作成する必要がある
         */
        let container = NSPersistentContainer(name: "SafeQR")

        // データベースの読み込み設定
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                /*
                 本来はより適切なエラーハンドリングが必要
                 開発段階では一旦fatalErrorで落とす
                 */
                fatalError("Core Data読み込みエラー: \(error), \(error.userInfo)")
            }
        }

        // マージポリシー設定：同じデータが複数作成された場合の対処
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    // MARK: - Context

    /**
     * メインスレッド用のコンテキスト
     * UI更新時に使用
     */
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    /**
     * バックグラウンドスレッド用のコンテキスト作成
     * 重い処理（大量データの保存等）時に使用
     */
    func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }

    // MARK: - Core Data保存処理

    /**
     * コンテキストの変更をディスクに保存
     * メインコンテキスト用
     */
    func saveContext() {
        let context = persistentContainer.viewContext

        // 変更があるかチェック
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // 保存エラーが発生した場合
                let nsError = error as NSError
                print("Core Data保存エラー: \(nsError), \(nsError.userInfo)")

                // 本来はより適切なエラーハンドリングが必要
                // 例：ユーザーに通知、データの復旧処理など
                fatalError("Core Data保存エラー: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    /**
     * バックグラウンドコンテキストの保存
     * @param context: 保存するバックグラウンドコンテキスト
     */
    func saveBackgroundContext(_ context: NSManagedObjectContext) {
        context.perform {
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    let nsError = error as NSError
                    print("バックグラウンドCore Data保存エラー: \(nsError), \(nsError.userInfo)")
                }
            }
        }
    }

    // MARK: - ヘルパーメソッド

    /**
     * データベースを完全にリセット（開発用）
     * 本番環境では使用しない
     */
    func deleteAllData() {
        let context = viewContext

        // ScanRecordEntityの全レコードを削除
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "ScanRecordEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try context.execute(deleteRequest)
            saveContext()
        } catch {
            print("データ削除エラー: \(error)")
        }
    }
}
