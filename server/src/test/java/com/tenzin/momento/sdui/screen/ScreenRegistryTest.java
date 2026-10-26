package com.tenzin.momento.sdui.screen;

import com.tenzin.momento.sdui.schema.Screen;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ScreenRegistryTest {

    @Test
    void findsProvidersById() {
        var registry = new ScreenRegistry(List.of(stub("a"), stub("b")));

        assertThat(registry.find("b")).get().extracting(ScreenProvider::screenId).isEqualTo("b");
        assertThat(registry.find("missing")).isEmpty();
        assertThat(registry.screenIds()).containsExactlyInAnyOrder("a", "b");
    }

    @Test
    void rejectsTwoProvidersWithTheSameId() {
        assertThatThrownBy(() -> new ScreenRegistry(List.of(stub("a"), stub("a"))))
                .isInstanceOf(IllegalStateException.class);
    }

    private static ScreenProvider stub(String id) {
        return new ScreenProvider() {
            @Override
            public String screenId() {
                return id;
            }

            @Override
            public Screen build(ScreenRequest request) {
                throw new UnsupportedOperationException();
            }
        };
    }
}
