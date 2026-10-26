package com.tenzin.momento.sdui.screen;

import java.util.Map;
import java.util.Optional;

/**
 * Everything a {@link ScreenProvider} needs to build a screen.
 *
 * @param params route params from the query string, e.g. {@code itemId}
 */
public record ScreenRequest(String screenId, Map<String, String> params, ClientContext client) {

    public ScreenRequest {
        params = Map.copyOf(params);
    }

    public Optional<String> param(String name) {
        return Optional.ofNullable(params.get(name));
    }
}
