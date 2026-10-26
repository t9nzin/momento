package com.tenzin.momento.sdui.schema;

import java.util.Set;

/** Wire names for every component type in schema v1. */
public final class ComponentTypes {

    public static final String COLUMN = "column";
    public static final String ROW = "row";
    public static final String TEXT = "text";
    public static final String IMAGE = "image";
    public static final String CARD = "card";
    public static final String GRID = "grid";
    public static final String LIST = "list";
    public static final String BUTTON = "button";
    public static final String SPACER = "spacer";

    public static final Set<String> ALL =
            Set.of(COLUMN, ROW, TEXT, IMAGE, CARD, GRID, LIST, BUTTON, SPACER);

    private ComponentTypes() {
    }
}
