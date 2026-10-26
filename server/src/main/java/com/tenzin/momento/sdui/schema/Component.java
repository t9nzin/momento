package com.tenzin.momento.sdui.schema;

import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;

/**
 * A node in a screen's component tree. Serialized with a {@code type}
 * discriminator so clients can switch on it.
 */
@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, property = "type")
@JsonSubTypes({
        @JsonSubTypes.Type(value = Column.class, name = ComponentTypes.COLUMN),
        @JsonSubTypes.Type(value = Row.class, name = ComponentTypes.ROW),
        @JsonSubTypes.Type(value = Text.class, name = ComponentTypes.TEXT),
        @JsonSubTypes.Type(value = Image.class, name = ComponentTypes.IMAGE),
        @JsonSubTypes.Type(value = Card.class, name = ComponentTypes.CARD),
        @JsonSubTypes.Type(value = Grid.class, name = ComponentTypes.GRID),
        @JsonSubTypes.Type(value = ListView.class, name = ComponentTypes.LIST),
        @JsonSubTypes.Type(value = Button.class, name = ComponentTypes.BUTTON),
        @JsonSubTypes.Type(value = Spacer.class, name = ComponentTypes.SPACER),
})
public sealed interface Component permits Column, Row, Text, Image, Card, Grid, ListView, Button, Spacer {

    String id();

    /** The wire name of this component, e.g. {@code "grid"}. */
    default String type() {
        return switch (this) {
            case Column c -> ComponentTypes.COLUMN;
            case Row r -> ComponentTypes.ROW;
            case Text t -> ComponentTypes.TEXT;
            case Image i -> ComponentTypes.IMAGE;
            case Card c -> ComponentTypes.CARD;
            case Grid g -> ComponentTypes.GRID;
            case ListView l -> ComponentTypes.LIST;
            case Button b -> ComponentTypes.BUTTON;
            case Spacer s -> ComponentTypes.SPACER;
        };
    }
}
