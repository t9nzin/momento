package com.tenzin.momento.sdui.web;

/** Request headers clients send to describe themselves. */
public final class ClientHeaders {

    public static final String USER_ID = "X-User-Id";
    public static final String PLATFORM = "X-Platform";
    public static final String SCHEMA_VERSION = "X-Schema-Version";
    public static final String SUPPORTED_COMPONENTS = "X-Supported-Components";

    private ClientHeaders() {
    }
}
