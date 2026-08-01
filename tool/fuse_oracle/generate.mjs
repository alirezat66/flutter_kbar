// Generates the fuse.js oracle fixture that test/match/fuse_matcher_test.dart
// validates the Dart port against.
//
// Run with:  cd tool/fuse_oracle && npm install && node generate.mjs
//
// The fixture is committed. Regenerate it only when deliberately changing which
// fuse.js version or configuration flutter_kbar targets — a diff here is a
// change in ranking behaviour and should be reviewed as such.

import { writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import Fuse from 'fuse.js';

import { actions, queries } from './corpus.mjs';

// kbar's exact configuration, from src/useMatches.tsx.
const fuseOptions = {
  keys: [
    { name: 'name', weight: 0.5 },
    {
      name: 'keywords',
      getFn: (item) => (item.keywords ?? '').split(','),
      weight: 0.5,
    },
    'subtitle',
  ],
  ignoreLocation: true,
  includeScore: true,
  includeMatches: true,
  threshold: 0.2,
  minMatchCharLength: 1,
};

const fuse = new Fuse(actions, fuseOptions);

const cases = queries.map((query) => {
  const results = fuse.search(query);
  return {
    query,
    results: results.map((r) => ({
      id: r.item.id,
      // kbar inverts fuse's score so that bigger is better.
      score: r.score,
      kbarScore: 1 / ((r.score ?? 0) + 1),
      matches: (r.matches ?? []).map((m) => ({
        key: m.key,
        value: m.value,
        // fuse emits inclusive [start, end] pairs.
        indices: m.indices.map(([s, e]) => [s, e]),
      })),
    })),
  };
});

const fixture = {
  generator: 'tool/fuse_oracle/generate.mjs',
  fuseVersion: '6.6.2',
  options: {
    keys: [
      { name: 'name', weight: 0.5 },
      { name: 'keywords', weight: 0.5, split: ',' },
      { name: 'subtitle', weight: 1 },
    ],
    ignoreLocation: true,
    threshold: 0.2,
    minMatchCharLength: 1,
  },
  actions,
  cases,
};

const out = resolve(
  dirname(fileURLToPath(import.meta.url)),
  '../../test/match/fuse_oracle_fixture.json',
);
writeFileSync(out, `${JSON.stringify(fixture, null, 2)}\n`);

const matched = cases.reduce((n, c) => n + c.results.length, 0);
console.log(
  `wrote ${out}\n` +
    `  ${actions.length} actions x ${queries.length} queries\n` +
    `  ${matched} matching pairs`,
);
