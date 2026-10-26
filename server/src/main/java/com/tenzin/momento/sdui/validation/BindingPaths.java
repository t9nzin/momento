package com.tenzin.momento.sdui.validation;

import com.fasterxml.jackson.databind.JsonNode;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.regex.Pattern;

/** Finds {@code {{path}}} bindings in strings and resolves dotted paths against JSON. */
final class BindingPaths {

    private static final Pattern BINDING = Pattern.compile("\\{\\{\\s*([\\w.]+)\\s*}}");

    private BindingPaths() {
    }

    static List<String> extract(String value) {
        var paths = new ArrayList<String>();
        var matcher = BINDING.matcher(value);
        while (matcher.find()) {
            paths.add(matcher.group(1));
        }
        return paths;
    }

    /** Resolves {@code a.b.0.c} against {@code root}; numeric segments index into arrays. */
    static Optional<JsonNode> resolve(JsonNode root, String path) {
        if (path.isEmpty()) {
            return Optional.of(root);
        }
        var current = root;
        for (var segment : path.split("\\.")) {
            if (current == null || current.isMissingNode() || current.isNull()) {
                return Optional.empty();
            }
            current = current.isArray() && segment.chars().allMatch(Character::isDigit)
                    ? current.get(Integer.parseInt(segment))
                    : current.get(segment);
        }
        return Optional.ofNullable(current).filter(node -> !node.isMissingNode());
    }

    static boolean isItemPath(String path) {
        return path.equals("item") || path.startsWith("item.");
    }

    /** {@code item.title} becomes {@code title}; {@code item} becomes empty. */
    static String stripItemPrefix(String path) {
        return path.equals("item") ? "" : path.substring("item.".length());
    }
}
