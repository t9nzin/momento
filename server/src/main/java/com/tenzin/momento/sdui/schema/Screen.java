package com.tenzin.momento.sdui.schema;

import java.util.Map;

/**
 * A full screen: the component tree plus the data its bindings resolve against.
 */
public record Screen(int schemaVersion, String screenId, String title, Map<String, Object> data, Component root) {

    public static final int CURRENT_SCHEMA_VERSION = 1;

    public Screen withRoot(Component newRoot) {
        return new Screen(schemaVersion, screenId, title, data, newRoot);
    }
}
