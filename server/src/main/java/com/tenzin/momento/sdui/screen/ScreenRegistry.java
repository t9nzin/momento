package com.tenzin.momento.sdui.screen;

import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

@Component
public class ScreenRegistry {

    private final Map<String, ScreenProvider> providers;

    public ScreenRegistry(List<ScreenProvider> providers) {
        // toMap throws on duplicate keys, so two providers claiming one id fail at startup.
        this.providers = providers.stream()
                .collect(Collectors.toUnmodifiableMap(ScreenProvider::screenId, Function.identity()));
    }

    public Optional<ScreenProvider> find(String screenId) {
        return Optional.ofNullable(providers.get(screenId));
    }

    public Set<String> screenIds() {
        return providers.keySet();
    }
}
