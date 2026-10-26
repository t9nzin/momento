package com.tenzin.momento.sdui.item;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/items")
public class ItemController {

    private final ItemRepository repository;

    public ItemController(ItemRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<Item> list() {
        return repository.findAll();
    }

    /** Toggles the favourite flag and returns the updated item. */
    @PostMapping("/{id}/favorite")
    public Item toggleFavorite(@PathVariable String id) {
        return repository.toggleFavorite(id).orElseThrow(() -> new ItemNotFoundException(id));
    }
}
