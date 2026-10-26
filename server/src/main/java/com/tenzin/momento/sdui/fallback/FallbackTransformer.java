package com.tenzin.momento.sdui.fallback;

import com.tenzin.momento.sdui.schema.Button;
import com.tenzin.momento.sdui.schema.Card;
import com.tenzin.momento.sdui.schema.Column;
import com.tenzin.momento.sdui.schema.Component;
import com.tenzin.momento.sdui.schema.Grid;
import com.tenzin.momento.sdui.schema.Image;
import com.tenzin.momento.sdui.schema.ListView;
import com.tenzin.momento.sdui.schema.Row;
import com.tenzin.momento.sdui.schema.Screen;
import com.tenzin.momento.sdui.schema.Spacer;
import com.tenzin.momento.sdui.schema.Text;
import com.tenzin.momento.sdui.screen.ClientContext;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Rewrites components a client cannot render into equivalents it can, so an
 * older client keeps working when a screen starts using a newer component.
 *
 * <ul>
 *   <li>{@code grid} becomes a {@code list} with the same template</li>
 *   <li>{@code card} becomes a {@code column} of {@code image} and {@code text}, keeping its action</li>
 *   <li>{@code row} becomes a {@code column}</li>
 * </ul>
 *
 * Rewrites chain (a rewritten node is checked again). If no chain ends in a
 * supported type, the original node is kept so the client's unknown-type
 * fallback names what the server actually meant to show.
 */
@Service
public class FallbackTransformer {

    public Screen apply(Screen screen, ClientContext client) {
        return screen.withRoot(transform(screen.root(), client));
    }

    public Component transform(Component component, ClientContext client) {
        var withChildren = transformChildren(component, client);
        if (client.supports(withChildren.type())) {
            return withChildren;
        }
        return rewrite(withChildren)
                .map(replacement -> transform(replacement, client))
                .filter(replacement -> client.supports(replacement.type()))
                .orElse(withChildren);
    }

    private Component transformChildren(Component component, ClientContext client) {
        return switch (component) {
            case Column c -> new Column(c.id(), c.props(), transformAll(c.children(), client), c.action());
            case Row r -> new Row(r.id(), r.props(), transformAll(r.children(), client), r.action());
            case Grid g -> new Grid(g.id(), g.props(), transform(g.template(), client));
            case ListView l -> new ListView(l.id(), l.props(), transform(l.template(), client));
            case Text t -> t;
            case Image i -> i;
            case Card c -> c;
            case Button b -> b;
            case Spacer s -> s;
        };
    }

    private List<Component> transformAll(List<Component> components, ClientContext client) {
        return components.stream().map(child -> transform(child, client)).toList();
    }

    /** The single-step equivalent for a type, if there is one. */
    private static Optional<Component> rewrite(Component component) {
        return switch (component) {
            case Grid g -> Optional.of(new ListView(g.id(), new ListView.Props(g.props().itemsBinding()), g.template()));
            case Card c -> Optional.of(cardAsColumn(c));
            case Row r -> Optional.of(new Column(r.id(), r.props() == null ? null : new Column.Props(r.props().spacing()),
                    r.children(), r.action()));
            case Column c -> Optional.empty();
            case Text t -> Optional.empty();
            case Image i -> Optional.empty();
            case ListView l -> Optional.empty();
            case Button b -> Optional.empty();
            case Spacer s -> Optional.empty();
        };
    }

    private static Column cardAsColumn(Card card) {
        var props = card.props();
        var children = new ArrayList<Component>();
        if (props.imageUrl() != null) {
            children.add(new Image(card.id() + "-image", new Image.Props(props.imageUrl(), props.title(), 1.0)));
        }
        children.add(new Text(card.id() + "-title", props.title(), "headline"));
        if (props.subtitle() != null) {
            children.add(new Text(card.id() + "-subtitle", props.subtitle(), "caption"));
        }
        return new Column(card.id(), new Column.Props(4), List.copyOf(children), card.action());
    }
}
