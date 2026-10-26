package com.tenzin.momento.sdui.screen;

import com.tenzin.momento.sdui.schema.ComponentTypes;
import com.tenzin.momento.sdui.schema.Screen;

import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * What the server knows about the client asking for a screen, taken from the
 * {@code X-*} request headers.
 *
 * @param supportedComponents component types the client can render natively
 */
public record ClientContext(String userId, Platform platform, int schemaVersion, Set<String> supportedComponents) {

    public static final String ANONYMOUS_USER = "anonymous";

    public ClientContext {
        supportedComponents = Set.copyOf(supportedComponents);
    }

    /**
     * Builds a context from raw header values, any of which may be null. A
     * missing component list means the client supports the whole current schema.
     */
    public static ClientContext fromHeaders(String userId, String platform, String schemaVersion,
                                            String supportedComponents) {
        return new ClientContext(
                userId == null || userId.isBlank() ? ANONYMOUS_USER : userId.trim(),
                Platform.fromHeader(platform),
                schemaVersion == null ? Screen.CURRENT_SCHEMA_VERSION : parseVersion(schemaVersion),
                supportedComponents == null ? ComponentTypes.ALL : parseList(supportedComponents));
    }

    public boolean supports(String componentType) {
        return supportedComponents.contains(componentType);
    }

    private static int parseVersion(String value) {
        try {
            return Integer.parseInt(value.trim());
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("X-Schema-Version must be an integer, got '" + value + "'");
        }
    }

    private static Set<String> parseList(String value) {
        return Arrays.stream(value.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .collect(Collectors.toUnmodifiableSet());
    }
}
