package com.tenzin.momento.sdui.web;

import com.tenzin.momento.sdui.schema.Screen;
import com.tenzin.momento.sdui.screen.ClientContext;
import com.tenzin.momento.sdui.screen.ScreenRequest;
import com.tenzin.momento.sdui.screen.ScreenService;
import com.tenzin.momento.sdui.variant.VariantAssigner;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/screens")
public class ScreenController {

    /** Response header telling the client which variant it was served. Handy for the dev panel and analytics. */
    public static final String VARIANT_HEADER = "X-Variant";

    private final ScreenService screens;
    private final VariantAssigner variants;

    public ScreenController(ScreenService screens, VariantAssigner variants) {
        this.screens = screens;
        this.variants = variants;
    }

    @GetMapping("/{screenId}")
    public ResponseEntity<Screen> screen(@PathVariable String screenId,
                         @RequestParam Map<String, String> params,
                         @RequestHeader(value = ClientHeaders.USER_ID, required = false) String userId,
                         @RequestHeader(value = ClientHeaders.PLATFORM, required = false) String platform,
                         @RequestHeader(value = ClientHeaders.SCHEMA_VERSION, required = false) String schemaVersion,
                         @RequestHeader(value = ClientHeaders.SUPPORTED_COMPONENTS, required = false) String supported) {
        var client = ClientContext.fromHeaders(userId, platform, schemaVersion, supported);
        var variant = variants.resolve(client.userId(), params.get("variant"));
        var screen = screens.render(new ScreenRequest(screenId, params, client, variant));
        return ResponseEntity.ok().header(VARIANT_HEADER, variant.name()).body(screen);
    }
}
