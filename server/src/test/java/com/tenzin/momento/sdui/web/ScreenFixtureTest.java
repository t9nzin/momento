package com.tenzin.momento.sdui.web;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.tenzin.momento.sdui.Fixtures;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.skyscreamer.jsonassert.JSONAssert;
import org.skyscreamer.jsonassert.JSONCompareMode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import java.nio.charset.StandardCharsets;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Golden-file tests: each screen's output must match its fixture in
 * {@code /schema/fixtures} exactly. A deliberate layout change means
 * regenerating fixtures and reviewing the diff.
 */
@SpringBootTest
@AutoConfigureMockMvc
class ScreenFixtureTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    ObjectMapper objectMapper;

    @ParameterizedTest(name = "{0}")
    @CsvSource(delimiter = '|', textBlock = """
            gallery.json     | /api/screens/gallery
            item-detail.json | /api/screens/item-detail?itemId=1
            """)
    void screenMatchesFixture(String fixture, String url) throws Exception {
        var body = mvc.perform(get(url)
                        .header(ClientHeaders.USER_ID, "fixture-user")
                        .header(ClientHeaders.PLATFORM, "web"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);

        if (Fixtures.UPDATE) {
            var pretty = objectMapper.copy().enable(SerializationFeature.INDENT_OUTPUT);
            Fixtures.write(fixture, pretty.writeValueAsString(objectMapper.readTree(body)));
        }
        JSONAssert.assertEquals(Fixtures.read(fixture), body, JSONCompareMode.STRICT);
    }
}
