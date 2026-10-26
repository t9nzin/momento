package com.tenzin.momento.sdui.fallback;

import com.tenzin.momento.sdui.schema.Action;
import com.tenzin.momento.sdui.schema.Card;
import com.tenzin.momento.sdui.schema.Column;
import com.tenzin.momento.sdui.schema.Component;
import com.tenzin.momento.sdui.schema.ComponentTypes;
import com.tenzin.momento.sdui.schema.Grid;
import com.tenzin.momento.sdui.schema.Image;
import com.tenzin.momento.sdui.schema.ListView;
import com.tenzin.momento.sdui.schema.Row;
import com.tenzin.momento.sdui.schema.Text;
import com.tenzin.momento.sdui.screen.ClientContext;
import com.tenzin.momento.sdui.screen.Platform;
import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

class FallbackTransformerTest {

    private static final Action OPEN_ITEM = new Action.Navigate("item-detail", Map.of("itemId", "{{item.id}}"));
    private static final Card CARD = new Card("card",
            new Card.Props("{{item.imageUrl}}", "{{item.title}}", "{{item.year}}"), OPEN_ITEM);
    private static final Grid GRID = new Grid("items", new Grid.Props(2, "items"), CARD);

    private final FallbackTransformer transformer = new FallbackTransformer();

    @Test
    void leavesTheTreeAloneWhenEverythingIsSupported() {
        var root = new Column("root", List.of(new Text("t", "hi", "body"), GRID));

        assertThat(transformer.transform(root, clientSupportingAllBut())).isEqualTo(root);
    }

    @Test
    void gridBecomesListWithTheSameTemplateAndBinding() {
        var result = transformer.transform(GRID, clientSupportingAllBut(ComponentTypes.GRID));

        assertThat(result).isEqualTo(new ListView("items", new ListView.Props("items"), CARD));
    }

    @Test
    void cardBecomesColumnOfImageAndTextsKeepingItsAction() {
        var result = transformer.transform(CARD, clientSupportingAllBut(ComponentTypes.CARD));

        assertThat(result).isEqualTo(new Column("card", new Column.Props(4), List.of(
                new Image("card-image", new Image.Props("{{item.imageUrl}}", "{{item.title}}", 1.0)),
                new Text("card-title", "{{item.title}}", "headline"),
                new Text("card-subtitle", "{{item.year}}", "caption")),
                OPEN_ITEM));
    }

    @Test
    void cardWithoutImageOrSubtitleBecomesJustATitle() {
        var bare = new Card("c", new Card.Props(null, "Title", null), null);

        var result = transformer.transform(bare, clientSupportingAllBut(ComponentTypes.CARD));

        assertThat(result).isEqualTo(new Column("c", new Column.Props(4), List.of(new Text("c-title", "Title", "headline")), null));
    }

    @Test
    void rowBecomesColumn() {
        var row = new Row("r", new Row.Props(8), List.of(new Text("t", "x", "body")), null);

        var result = transformer.transform(row, clientSupportingAllBut(ComponentTypes.ROW));

        assertThat(result).isEqualTo(new Column("r", new Column.Props(8), List.of(new Text("t", "x", "body")), null));
    }

    @Test
    void rewritesInsideTemplatesAndNestedChildren() {
        var root = new Column("root", List.of(new Column("inner", List.of(GRID))));

        var result = transformer.transform(root, clientSupportingAllBut(ComponentTypes.GRID, ComponentTypes.CARD));

        var list = (ListView) ((Column) ((Column) result).children().get(0)).children().get(0);
        assertThat(list.template()).isInstanceOf(Column.class);
        assertThat(((Column) list.template()).action()).isEqualTo(OPEN_ITEM);
        assertThat(typesIn(result)).doesNotContain(ComponentTypes.GRID, ComponentTypes.CARD);
    }

    @Test
    void appliesEveryRuleInOnePass() {
        var client = clientSupportingAllBut(ComponentTypes.GRID, ComponentTypes.CARD, ComponentTypes.ROW);
        var root = new Row("root", null, List.of(GRID), null);

        var result = transformer.transform(root, client);

        assertThat(typesIn(result)).containsOnly(
                ComponentTypes.COLUMN, ComponentTypes.LIST, ComponentTypes.IMAGE, ComponentTypes.TEXT);
    }

    @Test
    void keepsTheOriginalWhenNoFallbackIsSupportedEither() {
        var client = clientSupportingAllBut(ComponentTypes.GRID, ComponentTypes.LIST);

        var result = transformer.transform(GRID, client);

        assertThat(result).isEqualTo(GRID);
    }

    @Test
    void keepsComponentIdsUniqueAfterRewriting() {
        var root = new Column("root", List.of(GRID));

        var result = transformer.transform(root, clientSupportingAllBut(ComponentTypes.CARD));

        assertThat(idsIn(result)).doesNotHaveDuplicates();
    }

    private static ClientContext clientSupportingAllBut(String... unsupported) {
        var supported = new HashSet<>(ComponentTypes.ALL);
        List.of(unsupported).forEach(supported::remove);
        return new ClientContext("u", Platform.WEB, 1, supported);
    }

    private static Set<String> typesIn(Component component) {
        var types = new HashSet<String>();
        walk(component, c -> types.add(c.type()));
        return types;
    }

    private static List<String> idsIn(Component component) {
        var ids = new java.util.ArrayList<String>();
        walk(component, c -> ids.add(c.id()));
        return ids;
    }

    private static void walk(Component component, java.util.function.Consumer<Component> visitor) {
        visitor.accept(component);
        switch (component) {
            case Column c -> c.children().forEach(child -> walk(child, visitor));
            case Row r -> r.children().forEach(child -> walk(child, visitor));
            case Grid g -> walk(g.template(), visitor);
            case ListView l -> walk(l.template(), visitor);
            default -> {
            }
        }
    }
}
