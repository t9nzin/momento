package com.tenzin.momento.sdui.schema;

import java.util.List;

/** Lays children out horizontally. */
public record Row(String id, Props props, List<Component> children, Action action) implements Component {

    public record Props(Integer spacing) {
    }

    public Row(String id, List<Component> children) {
        this(id, null, children, null);
    }
}
