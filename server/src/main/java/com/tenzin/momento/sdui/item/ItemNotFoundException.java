package com.tenzin.momento.sdui.item;

public class ItemNotFoundException extends RuntimeException {

    public ItemNotFoundException(String id) {
        super("No item with id '" + id + "'");
    }
}
