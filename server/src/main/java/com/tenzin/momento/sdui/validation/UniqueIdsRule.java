package com.tenzin.momento.sdui.validation;

import com.fasterxml.jackson.databind.JsonNode;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

/** Every component has an id, and no two components share one. */
final class UniqueIdsRule implements ValidationRule {

    @Override
    public List<ValidationError> check(JsonNode screen) {
        var errors = new ArrayList<ValidationError>();
        var firstSeenAt = new HashMap<String, String>();
        ScreenTree.walk(screen, visit -> {
            var id = visit.id();
            if (id == null || id.isBlank()) {
                errors.add(new ValidationError(visit.path(), "component is missing an id"));
                return;
            }
            var previous = firstSeenAt.putIfAbsent(id, visit.path());
            if (previous != null) {
                errors.add(new ValidationError(visit.path(), "duplicate id '" + id + "' (first used at " + previous + ")"));
            }
        });
        return errors;
    }
}
