package com.tenzin.momento.sdui.schema;

public record Image(String id, Props props) implements Component {

    /** @param aspectRatio width / height; clients reserve space before the image loads */
    public record Props(String url, String alt, Double aspectRatio) {
    }
}
