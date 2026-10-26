package com.tenzin.momento.sdui.screen;

import java.util.Locale;

public enum Platform {
    WEB, IOS, UNKNOWN;

    public static Platform fromHeader(String value) {
        if (value == null) {
            return UNKNOWN;
        }
        return switch (value.trim().toLowerCase(Locale.ROOT)) {
            case "web" -> WEB;
            case "ios" -> IOS;
            default -> UNKNOWN;
        };
    }
}
