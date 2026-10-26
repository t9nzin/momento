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
            gallery-variant-a.json | /api/screens/gallery?variant=A | column,row,text,image,card,grid,list,button,spacer
            gallery-variant-b.json | /api/screens/gallery?variant=B | column,row,text,image,card,grid,list,button,spacer
            gallery-fallback.json  | /api/screens/gallery?variant=A | column,row,text,image,list,button,spacer
            item-detail.json       | /api/screens/item-detail?itemId=1 | column,row,text,image,card,grid,list,button,spacer
            """)
    void screenMatchesFixture(String fixture, String url, String supportedComponents) throws Exception {
        var body = mvc.perform(get(url)
                        .header(ClientHeaders.USER_ID, "fixture-user")
                        .header(ClientHeaders.PLATFORM, "web")
                        .header(ClientHeaders.SUPPORTED_COMPONENTS, supportedComponents))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);

        if (Fixtures.UPDATE) {
            var pretty = objectMapper.copy().enable(SerializationFeature.INDENT_OUTPUT);
            Fixtures.write(fixture, pretty.writeValueAsString(objectMapper.readTree(body)));
        }
        JSONAssert.assertEquals(Fixtures.read(fixture), body, JSONCompareMode.STRICT);
    }
}
