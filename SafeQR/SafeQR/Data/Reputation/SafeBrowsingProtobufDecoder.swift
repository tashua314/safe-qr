import Foundation

/// v5 hashes.searchのバイナリ応答だけを読む。wire定義はChromiumのsafebrowsingv5.protoに従う。
enum SafeBrowsingProtobufDecoder {
    struct Response {
        let fullHashes: [SafeBrowsingHashCache.FullHash]
        let cacheDuration: String
    }

    enum DecodingError: Error { case invalidResponse }

    static func decode(_ data: Data) throws -> Response {
        guard data.count <= 8 * 1024 * 1024 else { throw DecodingError.invalidResponse }
        let budget = Budget()
        var reader = Reader(data, budget: budget)
        var hashes = [SafeBrowsingHashCache.FullHash]()
        var duration: String?
        while let field = try reader.field() {
            switch field.number {
            case 1:
                try require(field.wire, 2)
                try hashes.append(fullHash(reader.bytes(), budget: budget))
            case 2:
                try require(field.wire, 2)
                duration = try cacheDuration(reader.bytes(), budget: budget)
            default: try reader.skip(field.wire)
            }
        }
        guard let duration = duration else { throw DecodingError.invalidResponse }
        return Response(fullHashes: hashes, cacheDuration: duration)
    }

    private static func fullHash(_ data: Data, budget: Budget) throws -> SafeBrowsingHashCache.FullHash {
        var reader = Reader(data, budget: budget)
        var hash = Data()
        var details = [SafeBrowsingHashCache.Detail]()
        while let field = try reader.field() {
            switch field.number {
            case 1:
                try require(field.wire, 2)
                hash = try reader.bytes()
            case 2:
                try require(field.wire, 2)
                try details.append(detail(reader.bytes(), budget: budget))
            default: try reader.skip(field.wire)
            }
        }
        guard hash.count == 32, !details.isEmpty else { throw DecodingError.invalidResponse }
        return .init(fullHash: hash, fullHashDetails: details)
    }

    private static func detail(_ data: Data, budget: Budget) throws -> SafeBrowsingHashCache.Detail {
        var reader = Reader(data, budget: budget)
        var threat: UInt64 = 0
        var attributes = [UInt64]()
        while let field = try reader.field() {
            switch field.number {
            case 1:
                try require(field.wire, 0)
                threat = try reader.varint()
            case 2:
                if field.wire == 0 {
                    try attributes.append(reader.varint())
                } else {
                    try require(field.wire, 2)
                    var packed = try Reader(reader.bytes(), budget: budget)
                    while !packed.isAtEnd {
                        try budget.consume()
                        try attributes.append(packed.varint())
                    }
                }
            default: try reader.skip(field.wire)
            }
        }
        let threats: [UInt64: String] = [
            1: "MALWARE",
            2: "SOCIAL_ENGINEERING",
            3: "UNWANTED_SOFTWARE",
            4: "POTENTIALLY_HARMFUL_APPLICATION"
        ]
        let knownAttributes: [UInt64: String] = [1: "CANARY", 2: "FRAME_ONLY"]
        // 未知enumを落とすと、未知属性のある脅威を既知の安全な応答として扱ってしまう。
        return .init(
            threatType: threats[threat] ?? "UNRECOGNIZED_\(threat)",
            attributes: attributes.map { knownAttributes[$0] ?? "UNRECOGNIZED_\($0)" }
        )
    }

    private static func cacheDuration(_ data: Data, budget: Budget) throws -> String {
        var reader = Reader(data, budget: budget)
        var seconds: UInt64 = 0
        var nanos: UInt64 = 0
        while let field = try reader.field() {
            switch field.number {
            case 1:
                try require(field.wire, 0)
                seconds = try reader.varint()
            case 2:
                try require(field.wire, 0)
                nanos = try reader.varint()
            default: try reader.skip(field.wire)
            }
        }
        // 負のsigned値はUInt64としても範囲外になる。負TTLをキャッシュへ入れない。
        guard seconds <= 315_576_000_000, nanos <= 999_999_999 else { throw DecodingError.invalidResponse }
        return "\(seconds).\(String(format: "%09llu", nanos))s"
    }

    private static func require(_ actual: UInt64, _ expected: UInt64) throws {
        guard actual == expected else { throw DecodingError.invalidResponse }
    }

    private final class Budget {
        private var remaining = 100_000
        func consume() throws {
            guard remaining > 0 else { throw DecodingError.invalidResponse }
            remaining -= 1
        }
    }

    private struct Reader {
        let data: [UInt8]
        let budget: Budget
        private var offset = 0
        init(_ data: Data, budget: Budget) {
            self.data = Array(data)
            self.budget = budget
        }

        var isAtEnd: Bool {
            offset == data.count
        }

        mutating func field() throws -> (number: UInt64, wire: UInt64)? {
            guard !isAtEnd else { return nil }
            try budget.consume()
            let tag = try varint()
            let number = tag >> 3
            guard number > 0, number <= 0x1FFF_FFFF else { throw DecodingError.invalidResponse }
            return (number, tag & 7)
        }

        mutating func varint() throws -> UInt64 {
            var value: UInt64 = 0
            for index in 0 ..< 10 {
                guard offset < data.count else { throw DecodingError.invalidResponse }
                let byte = data[offset]
                offset += 1
                guard index < 9 || byte <= 1 else { throw DecodingError.invalidResponse }
                value |= UInt64(byte & 0x7F) << (index * 7)
                if byte & 0x80 == 0 { return value }
            }
            throw DecodingError.invalidResponse
        }

        mutating func bytes() throws -> Data {
            let count = try varint()
            guard count <= UInt64(data.count - offset) else { throw DecodingError.invalidResponse }
            let end = offset + Int(count)
            defer { offset = end }
            return Data(data[offset ..< end])
        }

        mutating func skip(_ wire: UInt64) throws {
            switch wire {
            case 0: _ = try varint()
            case 1: try advance(8)
            case 2: _ = try bytes()
            case 5: try advance(4)
            default: throw DecodingError.invalidResponse
            }
        }

        private mutating func advance(_ count: Int) throws {
            guard count <= data.count - offset else { throw DecodingError.invalidResponse }
            offset += count
        }
    }
}
