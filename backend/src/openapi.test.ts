import { readFileSync } from 'fs';
import { resolve } from 'path';

/**
 * `openapi.yaml` is hand-edited on most backend PRs, and git will happily merge
 * two branches that each add a `components.schemas` block. That produced a
 * document declaring the key twice (#289 + #290): strict YAML parsers reject it,
 * lenient ones keep the last block and silently drop the users, dispatch and
 * leaderboard schemas. Nothing read the file in CI, so it reached main.
 *
 * A YAML mapping may not repeat a key. These checks cover the levels where merges
 * collide — the top-level keys, the sections under `components:`, and the schema
 * names under `components.schemas:` — without taking a YAML parser dependency for
 * a single test.
 */

const KEY = /^( *)([A-Za-z0-9_.$-]+):(?:\s|$)/;

interface KeyLine {
  indent: number;
  key: string;
  line: number;
}

function keyLines(text: string): KeyLine[] {
  const out: KeyLine[] = [];
  text.split('\n').forEach((raw, i) => {
    if (raw.trimStart().startsWith('#')) return;
    const match = KEY.exec(raw);
    if (match) out.push({ indent: match[1].length, key: match[2], line: i + 1 });
  });
  return out;
}

/** Keys at `indent` inside every block opened by `parent` (or the whole file). */
function childKeys(lines: KeyLine[], parentIndent: number, parentKey: string | null): KeyLine[] {
  const childIndent = parentKey === null ? 0 : parentIndent + 2;
  const children: KeyLine[] = [];
  let inside = parentKey === null;
  for (const entry of lines) {
    if (parentKey !== null) {
      if (entry.indent === parentIndent && entry.key === parentKey) {
        inside = true;
        continue;
      }
      if (entry.indent <= parentIndent) inside = false;
    }
    if (inside && entry.indent === childIndent) children.push(entry);
  }
  return children;
}

function repeatedKeys(entries: KeyLine[]): string[] {
  const seen = new Map<string, number[]>();
  for (const { key, line } of entries) seen.set(key, [...(seen.get(key) ?? []), line]);
  return [...seen.entries()]
    .filter(([, at]) => at.length > 1)
    .map(([key, at]) => `${key} (lines ${at.join(', ')})`);
}

describe('openapi.yaml', () => {
  const lines = keyLines(readFileSync(resolve(__dirname, '../openapi.yaml'), 'utf8'));

  it('declares each top-level key once', () => {
    expect(repeatedKeys(childKeys(lines, 0, null))).toEqual([]);
  });

  it('declares each components section once', () => {
    expect(repeatedKeys(childKeys(lines, 0, 'components'))).toEqual([]);
  });

  it('names each schema once', () => {
    // Every `schemas:` block under components counts, so a second block cannot
    // hide a name the first one already declares.
    const schemas = childKeys(lines, 2, 'schemas').filter((entry) => entry.indent === 4);
    expect(repeatedKeys(schemas)).toEqual([]);
  });

  it('the check itself catches a repeated key', () => {
    const doc = [
      'components:',
      '  schemas:',
      '    User:',
      '      type: object',
      '  securitySchemes:',
      '    bearerAuth: {}',
      '  schemas:',
      '    Webhook:',
      '      type: object',
      '    User:',
      '      type: object',
    ].join('\n');
    const parsed = keyLines(doc);
    expect(repeatedKeys(childKeys(parsed, 0, 'components'))).toEqual(['schemas (lines 2, 7)']);
    expect(
      repeatedKeys(childKeys(parsed, 2, 'schemas').filter((entry) => entry.indent === 4)),
    ).toEqual(['User (lines 3, 10)']);
  });
});
