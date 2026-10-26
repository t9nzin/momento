package com.tenzin.momento.sdui.variant;

import org.junit.jupiter.api.Test;

import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class VariantAssignerTest {

    private final VariantAssigner assigner = new VariantAssigner();

    @Test
    void sameUserAlwaysGetsTheSameVariant() {
        var first = assigner.assign("user-123");

        IntStream.range(0, 100).forEach(i -> assertThat(new VariantAssigner().assign("user-123")).isEqualTo(first));
    }

    @Test
    void bucketsArePinned() {
        // If these change, every existing user silently switches arms. Change
        // the hash on purpose or not at all.
        assertThat(VariantAssigner.bucket("alice")).isEqualTo(0);
        assertThat(VariantAssigner.bucket("grace")).isEqualTo(78);
        assertThat(assigner.assign("alice")).isEqualTo(Variant.A);
        assertThat(assigner.assign("grace")).isEqualTo(Variant.B);
    }

    @Test
    void splitIsRoughlyEven() {
        var users = 10_000;
        var inA = IntStream.range(0, users).filter(i -> assigner.assign("user-" + i) == Variant.A).count();

        assertThat((double) inA / users).isBetween(0.47, 0.53);
    }

    @Test
    void bucketsSpreadAcrossTheWholeRange() {
        var distinct = IntStream.range(0, 5_000).map(i -> VariantAssigner.bucket("u" + i)).distinct().count();

        assertThat(distinct).isEqualTo(100);
    }

    @Test
    void overrideWinsOverTheBucket() {
        var natural = assigner.assign("user-123");
        var forced = natural == Variant.A ? "b" : "a";

        assertThat(assigner.resolve("user-123", forced)).isNotEqualTo(natural);
        assertThat(assigner.resolve("user-123", null)).isEqualTo(natural);
        assertThat(assigner.resolve("user-123", "")).isEqualTo(natural);
    }

    @Test
    void rejectsUnknownOverrides() {
        assertThatThrownBy(() -> assigner.resolve("u", "C")).isInstanceOf(IllegalArgumentException.class);
    }
}
