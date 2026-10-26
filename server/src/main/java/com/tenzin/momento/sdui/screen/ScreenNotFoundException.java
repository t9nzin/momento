package com.tenzin.momento.sdui.screen;

public class ScreenNotFoundException extends RuntimeException {

    public ScreenNotFoundException(String screenId) {
        super("No screen with id '" + screenId + "'");
    }
}
