import Foundation

/// The values `{{path}}` bindings resolve against: the screen's data, plus
/// `item` inside a grid or list template.
public struct BindingScope: Equatable, Sendable {
    public var values: JSONValue

    public init(data: JSONValue) {
        values = data
    }

    public func with(item: JSONValue) -> BindingScope {
        BindingScope(data: values.merging(["item": item]))
    }

    /// Walks `a.b.0.c` through objects and arrays.
    public func resolve(_ path: String) -> JSONValue? {
        path.split(separator: ".").reduce(Optional(values)) { current, segment in
            switch current {
            case .object(let object): return object[String(segment)]
            case .array(let array):
                guard let index = Int(segment), array.indices.contains(index) else { return nil }
                return array[index]
            default: return nil
            }
        }
    }

    /// Interpolates every binding in `template`; missing values become "".
    public func string(_ template: String) -> String {
        let range = NSRange(template.startIndex..., in: template)
        var result = template
        for match in Self.binding.matches(in: template, range: range).reversed() {
            guard let whole = Range(match.range, in: template),
                  let path = Range(match.range(at: 1), in: template) else { continue }
            let value = resolve(String(template[path]))?.displayString ?? ""
            result.replaceSubrange(whole, with: value)
        }
        return result
    }

    /// Resolves an optional prop, treating an empty result as absent.
    public func optionalString(_ template: String?) -> String? {
        guard let template else { return nil }
        let value = string(template)
        return value.isEmpty ? nil : value
    }

    // Matches {{ path.to.value }}; the pattern is a constant, so try! cannot fail at runtime.
    private static let binding = try! NSRegularExpression(pattern: #"\{\{\s*([\w.]+)\s*\}\}"#)
}
