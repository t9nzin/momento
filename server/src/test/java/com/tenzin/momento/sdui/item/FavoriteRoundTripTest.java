package com.tenzin.momento.sdui.item;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The favourite button's request action, followed by the refresh a client does afterwards. */
@SpringBootTest
@AutoConfigureMockMvc
@DirtiesContext
class FavoriteRoundTripTest {

    private static final String FAVORITE_BUTTON = "$.root.children[?(@.id == 'actions')].children[?(@.id == 'favorite')]";

    @Autowired
    MockMvc mvc;

    @Test
    void togglingAFavouriteShowsUpInTheItemsApiAndTheRefreshedScreen() throws Exception {
        mvc.perform(get("/api/screens/item-detail").param("itemId", "2"))
                .andExpect(jsonPath(FAVORITE_BUTTON + ".props.label").value("♡ Add to favourites"))
                .andExpect(jsonPath(FAVORITE_BUTTON + ".action.path").value("/api/items/2/favorite"));

        mvc.perform(post("/api/items/2/favorite"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.favorite").value(true));

        mvc.perform(get("/api/items"))
                .andExpect(jsonPath("$[?(@.id == '2')].favorite").value(true));
        mvc.perform(get("/api/screens/item-detail").param("itemId", "2"))
                .andExpect(jsonPath("$.data.keepsake.favorite").value(true))
                .andExpect(jsonPath(FAVORITE_BUTTON + ".props.label").value("♥ Favourite"));

        mvc.perform(post("/api/items/2/favorite")).andExpect(jsonPath("$.favorite").value(false));
    }

    @Test
    void favouritingAnUnknownItemIs404() throws Exception {
        mvc.perform(post("/api/items/999/favorite")).andExpect(status().isNotFound());
    }
}
