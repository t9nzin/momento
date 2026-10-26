package com.tenzin.momento.sdui.validation;

import com.fasterxml.jackson.databind.JsonNode;

import java.util.List;

/** One independent check over a serialized screen. */
interface ValidationRule {

    List<ValidationError> check(JsonNode screen);
}
