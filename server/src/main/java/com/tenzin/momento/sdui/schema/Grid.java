package com.tenzin.momento.sdui.schema;

/**
 * Renders {@code template} once per element of the array at {@code itemsBinding},
 * laid out in {@code columns} columns. Inside the template, {@code {{item.*}}}
 * refers to the current element.
 */
public record Grid(String id, Props props, Component template) implements Component {

    public record Props(int columns, String itemsBinding) {
    }
}
