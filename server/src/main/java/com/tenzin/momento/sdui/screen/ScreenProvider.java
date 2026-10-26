package com.tenzin.momento.sdui.screen;

import com.tenzin.momento.sdui.schema.Screen;

/**
 * Builds one screen. Implementations are Spring beans and are picked up by
 * {@link ScreenRegistry} automatically, so adding a screen means adding a class.
 */
public interface ScreenProvider {

    String screenId();

    Screen build(ScreenRequest request);
}
