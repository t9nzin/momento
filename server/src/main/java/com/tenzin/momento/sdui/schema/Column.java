package com.tenzin.momento.sdui.schema;

import java.util.List;

/** Stacks children vertically. An optional action makes the whole column tappable. */
public record Column(String id, Props props, List<Component> children, Action action) implements Component {

    public record Props(Integer spacing) {
    }

    public Column(String id, List<Component> children) {
        this(id, null, children, null);
    }
}
