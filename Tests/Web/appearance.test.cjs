const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const web = path.resolve(__dirname, '../../Sources/MacMermaid/Resources/Web');
const context = vm.createContext({console});
for (const file of ['yaml.min.js', 'appearance.js']) vm.runInContext(fs.readFileSync(path.join(web, file), 'utf8'), context);
const A = context.MacMermaidAppearance;
const palettes = JSON.parse(fs.readFileSync(path.join(web, 'palettes.json')));
const edit = (source, setting, value, type = 'flowchart-v2') => A.update(source, type, setting, value, palettes);
const config = source => A.read(source).doc.toJS()?.config || {};
const body = source => source.slice(source.indexOf('\n---\n') + 5);

test('creates standard portable config and preserves the Unicode diagram byte for byte', () => {
  const source = '%% ความคิด 🐱\nflowchart LR\n A[สวัสดี] --> B[世界]\n';
  const updated = edit(source, 'theme', 'mocha');
  assert.equal(body(updated), source);
  assert.equal(config(updated).theme, 'base');
  assert.equal(config(updated).themeVariables.background, '#1e1e2e');
  assert.equal(config(updated).themeVariables.primaryColor, '#313244');
  assert.ok(!updated.includes('theme: mocha'));
  assert.equal(edit(updated, 'theme', 'mocha'), updated);
});

test('preserves comments, unrelated nested settings, quoted strings, title, and source', () => {
  const source = '---\n# User notes\ntitle: "Keep : this" # title note\nconfig:\n  # Layout note\n  layout: elk # chosen layout\n  flowchart:\n    padding: 37\n  custom:\n    nested: [one, two]\n---\nflowchart LR\n A --> B\n';
  const updated = edit(source, 'layout', 'dagre');
  for (const comment of ['# User notes', '# title note', '# Layout note', '# chosen layout']) assert.ok(updated.includes(comment));
  assert.equal(config(updated).layout, 'dagre');
  assert.equal(config(updated).flowchart.padding, 37);
  assert.equal(config(updated).custom.nested.join(','), 'one,two');
  assert.equal(body(updated), body(source));
});

test('changes the active scoped override; Default removes applicable overrides only', () => {
  const source = '---\nconfig:\n  layout: elk\n  class:\n    layout: elk\n  flowchart:\n    layout: dagre # preserve this comment\n    padding: 21\n---\nflowchart LR\n A --> B';
  const changed = edit(source, 'layout', 'elk');
  assert.equal(config(changed).flowchart.layout, 'elk');
  const cleared = edit(changed, 'layout', 'default');
  assert.equal(config(cleared).layout, undefined);
  assert.equal(config(cleared).flowchart.layout, undefined);
  assert.equal(config(cleared).class.layout, 'elk');
  assert.equal(config(cleared).flowchart.padding, 21);
  assert.ok(cleared.includes('preserve this comment'));
  assert.equal(edit('flowchart LR\n A --> B', 'look', 'default'), 'flowchart LR\n A --> B');
});

test('palette changes preserve unrelated theme typography and config', () => {
  const source = '---\nconfig:\n  themeVariables:\n    fontSize: 22px\n    fontFamily: Georgia\n  sequence:\n    mirrorActors: false\n---\nsequenceDiagram\n A->>B: Hi';
  const changed = edit(source, 'theme', 'latte', 'sequence');
  const cleared = edit(changed, 'theme', 'default', 'sequence');
  assert.equal(config(cleared).themeVariables.fontSize, '22px');
  assert.equal(config(cleared).themeVariables.fontFamily, 'Georgia');
  assert.equal(config(cleared).themeVariables.background, undefined);
  assert.equal(config(cleared).sequence.mirrorActors, false);
});

test('malformed and unsafe-to-edit YAML throw without returning a rewritten source', () => {
  for (const source of [
    '---\nconfig: [broken\n---\nflowchart LR\n A-->B',
    '---\nconfig: {}\nconfig: {}\n---\nflowchart LR',
    '---\nconfig: {}\nflowchart LR',
    '---\nconfig: hello\n---\nflowchart LR',
    '---\npalette: &p {theme: dark}\nconfig: *p\n---\nflowchart LR',
    '%%{init: {"theme":"dark"}}%%\nflowchart LR\n A-->B'
  ]) assert.throws(() => edit(source, 'theme', 'forest'));
});

test('CRLF body and indented frontmatter retain their original line endings', () => {
  const source = '\r\n  ---\r\n  title: Example\r\n  config: {look: classic}\r\n  ---\r\nflowchart LR\r\n A-->B\r\n';
  const changed = edit(source, 'look', 'neo');
  assert.ok(changed.endsWith('  ---\r\nflowchart LR\r\n A-->B\r\n'));
  assert.equal(config(changed).look, 'neo');
  assert.ok(!/(?<!\r)\n/.test(changed));
});

test('inspector distinguishes Default, preset and Custom; resolves diagram-scoped precedence', () => {
  const defaults = {layout: 'elk', look: 'classic', flowchart: {look: 'neo'}, theme: 'redux-color'};
  const inspect = source => A.inspect(source, 'flowchart-v2', config(source), defaults, palettes);
  const plain = 'flowchart LR\n A-->B';
  let state = inspect(plain);
  assert.equal(state.theme, 'default');
  assert.equal(state.effectiveLook, 'neo');
  assert.equal(state.effectiveLayout, 'elk');
  assert.equal(state.supportsCurve, false);
  state = inspect(edit(edit(plain, 'theme', 'tokyo-night'), 'layout', 'dagre'));
  assert.equal(state.theme, 'tokyo-night');
  assert.equal(state.supportsCurve, true);
  const custom = '---\nconfig:\n  theme: forest\n  flowchart:\n    theme: dark\n    look: classic\n  themeVariables: {fontSize: 21px}\n---\n'+plain;
  state = inspect(custom);
  assert.equal(state.theme, 'custom');
  assert.equal(state.effectiveTheme, 'dark');
  assert.equal(state.effectiveLook, 'classic');
  state = A.inspect('swimlane-beta LR', 'swimlane', {}, defaults, palettes);
  assert.equal(state.effectiveLayout, 'swimlane');
  assert.equal(state.supportsLayout, false);
  assert.equal(state.supportsCurve, false);
});

test('unknown source settings stay Custom while metadata reports renderer fallbacks', () => {
  const source = '---\nconfig:\n  theme: unknown-theme\n  layout: unknown-layout\n  themeVariables: {userToken: blue}\n---\nflowchart LR\n A-->B';
  const state = A.inspect(source, 'flowchart-v2', {}, {layout: 'elk', theme: 'redux-color'}, palettes);
  assert.equal(state.theme, 'custom');
  assert.equal(state.layout, 'custom');
  assert.equal(state.effectiveTheme, 'redux-color');
  const rawState = A.inspect(source, 'flowchart-v2', config(source), {layout: 'elk', theme: 'redux-color'}, palettes);
  assert.equal(rawState.effectiveLayout, 'dagre');
});
