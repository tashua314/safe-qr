import Foundation

/// APIのTTLは照会した全prefix（該当なしを含む）に適用する。
final class SafeBrowsingHashCache {
    struct FullHash: Decodable {
        let fullHash: Data
        let fullHashDetails: [Detail]?
    }

    struct Detail: Decodable {
        let threatType: String
        let attributes: [String]?
    }

    private struct Entry {
        let hashes: [FullHash]
        let expires: Date
    }

    private let lock = NSLock()
    private var entries = [Data: Entry]()

    func lookup(_ prefixes: Set<Data>, now: Date) -> (hashes: [FullHash], missing: Set<Data>) {
        lock.lock()
        defer { lock.unlock() }
        entries = entries.filter { $0.value.expires > now }
        var hashes = [FullHash]()
        var missing = Set<Data>()
        for prefix in prefixes {
            if let entry = entries[prefix] { hashes += entry.hashes } else { missing.insert(prefix) }
        }
        return (hashes, missing)
    }

    func store(_ hashes: [FullHash], prefixes: Set<Data>, duration: TimeInterval, now: Date) {
        lock.lock()
        defer { lock.unlock() }
        for prefix in prefixes {
            entries[prefix] = Entry(
                hashes: hashes.filter { Data($0.fullHash.prefix(4)) == prefix },
                expires: now.addingTimeInterval(duration)
            )
        }
        // 全URLの長期保管を避ける。再照会可能なメモリキャッシュに限る。
        if entries.count > 3000 { entries = entries.filter { prefixes.contains($0.key) } }
    }
}
