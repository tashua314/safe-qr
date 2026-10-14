import Darwin
import Foundation

/// GoogleのURL正規化仕様。未対応入力を生URLによる照会へフォールバックしない。
struct SafeBrowsingURLCanonicalizer {
    struct CanonicalURL {
        let host: String
        let path: String
        let query: String?
        let isIPAddress: Bool
    }

    enum CanonicalizationError: Error { case invalidURL }

    func canonicalize(_ input: String) throws -> CanonicalURL {
        guard input.utf8.count <= 16384 else { throw CanonicalizationError.invalidURL }
        let clean = input.filter { $0 != "\t" && $0 != "\r" && $0 != "\n" }
        let noFragment = String(clean.prefix(while: { $0 != "#" }))
        let bytes = try unescape(Array(noFragment.utf8))
        guard let schemeEnd = bytes.firstIndex(of: 58),
              let scheme = String(bytes: bytes[..<schemeEnd], encoding: .utf8),
              ["http", "https"].contains(scheme.lowercased()),
              bytes.dropFirst(schemeEnd + 1).starts(with: [47, 47]) else { throw CanonicalizationError.invalidURL }
        let remainder = Array(bytes.dropFirst(schemeEnd + 3))
        let authorityEnd = remainder.firstIndex(where: { $0 == 47 || $0 == 63 }) ?? remainder.count
        let authority = Array(remainder.prefix(authorityEnd))
        let host = try canonicalHost(authority)
        let tail = Array(remainder.dropFirst(authorityEnd))
        let queryStart = tail.firstIndex(of: 63)
        let path = normalizePath(Array(tail.prefix(queryStart ?? tail.count)))
        let query = queryStart.map { escape(Array(tail.dropFirst($0 + 1))) }
        return CanonicalURL(host: host.value, path: escape(path), query: query, isIPAddress: host.isIP)
    }

    private func unescape(_ input: [UInt8]) throws -> [UInt8] {
        var bytes = input
        // 悪意のある多重escapeでCPUを占有させず、失敗を未確認として返す。
        for _ in 0 ..< 128 {
            var decoded = [UInt8]()
            var index = 0
            while index < bytes.count {
                if bytes[index] == 37, index + 2 < bytes.count,
                   let high = hexValue(bytes[index + 1]), let low = hexValue(bytes[index + 2]) {
                    decoded.append(high * 16 + low)
                    index += 3
                } else {
                    decoded.append(bytes[index])
                    index += 1
                }
            }
            if decoded == bytes { return bytes }
            bytes = decoded
        }
        throw CanonicalizationError.invalidURL
    }

    private func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48 ... 57: return byte - 48
        case 65 ... 70: return byte - 55
        case 97 ... 102: return byte - 87
        default: return nil
        }
    }

    private func canonicalHost(_ authority: [UInt8]) throws -> (value: String, isIP: Bool) {
        let hostPort = Array(authority.dropFirst((authority.lastIndex(of: 64).map { $0 + 1 }) ?? 0))
        guard !hostPort.isEmpty else { throw CanonicalizationError.invalidURL }
        if hostPort.first == 91 {
            guard let close = hostPort.firstIndex(of: 93),
                  validPort(Array(hostPort.dropFirst(close + 1))),
                  let literal = String(bytes: hostPort[1 ..< close], encoding: .utf8),
                  let normalized = ipv6(literal) else { throw CanonicalizationError.invalidURL }
            return (normalized, true)
        }
        let portStart = hostPort.firstIndex(of: 58) ?? hostPort.count
        guard validPort(Array(hostPort.dropFirst(portStart))),
              let decoded = String(bytes: hostPort.prefix(portStart), encoding: .utf8) else {
            throw CanonicalizationError.invalidURL
        }
        let dotted = decoded.split(separator: ".", omittingEmptySubsequences: true).joined(separator: ".").lowercased()
        guard !dotted.isEmpty else { throw CanonicalizationError.invalidURL }
        if let address = ipv4(dotted) { return (address, true) }
        guard !dotted.contains(where: { $0.isWhitespace || "/\\#%?@[]:".contains($0) }),
              let ascii = URLComponents(string: "https://\(dotted)/")?.url?.host?.lowercased(),
              !ascii.contains("%") else { throw CanonicalizationError.invalidURL }
        return (ascii, false)
    }

    private func validPort(_ bytes: [UInt8]) -> Bool {
        bytes.isEmpty || (bytes.first == 58 && bytes.dropFirst().allSatisfy { 48 ... 57 ~= $0 })
    }

    private func ipv4(_ host: String) -> String? {
        let components = host.split(separator: ".", omittingEmptySubsequences: false)
        guard 1 ... 4 ~= components.count else { return nil }
        var values = [UInt64]()
        for component in components {
            let text = String(component)
            let radix: Int
            let digits: String
            if text.hasPrefix("0x") {
                radix = 16
                digits = String(text.dropFirst(2))
            } else if text.count > 1, text.hasPrefix("0") {
                radix = 8
                digits = String(text.dropFirst())
            } else {
                radix = 10
                digits = text
            }
            guard !digits.isEmpty, let value = UInt64(digits, radix: radix) else { return nil }
            values.append(value)
        }
        guard let last = values.last, values.dropLast().allSatisfy({ $0 <= 255 }),
              last < (UInt64(1) << (8 * (5 - values.count))) else { return nil }
        var address = last
        for (index, value) in values.dropLast().enumerated() {
            address += value << (8 * (3 - index))
        }
        return (0 ..< 4).map { String((address >> (8 * (3 - $0))) & 255) }.joined(separator: ".")
    }

    private func ipv6(_ literal: String) -> String? {
        var address = in6_addr()
        guard inet_pton(AF_INET6, literal, &address) == 1 else { return nil }
        let bytes = withUnsafeBytes(of: &address) { Array($0) }
        let mapped = bytes.prefix(10).allSatisfy { $0 == 0 } && bytes[10] == 255 && bytes[11] == 255
        let nat64 = Array(bytes.prefix(12)) == [0, 100, 255, 155, 0, 0, 0, 0, 0, 0, 0, 0]
        if mapped || nat64 { return bytes.suffix(4).map(String.init).joined(separator: ".") }
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        guard inet_ntop(AF_INET6, &address, &buffer, socklen_t(buffer.count)) != nil else { return nil }
        return "[\(String(cString: buffer).lowercased())]"
    }

    private func normalizePath(_ input: [UInt8]) -> [UInt8] {
        var segments = [[UInt8]]()
        let parts = input.split(separator: 47, omittingEmptySubsequences: true)
        for part in parts {
            if part.elementsEqual([46]) { continue }
            if part.elementsEqual([46, 46]) {
                if !segments.isEmpty { segments.removeLast() }
            } else {
                segments.append(Array(part))
            }
        }
        var path: [UInt8] = [47]
        for (index, segment) in segments.enumerated() {
            if index > 0 { path.append(47) }
            path += segment
        }
        let trailingDot = parts.last.map { $0.elementsEqual([46]) || $0.elementsEqual([46, 46]) } ?? false
        if !segments.isEmpty, input.last == 47 || trailingDot { path.append(47) }
        return path
    }

    private func escape(_ bytes: [UInt8]) -> String {
        bytes.map { byte in
            if byte <= 32 || byte >= 127 || byte == 35 || byte == 37 { return String(format: "%%%02X", byte) }
            return String(UnicodeScalar(byte))
        }.joined()
    }
}
