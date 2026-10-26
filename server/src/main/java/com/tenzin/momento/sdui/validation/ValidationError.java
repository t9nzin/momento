package com.tenzin.momento.sdui.validation;

/**
 * @param path where in the screen the problem is, e.g. {@code root.children[2].template}
 */
public record ValidationError(String path, String message) {

    @Override
    public String toString() {
        return path + ": " + message;
    }
}
