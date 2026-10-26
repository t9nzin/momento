import { resolveBindings, resolvePath, resolveString, withItem } from './bindings';

describe('resolvePath', () => {
  const scope = { user: { name: 'Tenzin', tags: ['a', 'b'] }, zero: 0 };

  it('walks nested objects', () => {
    expect(resolvePath(scope, 'user.name')).toBe('Tenzin');
  });

  it('indexes into arrays with numeric segments', () => {
    expect(resolvePath(scope, 'user.tags.1')).toBe('b');
  });

  it('returns undefined for missing paths instead of throwing', () => {
    expect(resolvePath(scope, 'user.address.city')).toBeUndefined();
    expect(resolvePath(scope, 'zero.toFixed')).toBeUndefined();
  });

  it('keeps falsy values', () => {
    expect(resolvePath(scope, 'zero')).toBe(0);
  });
});

describe('resolveString', () => {
  const scope = { title: 'Seashell', year: 2021, favorite: false, missing: null };

  it('returns the raw value when the string is a single binding', () => {
    expect(resolveString('{{favorite}}', scope)).toBe(false);
    expect(resolveString('{{ year }}', scope)).toBe(2021);
  });

  it('interpolates bindings embedded in text', () => {
    expect(resolveString('{{title}}, kept since {{year}}', scope)).toBe('Seashell, kept since 2021');
  });

  it('renders missing and null values as empty strings when interpolating', () => {
    expect(resolveString('[{{nope}}|{{missing}}]', scope)).toBe('[|]');
  });

  it('leaves strings without bindings untouched', () => {
    expect(resolveString('plain {text}', scope)).toBe('plain {text}');
  });
});

describe('resolveBindings', () => {
  it('resolves every string in a nested structure without mutating it', () => {
    const props = { title: '{{item.title}}', params: { id: '{{item.id}}' }, list: ['{{item.id}}'], size: 4 };
    const scope = withItem({}, { id: '7', title: 'Wristband' });

    const resolved = resolveBindings(props, scope);

    expect(resolved).toEqual({ title: 'Wristband', params: { id: '7' }, list: ['7'], size: 4 });
    expect(props.title).toBe('{{item.title}}');
  });

  it('lets item shadow a data key of the same name', () => {
    const scope = withItem({ item: 'outer', count: 3 }, { name: 'inner' });
    expect(resolveBindings('{{item.name}} of {{count}}', scope)).toBe('inner of 3');
  });
});
