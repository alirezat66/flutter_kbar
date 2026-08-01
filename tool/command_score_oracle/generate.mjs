// Generates the command-score oracle fixture.
//
// Run with:  node tool/command_score_oracle/generate.mjs
//
// No npm dependencies: reference.mjs is a verbatim copy of cmdk's algorithm.

import { writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { commandScore } from './reference.mjs';

const strings = [
  'Git status',
  'Git commit',
  'Git push',
  'Save',
  'Save as',
  'Save all',
  'Toggle theme',
  'Set theme to dark',
  'Open settings',
  'Search in files',
  'Go to definition',
  'Format document',
  'Toggle terminal',
  'New window',
  'Clear cache and reload the application window',
  'HTML',
  'haml',
  'html5',
  'user_profile.tsx',
  'src/components/Button.tsx',
  'lib/src/match/fuse/bitap.dart',
  'a-b-c',
  'foo.bar.baz',
  'AaBbCc',
  'ouch',
  'curtain',
  'bad',
  'bard',
  '',
  '   ',
];

const abbreviations = [
  'g', 'gs', 'gc', 'gp', 'git', 'gits',
  's', 'sv', 'sa', 'save', 'svae',
  'tt', 'theme', 'thm', 'tgl',
  'os', 'settings',
  'gtd', 'def',
  'fd', 'fmt',
  'nw', 'new',
  'ccarw', 'clear',
  'HM', 'hm', 'html', 'HTML',
  'up', 'ups', 'btn', 'bitap', 'dart',
  'abc', 'fbb', 'ABC', 'aabbcc',
  'uc', 'bd',
  '', 'zzz', 'qqqqqq',
];

// Aliases exercise the keywords path: cmdk appends them to the string.
const aliasSets = [[], ['vcs'], ['vcs', 'source control'], ['write', 'persist']];

const cases = [];
for (const string of strings) {
  for (const abbreviation of abbreviations) {
    for (let i = 0; i < aliasSets.length; i++) {
      const aliases = aliasSets[i];
      cases.push({
        string,
        abbreviation,
        aliases,
        score: commandScore(string, abbreviation, aliases),
      });
    }
  }
}

const fixture = {
  generator: 'tool/command_score_oracle/generate.mjs',
  source: 'cmdk command-score.ts',
  cases,
};

const out = resolve(
  dirname(fileURLToPath(import.meta.url)),
  '../../test/match/command_score_oracle_fixture.json',
);
writeFileSync(out, `${JSON.stringify(fixture, null, 1)}\n`);

const nonZero = cases.filter((c) => c.score > 0).length;
console.log(`wrote ${out}\n  ${cases.length} cases, ${nonZero} scoring above zero`);
