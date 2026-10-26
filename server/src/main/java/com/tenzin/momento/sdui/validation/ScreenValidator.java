package com.tenzin.momento.sdui.validation;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Checks a serialized screen against the v1 contract. It validates JSON rather
 * than the Java records so it sees exactly what clients will receive, and so the
 * same checks can run over hand-written fixtures.
 */
@Component
public class ScreenValidator {

    private final List<ValidationRule> rules = List.of(
            new UniqueIdsRule(),
            new KnownTypesRule(),
            new RequiredPropsRule(),
            new BindingsRule());

    public List<ValidationError> validate(JsonNode screen) {
        return rules.stream().flatMap(rule -> rule.check(screen).stream()).toList();
    }

    public void validateOrThrow(JsonNode screen) {
        var errors = validate(screen);
        if (!errors.isEmpty()) {
            throw new InvalidScreenException(errors);
        }
    }
}
