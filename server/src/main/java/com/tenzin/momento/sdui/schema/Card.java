package com.tenzin.momento.sdui.schema;

/** An image with a title and optional subtitle underneath. */
public record Card(String id, Props props, Action action) implements Component {

    public record Props(String imageUrl, String title, String subtitle) {
    }
}
