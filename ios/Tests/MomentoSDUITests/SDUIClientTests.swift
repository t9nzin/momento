import XCTest
@testable import MomentoSDUI

final class SDUIClientTests: XCTestCase {

    private let client = SDUIClient(baseURL: URL(string: "http://localhost:8080")!, userId: "ios-demo-user")

    func testSendsIOSContextHeaders() {
        let request = client.screenRequest("gallery")

        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Platform"), "ios")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-User-Id"), "ios-demo-user")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Schema-Version"), "1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Supported-Components"),
                       "column,row,text,image,card,grid,list,button,spacer")
    }

    func testBuildsScreenURLsWithParams() {
        let request = client.screenRequest("item-detail", params: ["itemId": "3", "variant": "B"])

        XCTAssertEqual(request.url?.absoluteString, "http://localhost:8080/api/screens/item-detail?itemId=3&variant=B")
        XCTAssertEqual(request.httpMethod, "GET")
    }
}
