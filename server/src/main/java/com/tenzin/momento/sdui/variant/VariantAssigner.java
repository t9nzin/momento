package com.tenzin.momento.sdui.variant;

import org.springframework.stereotype.Component;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

/**
 * Buckets users into layout variants. The bucket is derived from a hash of the
 * user id, so it is stable across requests, restarts and server instances with
 * no assignment table to store.
 */
@Component
public class VariantAssigner {

    /** Percentage of users in variant A; the rest get B. */
    static final int PERCENT_IN_A = 50;

    /** Salting with the experiment name keeps buckets independent across future experiments. */
    private static final String EXPERIMENT = "gallery-layout";

    /** Uses the forced variant if one is given (for demos), otherwise the user's bucket. */
    public Variant resolve(String userId, String override) {
        return Variant.parse(override).orElseGet(() -> assign(userId));
    }

    public Variant assign(String userId) {
        return bucket(userId) < PERCENT_IN_A ? Variant.A : Variant.B;
    }

    /** Maps a user id to a stable bucket in [0, 100). */
    static int bucket(String userId) {
        var hash = sha256(EXPERIMENT + ":" + userId);
        return Math.floorMod(ByteBuffer.wrap(hash).getInt(), 100);
    }

    private static byte[] sha256(String input) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(input.getBytes(StandardCharsets.UTF_8));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is required by every JVM", e);
        }
    }
}
