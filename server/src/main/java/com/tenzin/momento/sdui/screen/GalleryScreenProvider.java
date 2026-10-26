package com.tenzin.momento.sdui.screen;

import com.tenzin.momento.sdui.item.ItemRepository;
import com.tenzin.momento.sdui.schema.Action;
import com.tenzin.momento.sdui.schema.Card;
import com.tenzin.momento.sdui.schema.Column;
import com.tenzin.momento.sdui.schema.Component;
import com.tenzin.momento.sdui.schema.Grid;
import com.tenzin.momento.sdui.schema.Screen;
import com.tenzin.momento.sdui.schema.Text;

import java.util.List;
import java.util.Map;

@org.springframework.stereotype.Component
public class GalleryScreenProvider implements ScreenProvider {

    public static final String SCREEN_ID = "gallery";

    private final ItemRepository items;

    public GalleryScreenProvider(ItemRepository items) {
        this.items = items;
    }

    @Override
    public String screenId() {
        return SCREEN_ID;
    }

    @Override
    public Screen build(ScreenRequest request) {
        var title = "My keepsakes";
        var root = new Column("root", List.of(
                new Text("heading", title, "title"),
                new Text("subheading", "{{count}} things worth keeping", "caption"),
                itemsGrid()));
        Map<String, Object> data = Map.of(
                "count", items.findAll().size(),
                "items", items.findAll());
        return new Screen(Screen.CURRENT_SCHEMA_VERSION, SCREEN_ID, title, data, root);
    }

    private static Component itemsGrid() {
        return new Grid("items", new Grid.Props(2, "items"), itemCard());
    }

    private static Card itemCard() {
        return new Card("item-card",
                new Card.Props("{{item.imageUrl}}", "{{item.title}}", "{{item.year}}"),
                new Action.Navigate(ItemDetailScreenProvider.SCREEN_ID, Map.of("itemId", "{{item.id}}")));
    }
}
