import Foundation

/// 同梱したPSL snapshotを使用する。更新時に外部通信は行わない。
struct PublicSuffixList {
    private let exact: Set<String>
    private let wildcard: Set<String>
    private let exceptions: Set<String>

    init(contents: String) {
        var exact = Set<String>()
        var wildcard = Set<String>()
        var exceptions = Set<String>()
        for line in contents.split(whereSeparator: \.isNewline) {
            let rule = String(line).trimmingCharacters(in: .whitespaces)
            guard !rule.isEmpty, !rule.hasPrefix("//") else { continue }
            let isException = rule.hasPrefix("!")
            let isWildcard = rule.hasPrefix("*.")
            let domain = isException ? String(rule.dropFirst()) : (isWildcard ? String(rule.dropFirst(2)) : rule)
            guard let ascii = URLComponents(string: "https://\(domain)/")?.url?.host?.lowercased() else { continue }
            if isException {
                exceptions.insert(ascii)
            } else if isWildcard {
                wildcard.insert(ascii)
            } else {
                exact.insert(ascii)
            }
        }
        self.exact = exact
        self.wildcard = wildcard
        self.exceptions = exceptions
    }

    static let bundled: PublicSuffixList? = {
        guard let url = Bundle.main.url(forResource: "public_suffix_list", withExtension: "dat"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return PublicSuffixList(contents: contents)
    }()

    func registrableLabelCount(for host: String) -> Int {
        let labels = host.split(separator: ".")
        var suffixCount = 1 // PSLの既定ruleは「*」。
        for index in labels.indices {
            let suffix = labels[index...].joined(separator: ".")
            if exceptions.contains(suffix) { return min(labels.count, labels.count - index) }
            if exact.contains(suffix) { suffixCount = max(suffixCount, labels.count - index) }
            if index > 0, wildcard.contains(suffix) { suffixCount = max(suffixCount, labels.count - index + 1) }
        }
        return min(labels.count, suffixCount + 1)
    }
}
