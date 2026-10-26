import XCTest
@testable import MomentoSDUI

final class DecodingTests: XCTestCase {

    func testDecodesEverySharedFixtureWithoutUnknowns() throws {
        let names = ["gallery-variant-a.json", "gallery-variant-b.json", "gallery-fallback.json", "item-detail.json"]
        var seen = Set<String>()
        for name in names {
            walk(try Fixtures.screen(name).root) { component in
                if case .unknown(let type, let id) = component {
                    XCTFail("\(name): \(id) decoded as unknown type \(type)")
                }
                seen.insert(Self.typeName(component))
            }
        }
        XCTAssertEqual(seen, Set(Component.supportedTypes))
    }

    func testGalleryVariantAIsAGridOfNavigatingCards() throws {
        let screen = try Fixtures.screen("gallery-variant-a.json")

        guard case .column(let root) = screen.root, case .grid(let grid) = root.children.last else {
            return XCTFail("expected column > grid, got \(screen.root)")
        }
        XCTAssertEqual(grid.props.columns, 2)
        XCTAssertEqual(grid.props.itemsBinding, "items")
        guard case .card(let card) = grid.template else { return XCTFail("expected card template") }
        XCTAssertEqual(card.action, .navigate(screenId: "item-detail", params: ["itemId": "{{item.id}}"]))
        XCTAssertEqual(screen.data["items"]?.arrayValue?.count, 8)
    }

    func testDecodesRequestActions() throws {
        let screen = try Fixtures.screen("item-detail.json")
        var actions: [Action] = []
        walk(screen.root) { if case .button(let button) = $0 { actions.append(button.action) } }

        XCTAssertTrue(actions.contains(.request(method: "POST", path: "/api/items/1/favorite", refresh: true)))
    }

    func testUnknownTypesDecodeAsUnknownAndKeepTheirSiblings() throws {
        let json = """
            {"type": "column", "id": "root", "children": [
              {"type": "carousel", "id": "c", "props": {}},
              {"type": "text", "id": "t", "props": {"text": "Still here"}}
            ]}
            """
        let component = try JSONDecoder().decode(Component.self, from: Data(json.utf8))

        guard case .column(let column) = component else { return XCTFail() }
        XCTAssertEqual(column.children.first, .unknown(type: "carousel", id: "c"))
        XCTAssertEqual(column.children.last?.id, "t")
    }

    func testMalformedKnownTypeDegradesToUnknownInsteadOfFailingTheScreen() throws {
        let json = #"{"type": "text", "id": "t", "props": {}}"#

        let component = try JSONDecoder().decode(Component.self, from: Data(json.utf8))

        XCTAssertEqual(component, .unknown(type: "text", id: "t"))
    }

    func testUnknownActionTypesDecode() throws {
        let action = try JSONDecoder().decode(Action.self, from: Data(#"{"type": "share"}"#.utf8))
        XCTAssertEqual(action, .unknown(type: "share"))
    }

    private func walk(_ component: Component, _ visit: (Component) -> Void) {
        visit(component)
        switch component {
        case .column(let node), .row(let node): node.children.forEach { walk($0, visit) }
        case .grid(let node): walk(node.template, visit)
        case .list(let node): walk(node.template, visit)
        default: break
        }
    }

    private static func typeName(_ component: Component) -> String {
        switch component {
        case .column: "column"
        case .row: "row"
        case .text: "text"
        case .image: "image"
        case .card: "card"
        case .grid: "grid"
        case .list: "list"
        case .button: "button"
        case .spacer: "spacer"
        case .unknown(let type, _): type
        }
    }
}
