package com.tenzin.momento.sdui.validation;

import com.fasterxml.jackson.databind.JsonNode;
import com.tenzin.momento.sdui.schema.ComponentTypes;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/** Every component and action has a type from the v1 schema. */
final class KnownTypesRule implements ValidationRule {

    private static final Set<String> ACTION_TYPES = Set.of("navigate", "request");

    @Override
    public List<ValidationError> check(JsonNode screen) {
        var errors = new ArrayList<ValidationError>();
        ScreenTree.walk(screen, visit -> {
            if (!ComponentTypes.ALL.contains(visit.type())) {
                errors.add(new ValidationError(visit.path(), "unknown component type '" + visit.type() + "'"));
            }
            var action = visit.node().path("action");
            if (action.isObject() && !ACTION_TYPES.contains(action.path("type").asText())) {
                errors.add(new ValidationError(visit.path() + ".action",
                        "unknown action type '" + action.path("type").asText(null) + "'"));
            }
        });
        return errors;
    }
}
