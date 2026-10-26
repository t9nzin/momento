package com.tenzin.momento.sdui.validation;

import com.fasterxml.jackson.databind.JsonNode;

import java.util.ArrayList;
import java.util.List;

/**
 * Every {@code {{path}}} in props and actions resolves against the screen's
 * data, or against {@code item} inside a template. Every {@code itemsBinding}
 * points at an array.
 */
final class BindingsRule implements ValidationRule {

    @Override
    public List<ValidationError> check(JsonNode screen) {
        var data = screen.path("data");
        var errors = new ArrayList<ValidationError>();
        ScreenTree.walk(screen, visit -> {
            checkItemsBinding(visit, data, errors);
            checkStrings(visit.node().path("props"), visit, data, errors);
            checkStrings(visit.node().path("action"), visit, data, errors);
        });
        return errors;
    }

    private static void checkItemsBinding(ComponentVisit visit, JsonNode data, List<ValidationError> errors) {
        var itemsBinding = visit.node().path("props").path("itemsBinding");
        if (!itemsBinding.isTextual()) {
            return;
        }
        var path = itemsBinding.asText();
        if (BindingPaths.isItemPath(path)) {
            var samples = visit.itemScope();
            var relative = BindingPaths.stripItemPrefix(path);
            if (!visit.inTemplate() || samples.stream().anyMatch(item -> !isArrayAt(item, relative))) {
                errors.add(new ValidationError(visit.path(), "itemsBinding '" + path + "' is not an array on every item"));
            }
        } else if (!isArrayAt(data, path)) {
            errors.add(new ValidationError(visit.path(), "itemsBinding '" + path + "' does not point at an array in data"));
        }
    }

    private static boolean isArrayAt(JsonNode root, String path) {
        return BindingPaths.resolve(root, path).map(JsonNode::isArray).orElse(false);
    }

    /** Recurses through objects and arrays, checking every string value. */
    private static void checkStrings(JsonNode node, ComponentVisit visit, JsonNode data, List<ValidationError> errors) {
        if (node.isTextual()) {
            BindingPaths.extract(node.asText()).forEach(path -> checkBinding(path, visit, data, errors));
        } else if (node.isContainerNode()) {
            node.forEach(child -> checkStrings(child, visit, data, errors));
        }
    }

    private static void checkBinding(String path, ComponentVisit visit, JsonNode data, List<ValidationError> errors) {
        if (!BindingPaths.isItemPath(path)) {
            if (BindingPaths.resolve(data, path).isEmpty()) {
                errors.add(new ValidationError(visit.path(), "binding '{{" + path + "}}' does not resolve against data"));
            }
            return;
        }
        if (!visit.inTemplate()) {
            errors.add(new ValidationError(visit.path(), "binding '{{" + path + "}}' uses item outside a grid or list template"));
            return;
        }
        var relative = BindingPaths.stripItemPrefix(path);
        var unresolved = visit.itemScope().stream()
                .filter(item -> BindingPaths.resolve(item, relative).isEmpty())
                .count();
        if (unresolved > 0) {
            errors.add(new ValidationError(visit.path(),
                    "binding '{{" + path + "}}' does not resolve on " + unresolved + " of " + visit.itemScope().size() + " items"));
        }
    }
}
