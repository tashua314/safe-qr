import Foundation
import Network
@testable import SafeQR
import XCTest

final class HtmlTitleRedirectTests: XCTestCase {
    func testHTTPRedirectDoesNotRequestUnapprovedDestination() throws {
        let listener = try NWListener(using: .tcp, on: .any)
        let ready = expectation(description: "管理下のHTTPサーバー起動")
        let queue = DispatchQueue(label: "safeqr.title-redirect-test")
        let requests = RedirectRequests()
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready: ready.fulfill()
            case let .failed(error): XCTFail("テストサーバーの起動失敗: \(error)")
            default: break
            }
        }
        listener.newConnectionHandler = { connection in
            connection.start(queue: queue)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                guard let data = data, let port = listener.port else { connection.cancel()
                    return
                }
                requests.append((String(bytes: data, encoding: .utf8) ?? "").components(separatedBy: "\r\n").first ?? "")
                let response = "HTTP/1.1 302 Found\r\nLocation: http://127.0.0.1:\(port.rawValue)/unapproved\r\n"
                    + "Content-Length: 0\r\nConnection: close\r\n\r\n"
                connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
            }
        }
        listener.start(queue: queue)
        defer { listener.cancel() }
        wait(for: [ready], timeout: 3)
        let port = try XCTUnwrap(listener.port)
        let done = expectation(description: "リダイレクトを追わず取得終了")
        let fetcher = HtmlTitleFetcher()
        fetcher.fetchTitle(from: "http://127.0.0.1:\(port.rawValue)/approved") { (result: Result<String, Error>) in
            guard case .failure = result else { return XCTFail("302応答をタイトルとして受理しない") }
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(requests.all, ["GET /approved HTTP/1.1"])
    }
}

private final class RedirectRequests {
    private let lock = NSLock()
    private var values: [String] = []
    func append(_ value: String) {
        lock.lock()
        defer { lock.unlock() }
        values.append(value)
    }

    var all: [String] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}
