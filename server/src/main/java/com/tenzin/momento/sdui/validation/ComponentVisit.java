package com.tenzin.momento.sdui.validation;

import com.fasterxml.jackson.databind.JsonNode;

import java.util.List;

/**
 * One component reached while walking a screen tree.
 *
 * @param path       human-readable location, e.g. {@code root.children[1].template}
 * @param inTemplate whether this component sits inside a grid or list template
 * @param itemScope  the values {@code item} takes here; may be empty even in a template
 */
record ComponentVisit(JsonNode node, String path, boolean inTemplate, List<JsonNode> itemScope) {

    static ComponentVisit root(JsonNode node) {
        return new ComponentVisit(node, "root", false, List.of());
    }

    ComponentVisit child(JsonNode child, String childPath) {
        return new ComponentVisit(child, childPath, inTemplate, itemScope);
    }

    ComponentVisit template(JsonNode template, List<JsonNode> items) {
        return new ComponentVisit(template, path + ".template", true, items);
    }

    String type() {
        return node.path("type").asText(null);
    }

    String id() {
        return node.path("id").asText(null);
    }
}
