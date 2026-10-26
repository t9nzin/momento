/**
 * Resolves `{{path}}` bindings against a scope. Pure functions only, so the
 * renderer can call them on every render and tests need no DOM.
 */

export type Scope = Record<string, unknown>;

const BINDING = /\{\{\s*([\w.]+)\s*\}\}/g;
const WHOLE_BINDING = /^\{\{\s*([\w.]+)\s*\}\}$/;

/** Walks `a.b.0.c` through objects and arrays. Returns undefined if any step is missing. */
export function resolvePath(scope: unknown, path: string): unknown {
  return path.split('.').reduce<unknown>((current, segment) => {
    if (current === null || typeof current !== 'object') return undefined;
    return (current as Record<string, unknown>)[segment];
  }, scope);
}

/**
 * A string that is exactly one binding resolves to the raw value, so
 * `"{{item.favorite}}"` can produce a boolean. Anything else is interpolated,
 * with missing values rendering as an empty string.
 */
export function resolveString(template: string, scope: Scope): unknown {
  const whole = WHOLE_BINDING.exec(template);
  if (whole) return resolvePath(scope, whole[1]);
  return template.replace(BINDING, (_, path: string) => {
    const value = resolvePath(scope, path);
    return value === undefined || value === null ? '' : String(value);
  });
}

/** Deeply resolves every string in `value`. Returns new objects; never mutates. */
export function resolveBindings<T>(value: T, scope: Scope): T {
  if (typeof value === 'string') return resolveString(value, scope) as T;
  if (Array.isArray(value)) return value.map((entry) => resolveBindings(entry, scope)) as T;
  if (value !== null && typeof value === 'object') {
    const entries = Object.entries(value).map(([key, entry]) => [key, resolveBindings(entry, scope)]);
    return Object.fromEntries(entries) as T;
  }
  return value;
}

/** The scope inside a grid or list template: screen data plus the current `item`. */
export function withItem(scope: Scope, item: unknown): Scope {
  return { ...scope, item };
}
