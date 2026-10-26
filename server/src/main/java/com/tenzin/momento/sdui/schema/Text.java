package com.tenzin.momento.sdui.schema;

public record Text(String id, Props props) implements Component {

    /** @param style one of {@code title}, {@code headline}, {@code body}, {@code caption} */
    public record Props(String text, String style) {
    }

    public Text(String id, String text, String style) {
        this(id, new Props(text, style));
    }
}
