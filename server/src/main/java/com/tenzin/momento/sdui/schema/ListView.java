package com.tenzin.momento.sdui.schema;

/**
 * Wire type {@code list}. Like {@link Grid} but a single vertical column.
 * Named {@code ListView} to avoid clashing with {@link java.util.List}.
 */
public record ListView(String id, Props props, Component template) implements Component {

    public record Props(String itemsBinding) {
    }
}
