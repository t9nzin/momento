import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { loadFixture } from '../test/fixtures';
import { COMPONENT_TYPES, type Action, type ComponentNode } from '../schema/types';
import { ActionProvider } from './ActionContext';
import { ComponentRenderer } from './ComponentRenderer';

function renderNode(node: ComponentNode, data: Record<string, unknown> = {}, dispatch = jest.fn()) {
  const result = render(
    <ActionProvider value={dispatch}>
      <ComponentRenderer node={node} scope={data} />
    </ActionProvider>,
  );
  return { ...result, dispatch };
}

function renderedTypes(container: HTMLElement): Set<string> {
  const nodes = container.querySelectorAll('[data-sdui-type]');
  return new Set(Array.from(nodes, (node) => node.getAttribute('data-sdui-type')!));
}

const FIXTURES = ['gallery-variant-a.json', 'gallery-variant-b.json', 'gallery-fallback.json', 'item-detail.json'];

describe('ComponentRenderer with shared fixtures', () => {
  it('renders every component type in the schema across the fixtures, with no unknowns', () => {
    const seen = new Set<string>();
    for (const name of FIXTURES) {
      const fixture = loadFixture(name);
      const { container, unmount } = renderNode(fixture.root, fixture.data);
      renderedTypes(container).forEach((type) => seen.add(type));
      unmount();
    }

    expect([...seen].sort()).toEqual([...COMPONENT_TYPES].sort());
  });

  it('renders the gallery grid variant: one card per item with bound titles', () => {
    const gallery = loadFixture('gallery-variant-a.json');
    const { container } = renderNode(gallery.root, gallery.data);

    expect(screen.getByRole('heading', { name: 'My keepsakes' })).toBeInTheDocument();
    expect(screen.getByText('8 things worth keeping')).toBeInTheDocument();
    expect(container.querySelectorAll('[data-sdui-type="card"]')).toHaveLength(8);
    expect(screen.getByRole('button', { name: /Ticket stub\s*2016/ })).toBeInTheDocument();
    expect(renderedTypes(container)).toEqual(new Set(['column', 'text', 'grid', 'card']));
  });

  it('renders the gallery list variant as list items', () => {
    const gallery = loadFixture('gallery-variant-b.json');
    renderNode(gallery.root, gallery.data);

    expect(screen.getAllByRole('listitem')).toHaveLength(8);
  });

  it('renders the capability-fallback gallery as tappable columns of image and text', async () => {
    const gallery = loadFixture('gallery-fallback.json');
    const { container, dispatch } = renderNode(gallery.root, gallery.data);

    expect(container.querySelector('[data-sdui-type="card"], [data-sdui-type="grid"]')).toBeNull();
    await userEvent.click(screen.getByRole('button', { name: /Seashell/ }));
    expect(dispatch).toHaveBeenCalledWith({ type: 'navigate', screenId: 'item-detail', params: { itemId: '3' } });
  });

  it('renders item detail with an image, spacer, row and buttons', () => {
    const detail = loadFixture('item-detail.json');
    const { container } = renderNode(detail.root, detail.data);

    expect(screen.getByRole('img', { name: 'Ticket stub' })).toHaveAttribute(
      'src',
      'https://picsum.photos/seed/ticket-stub/600/600',
    );
    expect(screen.getByText('Kept since 2016')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Back to gallery' })).toBeInTheDocument();
    expect(renderedTypes(container)).toEqual(new Set(['column', 'image', 'spacer', 'text', 'row', 'button']));
  });
});

describe('ComponentRenderer', () => {
  it('renders a list template once per bound item', () => {
    const node: ComponentNode = {
      type: 'list',
      id: 'l',
      props: { itemsBinding: 'things' },
      template: { type: 'text', id: 't', props: { text: '{{item.name}}' } },
    };
    renderNode(node, { things: [{ id: 'a', name: 'Shell' }, { id: 'b', name: 'Stub' }] });

    const items = screen.getAllByRole('listitem');
    expect(items).toHaveLength(2);
    expect(within(items[1]).getByText('Stub')).toBeInTheDocument();
  });

  it('dispatches the action with bindings resolved against the tapped item', async () => {
    const node: ComponentNode = {
      type: 'grid',
      id: 'g',
      props: { columns: 2, itemsBinding: 'items' },
      template: {
        type: 'card',
        id: 'c',
        props: { title: '{{item.title}}' },
        action: { type: 'navigate', screenId: 'item-detail', params: { itemId: '{{item.id}}' } },
      },
    };
    const { dispatch } = renderNode(node, { items: [{ id: '1', title: 'One' }, { id: '2', title: 'Two' }] });

    await userEvent.click(screen.getByRole('button', { name: 'Two' }));

    expect(dispatch).toHaveBeenCalledWith<[Action]>({
      type: 'navigate',
      screenId: 'item-detail',
      params: { itemId: '2' },
    });
  });

  it('renders a visible fallback for unknown types, warns, and keeps rendering siblings', () => {
    const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
    const node = {
      type: 'column',
      id: 'root',
      children: [
        { type: 'carousel', id: 'c', props: {} },
        { type: 'text', id: 't', props: { text: 'Still here' } },
      ],
    } as unknown as ComponentNode;

    renderNode(node);

    expect(screen.getByRole('note')).toHaveTextContent('Unsupported component: carousel');
    expect(screen.getByText('Still here')).toBeInTheDocument();
    expect(warn).toHaveBeenCalledWith(expect.stringContaining('unknown component type "carousel"'));
    warn.mockRestore();
  });

  it('renders nothing for a template whose binding is not an array', () => {
    const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
    const node: ComponentNode = {
      type: 'list',
      id: 'l',
      props: { itemsBinding: 'missing' },
      template: { type: 'text', id: 't', props: { text: 'x' } },
    };

    renderNode(node);

    expect(screen.queryByRole('listitem')).not.toBeInTheDocument();
    expect(warn).toHaveBeenCalledWith(expect.stringContaining('is not an array'));
    warn.mockRestore();
  });

  it('does not make containers without an action tappable', () => {
    renderNode({ type: 'card', id: 'c', props: { title: 'Static' } });
    expect(screen.queryByRole('button')).not.toBeInTheDocument();
  });
});
