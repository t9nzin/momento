package com.tenzin.momento.sdui.item;

import org.springframework.stereotype.Repository;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/** In-memory keepsake store, seeded on startup. Not persisted. */
@Repository
public class ItemRepository {

    private final Map<String, Item> items = new LinkedHashMap<>();

    public ItemRepository() {
        seed().forEach(item -> items.put(item.id(), item));
    }

    public synchronized List<Item> findAll() {
        return List.copyOf(items.values());
    }

    public synchronized Optional<Item> findById(String id) {
        return Optional.ofNullable(items.get(id));
    }

    public synchronized Optional<Item> toggleFavorite(String id) {
        return Optional.ofNullable(items.computeIfPresent(id, (key, item) -> item.withFavorite(!item.favorite())));
    }

    private static List<Item> seed() {
        return List.of(
                item("1", "Ticket stub", "Front row at the first concert I ever went to.", "ticket-stub", 2016, true),
                item("2", "Pressed flower", "A daisy from the field behind my grandparents' house.", "pressed-flower", 2009, false),
                item("3", "Seashell", "Found on a beach walk in Tofino at low tide.", "seashell", 2021, false),
                item("4", "Polaroid", "Six friends squeezed into one photo booth frame.", "polaroid", 2018, true),
                item("5", "Postcard from Kyoto", "Sent to myself so it would arrive after I got home.", "kyoto-postcard", 2023, false),
                item("6", "Grandma's ring", "Too small for any finger, so it lives on a chain.", "grandmas-ring", 1974, false),
                item("7", "Festival wristband", "Never cut it off until it fell off on its own.", "wristband", 2019, false),
                item("8", "Train ticket", "Overnight sleeper from Vienna to Venice.", "train-ticket", 2022, false));
    }

    private static Item item(String id, String title, String description, String imageSeed, int year, boolean favorite) {
        var imageUrl = "https://picsum.photos/seed/" + imageSeed + "/600/600";
        return new Item(id, title, description, imageUrl, year, favorite);
    }
}
