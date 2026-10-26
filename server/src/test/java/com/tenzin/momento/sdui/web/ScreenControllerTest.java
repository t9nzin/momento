package com.tenzin.momento.sdui.web;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class ScreenControllerTest {

    @Autowired
    MockMvc mvc;

    @Test
    void unknownScreenIs404() throws Exception {
        mvc.perform(get("/api/screens/nope"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.detail").value("No screen with id 'nope'"));
    }

    @Test
    void itemDetailWithoutItemIdIs400() throws Exception {
        mvc.perform(get("/api/screens/item-detail")).andExpect(status().isBadRequest());
    }

    @Test
    void itemDetailForUnknownItemIs404() throws Exception {
        mvc.perform(get("/api/screens/item-detail").param("itemId", "999")).andExpect(status().isNotFound());
    }

    @Test
    void malformedSchemaVersionIs400() throws Exception {
        mvc.perform(get("/api/screens/gallery").header(ClientHeaders.SCHEMA_VERSION, "one"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void healthReportsOk() throws Exception {
        mvc.perform(get("/api/health")).andExpect(jsonPath("$.status").value("ok"));
    }

    @Test
    void allowsCorsPreflightFromViteDevServer() throws Exception {
        mvc.perform(options("/api/screens/gallery")
                        .header("Origin", "http://localhost:5173")
                        .header("Access-Control-Request-Method", "GET")
                        .header("Access-Control-Request-Headers", ClientHeaders.SUPPORTED_COMPONENTS))
                .andExpect(status().isOk())
                .andExpect(header().string("Access-Control-Allow-Origin", "http://localhost:5173"));
    }
}
