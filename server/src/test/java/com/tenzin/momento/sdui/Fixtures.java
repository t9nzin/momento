package com.tenzin.momento.sdui;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Reads and writes the shared JSON fixtures in {@code /schema/fixtures}, which
 * the web client's tests render too.
 */
public final class Fixtures {

    public static final Path DIRECTORY = Path.of("..", "schema", "fixtures");

    /** Run tests with {@code -DupdateFixtures=true} to rewrite fixtures from current server output. */
    public static final boolean UPDATE = Boolean.getBoolean("updateFixtures");

    private Fixtures() {
    }

    public static String read(String name) {
        try {
            return Files.readString(DIRECTORY.resolve(name));
        } catch (IOException e) {
            throw new UncheckedIOException("Missing fixture " + name + "; run with -DupdateFixtures=true", e);
        }
    }

    public static void write(String name, String json) {
        try {
            Files.writeString(DIRECTORY.resolve(name), json + System.lineSeparator());
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}
