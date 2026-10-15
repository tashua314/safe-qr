import CryptoKit
import Foundation

struct SafeBrowsingURLHasher {
    let suffixList: PublicSuffixList

    func expressions(for url: String) throws -> [String] {
        let canonical = try SafeBrowsingURLCanonicalizer().canonicalize(url)
        let hosts = hostVariants(canonical)
        var paths = Set([canonical.path, "/"])
        if let query = canonical.query { paths.insert(canonical.path + "?" + query) }
        var prefix = ""
        for component in canonical.path.split(separator: "/").dropLast().prefix(3) {
            prefix += "/" + component
            paths.insert(prefix + "/")
        }
        // trailing slashのURLも、4個のpath prefix（rootを含む）まで生成する。
        if canonical.path.hasSuffix("/") {
            let components = canonical.path.split(separator: "/").prefix(3)
            prefix = ""
            for component in components {
                prefix += "/" + component
                paths.insert(prefix + "/")
            }
        }
        return hosts.flatMap { host in paths.sorted().map { host + $0 } }
    }

    func fullHashes(for url: String) throws -> Set<Data> {
        try Set(expressions(for: url).map { Data(SHA256.hash(data: Data($0.utf8))) })
    }

    private func hostVariants(_ url: SafeBrowsingURLCanonicalizer.CanonicalURL) -> [String] {
        guard !url.isIPAddress else { return [url.host] }
        let labels = url.host.split(separator: ".")
        let minimum = suffixList.registrableLabelCount(for: url.host)
        var hosts = Set([url.host])
        for count in minimum ... min(labels.count, minimum + 3) {
            hosts.insert(labels.suffix(count).joined(separator: "."))
        }
        return hosts.sorted()
    }
}
