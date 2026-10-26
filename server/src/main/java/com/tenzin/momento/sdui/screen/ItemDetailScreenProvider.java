package com.tenzin.momento.sdui.screen;

import com.tenzin.momento.sdui.item.Item;
import com.tenzin.momento.sdui.item.ItemNotFoundException;
import com.tenzin.momento.sdui.item.ItemRepository;
import com.tenzin.momento.sdui.schema.Action;
import com.tenzin.momento.sdui.schema.Button;
import com.tenzin.momento.sdui.schema.Column;
import com.tenzin.momento.sdui.schema.Image;
import com.tenzin.momento.sdui.schema.Row;
import com.tenzin.momento.sdui.schema.Screen;
import com.tenzin.momento.sdui.schema.Spacer;
import com.tenzin.momento.sdui.schema.Text;

import java.util.List;
import java.util.Map;

@org.springframework.stereotype.Component
public class ItemDetailScreenProvider implements ScreenProvider {

    public static final String SCREEN_ID = "item-detail";

    private final ItemRepository items;

    public ItemDetailScreenProvider(ItemRepository items) {
        this.items = items;
    }

    @Override
    public String screenId() {
        return SCREEN_ID;
    }

    @Override
    public Screen build(ScreenRequest request) {
        var itemId = request.param("itemId")
                .orElseThrow(() -> new IllegalArgumentException("item-detail requires an itemId param"));
        var item = items.findById(itemId).orElseThrow(() -> new ItemNotFoundException(itemId));

        var root = new Column("root", new Column.Props(12), List.of(
                new Image("photo", new Image.Props("{{keepsake.imageUrl}}", "{{keepsake.title}}", 1.0)),
                new Spacer("photo-gap", new Spacer.Props(4)),
                new Text("title", "{{keepsake.title}}", "title"),
                new Text("year", "Kept since {{keepsake.year}}", "caption"),
                new Text("description", "{{keepsake.description}}", "body"),
                new Row("actions", new Row.Props(8), List.of(favoriteButton(item), backButton()), null)),
                null);
        return new Screen(Screen.CURRENT_SCHEMA_VERSION, SCREEN_ID, item.title(), Map.of("keepsake", item), root);
    }

    private static Button favoriteButton(Item item) {
        var label = item.favorite() ? "♥ Favourite" : "♡ Add to favourites";
        var toggle = new Action.Request("POST", "/api/items/" + item.id() + "/favorite", true);
        return new Button("favorite", new Button.Props(label, "primary"), toggle);
    }

    private static Button backButton() {
        var toGallery = new Action.Navigate(GalleryScreenProvider.SCREEN_ID, Map.of());
        return new Button("back", new Button.Props("Back to gallery", "secondary"), toGallery);
    }
}
