package com.tenzin.momento.sdui.schema;

import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;

import java.util.Map;

/** Something a client does when the user taps a component. */
@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, property = "type")
@JsonSubTypes({
        @JsonSubTypes.Type(value = Action.Navigate.class, name = "navigate"),
        @JsonSubTypes.Type(value = Action.Request.class, name = "request"),
})
public sealed interface Action {

    /** Open another server-driven screen. */
    record Navigate(String screenId, Map<String, String> params) implements Action {
    }

    /** Call the API, then optionally re-fetch the current screen. */
    record Request(String method, String path, boolean refresh) implements Action {
    }
}
