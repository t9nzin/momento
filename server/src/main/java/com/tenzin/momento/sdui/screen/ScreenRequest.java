package com.tenzin.momento.sdui.screen;

import com.tenzin.momento.sdui.variant.Variant;

import java.util.Map;
import java.util.Optional;

/**
 * Everything a {@link ScreenProvider} needs to build a screen.
 *
 * @param params  route params from the query string, e.g. {@code itemId}
 * @param variant the layout variant this user is bucketed into (or forced to)
 */
public record ScreenRequest(String screenId, Map<String, String> params, ClientContext client, Variant variant) {

    public ScreenRequest {
        params = Map.copyOf(params);
    }

    public Optional<String> param(String name) {
        return Optional.ofNullable(params.get(name));
    }
}
