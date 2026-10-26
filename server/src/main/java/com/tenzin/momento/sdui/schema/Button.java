package com.tenzin.momento.sdui.schema;

public record Button(String id, Props props, Action action) implements Component {

    /** @param style {@code primary} or {@code secondary} */
    public record Props(String label, String style) {
    }
}
