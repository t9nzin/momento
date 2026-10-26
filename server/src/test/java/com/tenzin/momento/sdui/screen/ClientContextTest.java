package com.tenzin.momento.sdui.screen;

import com.tenzin.momento.sdui.schema.ComponentTypes;
import org.junit.jupiter.api.Test;

import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ClientContextTest {

    @Test
    void parsesAllHeaders() {
        var context = ClientContext.fromHeaders("u-42", "iOS", "1", " column, text ,,grid ");

        assertThat(context.userId()).isEqualTo("u-42");
        assertThat(context.platform()).isEqualTo(Platform.IOS);
        assertThat(context.schemaVersion()).isEqualTo(1);
        assertThat(context.supportedComponents()).containsExactlyInAnyOrder("column", "text", "grid");
    }

    @Test
    void missingHeadersFallBackToDefaults() {
        var context = ClientContext.fromHeaders(null, null, null, null);

        assertThat(context.userId()).isEqualTo(ClientContext.ANONYMOUS_USER);
        assertThat(context.platform()).isEqualTo(Platform.UNKNOWN);
        assertThat(context.supportedComponents()).isEqualTo(ComponentTypes.ALL);
    }

    @Test
    void emptyComponentListMeansNothingIsSupported() {
        assertThat(ClientContext.fromHeaders(null, null, null, "").supportedComponents()).isEqualTo(Set.of());
    }

    @Test
    void rejectsNonNumericSchemaVersion() {
        assertThatThrownBy(() -> ClientContext.fromHeaders(null, null, "v1", null))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
