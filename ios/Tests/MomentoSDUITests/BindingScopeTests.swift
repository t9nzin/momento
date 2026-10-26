import XCTest
@testable import MomentoSDUI

final class BindingScopeTests: XCTestCase {

    private let scope = BindingScope(data: .object([
        "count": .number(8),
        "user": .object(["name": .string("Tenzin")]),
        "items": .array([.object(["title": .string("Seashell"), "year": .number(2021)])]),
    ]))

    func testResolvesNestedPathsAndArrayIndices() {
        XCTAssertEqual(scope.resolve("user.name"), .string("Tenzin"))
        XCTAssertEqual(scope.resolve("items.0.title"), .string("Seashell"))
        XCTAssertNil(scope.resolve("items.3.title"))
        XCTAssertNil(scope.resolve("user.name.first"))
    }

    func testInterpolatesWholeNumbersWithoutADecimal() {
        XCTAssertEqual(scope.string("{{count}} things, since {{ items.0.year }}"), "8 things, since 2021")
    }

    func testMissingBindingsBecomeEmpty() {
        XCTAssertEqual(scope.string("[{{nope}}]"), "[]")
        XCTAssertNil(scope.optionalString("{{nope}}"))
        XCTAssertNil(scope.optionalString(nil))
    }

    func testItemScopeShadowsData() {
        let itemScope = scope.with(item: .object(["title": .string("Polaroid")]))

        XCTAssertEqual(itemScope.string("{{item.title}} of {{count}}"), "Polaroid of 8")
    }

    func testResolvesActionsAgainstTheScope() {
        let itemScope = scope.with(item: .object(["id": .string("4")]))
        let action = Action.navigate(screenId: "item-detail", params: ["itemId": "{{item.id}}"])

        XCTAssertEqual(action.resolved(in: itemScope), .navigate(screenId: "item-detail", params: ["itemId": "4"]))
    }

    func testLocalDataReplacesServerData() {
        let server = JSONValue.object(["items": .array([.string("server")]), "count": .number(1)])

        let merged = server.merging(["items": .array([.string("local")])])

        XCTAssertEqual(merged["items"], .array([.string("local")]))
        XCTAssertEqual(merged["count"], .number(1))
    }
}
