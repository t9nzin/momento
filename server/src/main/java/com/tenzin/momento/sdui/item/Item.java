package com.tenzin.momento.sdui.item;

public record Item(String id, String title, String description, String imageUrl, int year, boolean favorite) {

    public Item withFavorite(boolean newFavorite) {
        return new Item(id, title, description, imageUrl, year, newFavorite);
    }
}
