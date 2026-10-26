package com.tenzin.momento.sdui.web;

import com.tenzin.momento.sdui.schema.Screen;
import com.tenzin.momento.sdui.screen.ClientContext;
import com.tenzin.momento.sdui.screen.ScreenRequest;
import com.tenzin.momento.sdui.screen.ScreenService;
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

    private final ScreenService screens;

    public ScreenController(ScreenService screens) {
        this.screens = screens;
    }

    @GetMapping("/{screenId}")
    public Screen screen(@PathVariable String screenId,
                         @RequestParam Map<String, String> params,
                         @RequestHeader(value = ClientHeaders.USER_ID, required = false) String userId,
                         @RequestHeader(value = ClientHeaders.PLATFORM, required = false) String platform,
                         @RequestHeader(value = ClientHeaders.SCHEMA_VERSION, required = false) String schemaVersion,
                         @RequestHeader(value = ClientHeaders.SUPPORTED_COMPONENTS, required = false) String supported) {
        var client = ClientContext.fromHeaders(userId, platform, schemaVersion, supported);
        return screens.render(new ScreenRequest(screenId, params, client));
    }
}
