package com.tenzin.momento.sdui.validation;

import com.fasterxml.jackson.databind.JsonNode;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;

/**
 * Walks every component in a serialized screen, depth first, tracking which
 * {@code item} values are in scope inside grid and list templates.
 */
final class ScreenTree {

    private ScreenTree() {
    }

    static void walk(JsonNode screen, Consumer<ComponentVisit> visitor) {
        var root = screen.path("root");
        if (root.isObject()) {
            visit(ComponentVisit.root(root), screen.path("data"), visitor);
        }
    }

    private static void visit(ComponentVisit visit, JsonNode data, Consumer<ComponentVisit> visitor) {
        visitor.accept(visit);
        var node = visit.node();

        var children = node.path("children");
        for (int i = 0; i < children.size(); i++) {
            var childPath = visit.path() + ".children[" + i + "]";
            visit(visit.child(children.get(i), childPath), data, visitor);
        }

        var template = node.path("template");
        if (template.isObject()) {
            var itemScope = templateItems(node.path("props").path("itemsBinding").asText(""), data, visit);
            visit(visit.template(template, itemScope), data, visitor);
        }
    }

    /**
     * The elements a template will be stamped out for. An unresolvable binding
     * yields no items; {@link BindingsRule} reports that separately.
     */
    private static List<JsonNode> templateItems(String itemsBinding, JsonNode data, ComponentVisit parent) {
        var sources = BindingPaths.isItemPath(itemsBinding)
                ? parent.itemScope().stream()
                        .map(item -> BindingPaths.resolve(item, BindingPaths.stripItemPrefix(itemsBinding)))
                        .toList()
                : List.of(BindingPaths.resolve(data, itemsBinding));

        var items = new ArrayList<JsonNode>();
        sources.forEach(source -> source.filter(JsonNode::isArray).ifPresent(array -> array.forEach(items::add)));
        return items;
    }
}
