package com.tenzin.momento.sdui.variant;

import java.util.Locale;
import java.util.Optional;

/** Gallery layout experiment arms. */
public enum Variant {
    /** Two-column grid of cards. */
    A,
    /** Single-column list with larger images. */
    B;

    public static Optional<Variant> parse(String value) {
        if (value == null || value.isBlank()) {
            return Optional.empty();
        }
        try {
            return Optional.of(valueOf(value.trim().toUpperCase(Locale.ROOT)));
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Unknown variant '" + value + "'; expected A or B");
        }
    }
}
