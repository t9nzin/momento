package com.tenzin.momento.sdui.schema;

public record Spacer(String id, Props props) implements Component {

    public record Props(int size) {
    }
}
