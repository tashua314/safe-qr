@testable import SafeQR
import XCTest

final class SafeBrowsingURLHasherTests: XCTestCase {
    private let list = PublicSuffixList(contents: "com\nco.uk\n*.ck\n!www.ck\ngithub.io\nde\n")

    func testDocumentedHostAndPathExpressions() throws {
        let actual = try SafeBrowsingURLHasher(suffixList: list).expressions(for: "http://a.b.com/1/2.html?param=1")
        let paths = ["/1/2.html?param=1", "/1/2.html", "/", "/1/"]
        let expected = Set(["a.b.com", "b.com"].flatMap { host in paths.map { host + $0 } })
        XCTAssertEqual(Set(actual), expected)
    }

    func testPublicSuffixWildcardExceptionAndPrivateDomain() throws {
        let hasher = SafeBrowsingURLHasher(suffixList: list)
        XCTAssertEqual(try Set(hasher.expressions(for: "https://example.co.uk/1")), ["example.co.uk/1", "example.co.uk/"])
        XCTAssertEqual(try Set(hasher.expressions(for: "https://a.b.ck/")), ["a.b.ck/"])
        XCTAssertEqual(try Set(hasher.expressions(for: "https://a.www.ck/")), ["a.www.ck/", "www.ck/"])
        XCTAssertEqual(try Set(hasher.expressions(for: "https://a.project.github.io/")), ["a.project.github.io/", "project.github.io/"])
    }

    func testDeepHostAndLongPathStayWithinThirtyExpressions() throws {
        let expressions = try SafeBrowsingURLHasher(suffixList: list).expressions(for: "https://a.b.c.d.e.f.com/1/2/3/4/file?q=1")
        XCTAssertEqual(expressions.count, 30)
        XCTAssertTrue(expressions.contains("c.d.e.f.com/"))
        XCTAssertFalse(expressions.contains("b.c.d.e.f.com/"))
        XCTAssertFalse(expressions.contains("com/"))
        XCTAssertFalse(expressions.contains("f.com/1/2/3/4/"))
    }

    func testRepeatedPercentDecodeAndEscapedBytes() throws {
        let canonicalizer = SafeBrowsingURLCanonicalizer()
        let cases = [
            ("http://host/%25%32%35", "/%25"),
            ("http://host/%2525252525252525", "/%25"),
            ("http://host/asdf%25%32%35asd", "/asdf%25asd"),
            ("http://host/%%%25%32%35asd%%", "/%25%25%25asd%25%25"),
            ("http://host/%00%FF%20%23", "/%00%FF%20%23"),
            ("http://host/a/../b//./c/..", "/b/")
        ]
        for (input, expected) in cases {
            XCTAssertEqual(try canonicalizer.canonicalize(input).path, expected)
        }
    }

    func testFragmentsControlsAndQueries() throws {
        let result = try SafeBrowsingURLCanonicalizer().canonicalize("ht\ttps://..EXAMPLE...com../a//b/../?q=/../x//y%23z#fragment")
        XCTAssertEqual(result.host, "example.com")
        XCTAssertEqual(result.path, "/a/")
        XCTAssertEqual(result.query, "q=/../x//y%23z")
        XCTAssertEqual(try SafeBrowsingURLCanonicalizer().canonicalize("https://example.com/?").query, "")
        XCTAssertEqual(try SafeBrowsingURLCanonicalizer().canonicalize("https://example.com/%0A").path, "/%0A")
    }

    func testInternationalDomainAndDiscardedCredentialsPortScheme() throws {
        let hasher = SafeBrowsingURLHasher(suffixList: list)
        XCTAssertEqual(try hasher.expressions(for: "https://bücher.de/"), ["xn--bcher-kva.de/"])
        let first = try hasher.fullHashes(for: "http://user:password@Example.com:8080/a#fragment")
        let second = try hasher.fullHashes(for: "https://example.com/a")
        XCTAssertEqual(first, second)
    }

    func testIPv4LegalEncodings() throws {
        let canonicalizer = SafeBrowsingURLCanonicalizer()
        for host in ["192.168.0.1", "0xc0.0250.1", "0xc0a80001", "3232235521", "192.168.1"] {
            let result = try canonicalizer.canonicalize("https://\(host)/")
            XCTAssertEqual(result.host, "192.168.0.1")
            XCTAssertTrue(result.isIPAddress)
        }
    }

    func testIPv6AndIPv4Translations() throws {
        let canonicalizer = SafeBrowsingURLCanonicalizer()
        XCTAssertEqual(try canonicalizer.canonicalize("https://[2001:0db8:0000::1]/").host, "[2001:db8::1]")
        XCTAssertEqual(try canonicalizer.canonicalize("https://[::ffff:1.2.3.4]/").host, "1.2.3.4")
        XCTAssertEqual(try canonicalizer.canonicalize("https://[64:ff9b::102:304]/").host, "1.2.3.4")
        XCTAssertEqual(
            try SafeBrowsingURLHasher(suffixList: list).expressions(for: "https://[2001:db8::1]/1/"),
            ["[2001:db8::1]/", "[2001:db8::1]/1/"]
        )
    }

    func testInvalidInputsCannotFallBackToRawURL() {
        for input in [
            "relative/path",
            "https:///path",
            "ftp://example.com/",
            "https://[invalid]/",
            "https://example.com:abc/",
            "https://example.com/" + String(repeating: "a", count: 16384)
        ] {
            XCTAssertThrowsError(try SafeBrowsingURLCanonicalizer().canonicalize(input))
        }
    }

    func testBundledSuffixListIsAvailableToApp() throws {
        let bundled = try XCTUnwrap(PublicSuffixList.bundled)
        XCTAssertEqual(bundled.registrableLabelCount(for: "a.example.co.uk"), 3)
        XCTAssertEqual(bundled.registrableLabelCount(for: "a.project.github.io"), 3)
    }
}
