import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import type { Screen } from '../schema/types';

/** Loads a shared fixture from /schema/fixtures, the same files the server tests check. */
export function loadFixture(name: string): Screen {
  const path = join(__dirname, '..', '..', '..', 'schema', 'fixtures', name);
  return JSON.parse(readFileSync(path, 'utf8')) as Screen;
}
