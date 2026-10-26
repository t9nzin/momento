package com.tenzin.momento.sdui.screen;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tenzin.momento.sdui.fallback.FallbackTransformer;
import com.tenzin.momento.sdui.schema.Screen;
import com.tenzin.momento.sdui.validation.ScreenValidator;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/**
 * The screen pipeline: look up the provider, build the screen, rewrite any
 * components the client can't render, then validate the serialized result
 * before it leaves the server.
 */
@Service
public class ScreenService {

    private final ScreenRegistry registry;
    private final FallbackTransformer fallback;
    private final ScreenValidator validator;
    private final ObjectMapper objectMapper;
    private final boolean validateResponses;

    public ScreenService(ScreenRegistry registry, FallbackTransformer fallback, ScreenValidator validator,
                         ObjectMapper objectMapper, @Value("${sdui.validate-responses:true}") boolean validateResponses) {
        this.registry = registry;
        this.fallback = fallback;
        this.validator = validator;
        this.objectMapper = objectMapper;
        this.validateResponses = validateResponses;
    }

    public Screen render(ScreenRequest request) {
        var provider = registry.find(request.screenId())
                .orElseThrow(() -> new ScreenNotFoundException(request.screenId()));
        var screen = fallback.apply(provider.build(request), request.client());
        if (validateResponses) {
            validator.validateOrThrow(objectMapper.valueToTree(screen));
        }
        return screen;
    }
}
