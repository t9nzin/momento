package com.tenzin.momento.sdui.validation;

import com.fasterxml.jackson.databind.JsonNode;
import com.tenzin.momento.sdui.schema.ComponentTypes;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Each component and action carries the fields its type needs to render.
 * Fields are dotted paths relative to the node, e.g. {@code props.text}.
 */
final class RequiredPropsRule implements ValidationRule {

    private static final Map<String, List<String>> REQUIRED_BY_COMPONENT = Map.of(
            ComponentTypes.COLUMN, List.of("children"),
            ComponentTypes.ROW, List.of("children"),
            ComponentTypes.TEXT, List.of("props.text"),
            ComponentTypes.IMAGE, List.of("props.url"),
            ComponentTypes.CARD, List.of("props.title"),
            ComponentTypes.GRID, List.of("props.columns", "props.itemsBinding", "template"),
            ComponentTypes.LIST, List.of("props.itemsBinding", "template"),
            ComponentTypes.BUTTON, List.of("props.label", "action"),
            ComponentTypes.SPACER, List.of("props.size"));

    private static final Map<String, List<String>> REQUIRED_BY_ACTION = Map.of(
            "navigate", List.of("screenId"),
            "request", List.of("method", "path"));

    @Override
    public List<ValidationError> check(JsonNode screen) {
        var errors = new ArrayList<ValidationError>();
        ScreenTree.walk(screen, visit -> {
            var node = visit.node();
            var required = REQUIRED_BY_COMPONENT.getOrDefault(visit.type(), List.of());
            checkFields(node, required, visit.path(), visit.type(), errors);

            var action = node.path("action");
            if (action.isObject()) {
                var actionType = action.path("type").asText();
                var requiredByAction = REQUIRED_BY_ACTION.getOrDefault(actionType, List.of());
                checkFields(action, requiredByAction, visit.path() + ".action", actionType, errors);
            }
        });
        return errors;
    }

    private static void checkFields(JsonNode node, List<String> fields, String path, String type,
                                    List<ValidationError> errors) {
        for (var field : fields) {
            var value = BindingPaths.resolve(node, field);
            if (value.isEmpty() || value.get().isNull()) {
                errors.add(new ValidationError(path, type + " is missing required field '" + field + "'"));
            }
        }
    }
}
