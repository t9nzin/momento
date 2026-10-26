package com.tenzin.momento.sdui.validation;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.tenzin.momento.sdui.Fixtures;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ScreenValidatorTest {

    private static final ObjectMapper JSON = new ObjectMapper();
    private final ScreenValidator validator = new ScreenValidator();

    @Test
    void acceptsAValidScreen() {
        var screen = screen("""
                {"type": "column", "id": "root", "children": [
                  {"type": "text", "id": "t", "props": {"text": "Hello {{name}}"}}
                ]}""", """
                {"name": "Momento"}""");

        assertThat(validator.validate(screen)).isEmpty();
    }

    @ParameterizedTest
    @ValueSource(strings = {"gallery.json", "item-detail.json"})
    void acceptsEverySharedFixture(String fixture) throws JsonProcessingException {
        assertThat(validator.validate(JSON.readTree(Fixtures.read(fixture)))).isEmpty();
    }

    @Test
    void validateOrThrowCarriesTheErrors() {
        var screen = screen("""
                {"type": "carousel", "id": "root"}""", "{}");

        assertThatThrownBy(() -> validator.validateOrThrow(screen))
                .isInstanceOfSatisfying(InvalidScreenException.class,
                        e -> assertThat(e.errors()).extracting(ValidationError::path).containsExactly("root"));
    }

    @Nested
    class UniqueIds {

        @Test
        void flagsDuplicateIdsAnywhereInTheTree() {
            var screen = screen("""
                    {"type": "column", "id": "root", "children": [
                      {"type": "text", "id": "same", "props": {"text": "a"}},
                      {"type": "row", "id": "row", "children": [
                        {"type": "text", "id": "same", "props": {"text": "b"}}
                      ]}
                    ]}""", "{}");

            assertThat(messages(new UniqueIdsRule(), screen))
                    .containsExactly("root.children[1].children[0]: duplicate id 'same' (first used at root.children[0])");
        }

        @Test
        void flagsMissingIds() {
            var screen = screen("""
                    {"type": "column", "id": "root", "children": [{"type": "spacer", "props": {"size": 4}}]}""", "{}");

            assertThat(messages(new UniqueIdsRule(), screen))
                    .containsExactly("root.children[0]: component is missing an id");
        }
    }

    @Nested
    class KnownTypes {

        @Test
        void flagsUnknownComponentTypes() {
            var screen = screen("""
                    {"type": "column", "id": "root", "children": [{"type": "carousel", "id": "c"}]}""", "{}");

            assertThat(messages(new KnownTypesRule(), screen))
                    .containsExactly("root.children[0]: unknown component type 'carousel'");
        }

        @Test
        void flagsUnknownActionTypes() {
            var screen = screen("""
                    {"type": "button", "id": "b", "props": {"label": "Go"}, "action": {"type": "teleport"}}""", "{}");

            assertThat(messages(new KnownTypesRule(), screen))
                    .containsExactly("root.action: unknown action type 'teleport'");
        }

        @Test
        void checksTemplatesToo() {
            var screen = screen("""
                    {"type": "list", "id": "l", "props": {"itemsBinding": "xs"}, "template": {"type": "video", "id": "v"}}""",
                    """
                    {"xs": []}""");

            assertThat(messages(new KnownTypesRule(), screen))
                    .containsExactly("root.template: unknown component type 'video'");
        }
    }

    @Nested
    class RequiredProps {

        @Test
        void flagsMissingProps() {
            var screen = screen("""
                    {"type": "column", "id": "root", "children": [
                      {"type": "text", "id": "t", "props": {"style": "title"}},
                      {"type": "image", "id": "i"}
                    ]}""", "{}");

            assertThat(messages(new RequiredPropsRule(), screen)).containsExactly(
                    "root.children[0]: text is missing required field 'props.text'",
                    "root.children[1]: image is missing required field 'props.url'");
        }

        @Test
        void gridNeedsColumnsBindingAndTemplate() {
            var screen = screen("""
                    {"type": "grid", "id": "g", "props": {}}""", "{}");

            assertThat(messages(new RequiredPropsRule(), screen)).containsExactly(
                    "root: grid is missing required field 'props.columns'",
                    "root: grid is missing required field 'props.itemsBinding'",
                    "root: grid is missing required field 'template'");
        }

        @Test
        void containersNeedChildren() {
            var screen = screen("""
                    {"type": "row", "id": "r"}""", "{}");

            assertThat(messages(new RequiredPropsRule(), screen))
                    .containsExactly("root: row is missing required field 'children'");
        }

        @Test
        void actionsNeedTheirFields() {
            var screen = screen("""
                    {"type": "button", "id": "b", "props": {"label": "Save"}, "action": {"type": "request", "method": "POST"}}""",
                    "{}");

            assertThat(messages(new RequiredPropsRule(), screen))
                    .containsExactly("root.action: request is missing required field 'path'");
        }

        @Test
        void nullCountsAsMissing() {
            var screen = screen("""
                    {"type": "text", "id": "t", "props": {"text": null}}""", "{}");

            assertThat(messages(new RequiredPropsRule(), screen))
                    .containsExactly("root: text is missing required field 'props.text'");
        }
    }

    @Nested
    class Bindings {

        @Test
        void flagsBindingsMissingFromData() {
            var screen = screen("""
                    {"type": "text", "id": "t", "props": {"text": "{{user.name}} has {{count}}"}}""", """
                    {"user": {"name": "Tenzin"}}""");

            assertThat(messages(new BindingsRule(), screen))
                    .containsExactly("root: binding '{{count}}' does not resolve against data");
        }

        @Test
        void resolvesItemBindingsAgainstEveryTemplateItem() {
            var screen = screen("""
                    {"type": "grid", "id": "g", "props": {"columns": 2, "itemsBinding": "items"},
                     "template": {"type": "card", "id": "c", "props": {"title": "{{item.title}}", "imageUrl": "{{item.imageUrl}}"}}}""",
                    """
                    {"items": [{"title": "a", "imageUrl": "x"}, {"title": "b"}]}""");

            assertThat(messages(new BindingsRule(), screen))
                    .containsExactly("root.template: binding '{{item.imageUrl}}' does not resolve on 1 of 2 items");
        }

        @Test
        void flagsItemBindingsOutsideTemplates() {
            var screen = screen("""
                    {"type": "text", "id": "t", "props": {"text": "{{item.title}}"}}""", "{}");

            assertThat(messages(new BindingsRule(), screen))
                    .containsExactly("root: binding '{{item.title}}' uses item outside a grid or list template");
        }

        @Test
        void itemsBindingMustPointAtAnArray() {
            var screen = screen("""
                    {"type": "list", "id": "l", "props": {"itemsBinding": "items"},
                     "template": {"type": "text", "id": "t", "props": {"text": "x"}}}""", """
                    {"items": "not an array"}""");

            assertThat(messages(new BindingsRule(), screen))
                    .containsExactly("root: itemsBinding 'items' does not point at an array in data");
        }

        @Test
        void checksBindingsInActionParams() {
            var screen = screen("""
                    {"type": "list", "id": "l", "props": {"itemsBinding": "items"},
                     "template": {"type": "card", "id": "c", "props": {"title": "{{item.title}}"},
                       "action": {"type": "navigate", "screenId": "detail", "params": {"id": "{{item.uuid}}"}}}}""",
                    """
                    {"items": [{"title": "a", "id": "1"}]}""");

            assertThat(messages(new BindingsRule(), screen))
                    .containsExactly("root.template: binding '{{item.uuid}}' does not resolve on 1 of 1 items");
        }

        @Test
        void emptyListsCannotBeCheckedSoPass() {
            var screen = screen("""
                    {"type": "list", "id": "l", "props": {"itemsBinding": "items"},
                     "template": {"type": "text", "id": "t", "props": {"text": "{{item.anything}}"}}}""", """
                    {"items": []}""");

            assertThat(messages(new BindingsRule(), screen)).isEmpty();
        }

        @Test
        void supportsArrayIndexSegments() {
            var screen = screen("""
                    {"type": "text", "id": "t", "props": {"text": "{{items.0.title}} / {{items.5.title}}"}}""", """
                    {"items": [{"title": "first"}]}""");

            assertThat(messages(new BindingsRule(), screen))
                    .containsExactly("root: binding '{{items.5.title}}' does not resolve against data");
        }
    }

    private static JsonNode screen(String root, String data) {
        try {
            return JSON.readTree("""
                    {"schemaVersion": 1, "screenId": "test", "title": "Test", "data": %s, "root": %s}"""
                    .formatted(data, root));
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException(e);
        }
    }

    private static List<String> messages(ValidationRule rule, JsonNode screen) {
        return rule.check(screen).stream().map(ValidationError::toString).toList();
    }
}
