/* Document appearance: YAML AST edits, with no private fields written to .mmd files. */
(() => {
  function contrastLabel(hex) {
    const rgb = hex.slice(1).match(/../g).map(v => parseInt(v, 16) / 255)
      .map(v => v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
    const luminance = rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722;
    return (luminance + 0.05) / 0.05 >= 1.05 / (luminance + 0.05) ? '#000000' : '#ffffff';
  }
  function preset(options) {
    const isDark = ['mocha', 'tokyo-night', 'dark'].includes(options.theme);
    let theme = options.theme;
    let themeVariables = {};
    if (options.palette) {
      const p = options.palette;
      theme = 'base';
      themeVariables = {...themeVariables, darkMode: isDark,
        background: p.base, primaryColor: p.surface0, primaryTextColor: p.text,
        primaryBorderColor: p.mauve, lineColor: p.subtext1, textColor: p.text,
        secondaryColor: p.mantle, secondaryTextColor: p.text, secondaryBorderColor: p.blue,
        tertiaryColor: p.surface1, tertiaryTextColor: p.text, tertiaryBorderColor: p.teal,
        edgeLabelBackground: p.base, clusterBkg: p.mantle, clusterBorder: p.surface2,
        titleColor: p.text,
        actorBkg: p.surface0, actorBorder: p.mauve, actorTextColor: p.text,
        actorLineColor: p.subtext1, signalColor: p.subtext1, signalTextColor: p.text,
        labelBoxBkgColor: p.mantle, labelBoxBorderColor: p.mauve, labelTextColor: p.text,
        loopTextColor: p.text, noteBkgColor: p.surface0, noteBorderColor: p.yellow, noteTextColor: p.text,
        activationBkgColor: p.surface1, activationBorderColor: p.mauve,
        pieTitleTextColor: p.text, pieSectionTextColor: p.base, pieLegendTextColor: p.text,
        pieStrokeColor: p.base, pieOuterStrokeColor: p.surface2,
        git0: p.mauve, gitBranchLabel0: contrastLabel(p.mauve)
      };
      [p.mauve, p.blue, p.teal, p.green, p.peach, p.yellow, p.pink, p.red, p.lavender, p.rosewater, p.subtext0, p.overlay1]
        .forEach((color, index) => {
          themeVariables[`pie${index + 1}`] = color;
          // Base's derived dark scale can clamp to black. Explicit standard scale
          // variables keep mind-map and timeline branches legible outside the app too.
          themeVariables[`cScale${index}`] = color;
          themeVariables[`cScaleLabel${index}`] = contrastLabel(color);
        });
    } else if (theme === 'studio' || theme === 'ocean') {
      const ocean = theme === 'ocean';
      theme = 'base';
      themeVariables = {...themeVariables, darkMode: isDark,
        background: isDark ? '#172024' : '#f7f9fa',
        primaryColor: isDark ? (ocean ? '#253c55' : '#24473f') : (ocean ? '#e2ecfb' : '#e4f3ee'),
        primaryTextColor: isDark ? '#e8f3f1' : '#203f3a',
        primaryBorderColor: ocean ? '#6b92c3' : '#74aa9c',
        lineColor: isDark ? '#8da8af' : '#8a9e9d',
        secondaryColor: isDark ? '#35434b' : '#eef1f5',
        tertiaryColor: isDark ? '#3b3b4e' : '#f1ecfa',
        secondaryTextColor: isDark ? '#edf3f4' : '#263e42',
        tertiaryTextColor: isDark ? '#edf3f4' : '#263e42',
        edgeLabelBackground: isDark ? '#172024' : '#f7f9fa',
        clusterBkg: isDark ? '#203036' : '#edf4f3',
        clusterBorder: isDark ? '#506b71' : '#c1d6d1'
      };
    } else if (theme === 'auto') {
      theme = 'default';
    }
    return {theme, themeVariables};
  }
  const aliases = {'flowchart-v2': 'flowchart', 'flowchart-elk': 'flowchart',
    classDiagram: 'class', stateDiagram: 'state', xychart: 'xyChart',
    railroadAbnf: 'railroad', railroadEbnf: 'railroad', railroadPeg: 'railroad'};
  const configKey = type => aliases[type] || type;
  const themes = ['redux-color', 'studio', 'ocean', 'auto', 'forest', 'neutral', 'dark',
    'latte', 'mocha', 'tokyo-day', 'tokyo-night'];
  const nativeThemes = ['base', 'default', 'dark', 'forest', 'neutral', 'null',
    'redux', 'redux-color', 'redux-dark', 'redux-dark-color'];
  const layouts = ['flowchart', 'class', 'state', 'er', 'usecase'];
  const looks = [...layouts, 'mindmap', 'swimlane', 'block', 'agentflow'];
  const neoLooks = ['sequence', 'gitGraph', 'timeline', 'requirement'];
  const roughLooks = ['venn', 'ishikawa'];
  const own = (object, key) => object != null && Object.hasOwn(object, key);

  function split(source) {
    // Only the delimiters are matched here. YAML content is parsed below, never with regex.
    const opening = /^(?:[ \t]*\r?\n)*([ \t]*)---[ \t]*\r?\n/.exec(source);
    if (!opening) return {prefix: '', yaml: '', suffix: source, indent: '', newline: source.includes('\r\n') ? '\r\n' : '\n', exists: false};
    const start = opening[0].length;
    const closing = /^[ \t]*---[ \t]*(?:\r?\n|$)/m.exec(source.slice(start));
    if (!closing) throw new Error('YAML frontmatter needs a closing --- line. The source has not been changed.');
    const raw = source.slice(start, start + closing.index);
    const indent = opening[1];
    const yaml = raw.split(/\r?\n/).map(line => line.startsWith(indent) ? line.slice(indent.length) : line).join('\n');
    return {prefix: source.slice(0, start), yaml,
      suffix: source.slice(start + closing.index), indent, newline: opening[0].includes('\r\n') ? '\r\n' : '\n', exists: true};
  }
  function read(source) {
    const parts = split(source);
    const doc = YAML.parseDocument(parts.yaml, {keepSourceTokens: true, uniqueKeys: true, schema: 'core'});
    if (doc.errors.length) throw new Error('Invalid YAML frontmatter: ' + doc.errors[0].message);
    if (doc.warnings.length) throw new Error('Unsupported YAML frontmatter: ' + doc.warnings[0].message);
    if (doc.contents != null && !YAML.isMap(doc.contents)) throw new Error('Frontmatter must be a YAML mapping.');
    return {parts, doc};
  }
  function presetFor(theme, palettes) { return preset({theme, palette: palettes[theme]}); }
  function paletteKeys(palettes) {
    return new Set(themes.flatMap(theme => Object.keys(presetFor(theme, palettes).themeVariables)));
  }
  function explicit(config, type, key) {
    const section = config?.[configKey(type)];
    return own(section, key) ? section[key] : config?.[key];
  }
  function usable(key, value) {
    return typeof value === 'string' && (key === 'theme' ? nativeThemes.includes(value) : key === 'look' ? ['neo', 'classic', 'handDrawn'].includes(value) : true);
  }
  function effective(config, type, key, defaults) {
    // Same layer order and aliases as pinned Mermaid config.ts. No global layout/look override.
    for (const layer of [config, key === 'theme' ? {theme: 'redux-color'} : {}, defaults]) {
      for (const value of [layer?.[configKey(type)]?.[key], layer?.[key]]) {
        if (usable(key, value)) return value;
      }
    }
    return '';
  }
  function editProblem(source, doc, type) {
    if (/%%\{\s*(?:init|initialize)\s*:/i.test(source)) return 'Move the init directive into YAML frontmatter before changing appearance here.';
    for (const path of [['config'], ['config', configKey(type)], ['config', 'themeVariables']]) {
      const node = doc.getIn(path, true);
      if (node != null && !YAML.isMap(node)) return path.join('.') + ' must be a YAML mapping to edit appearance.';
    }
    let problem = '';
    YAML.visit(doc.get('config', true), (_, node) => {
      if (YAML.isAlias(node) || node?.anchor || node?.key?.value === '<<') problem = 'Expand aliases, anchors, and merge keys in config before changing appearance here.';
    });
    return problem;
  }
  function inspect(source, type, config, defaults, palettes) {
    const {doc} = read(source);
    const key = configKey(type);
    const effectiveTheme = effective(config, type, 'theme', defaults);
    const effectiveLook = effective(config, type, 'look', defaults);
    let effectiveLayout = effective(config, type, 'layout', defaults);
    // Mermaid pins these algorithms in their renderer; they are not general graph layouts.
    if (key === 'swimlane') effectiveLayout = 'swimlane';
    if (key === 'mindmap' && config.layout === undefined) effectiveLayout = 'cose-bilkent';
    const registered = ['elk', 'dagre', 'swimlane', 'cose-bilkent', 'elk.stress', 'elk.force',
      'elk.mrtree', 'elk.sporeOverlap', 'elk.box', 'elk.rectpacking'];
    if ((layouts.includes(key) || key === 'mindmap') && !registered.includes(effectiveLayout)) effectiveLayout = key === 'mindmap' ? 'cose-bilkent' : 'dagre';
    const sourceConfig = /%%\{\s*(?:init|initialize)\s*:/i.test(source) ? config : (doc.toJS()?.config || {});
    const vars = sourceConfig.themeVariables || {};
    let selectedTheme = 'custom';
    if (explicit(sourceConfig, type, 'theme') == null && Object.keys(vars).length === 0) selectedTheme = 'default';
    else if (usable('theme', explicit(sourceConfig, type, 'theme'))) {
      for (const theme of themes) {
        const p = presetFor(theme, palettes);
        if (p.theme === effectiveTheme && JSON.stringify(Object.entries(p.themeVariables).sort()) === JSON.stringify(Object.entries(vars).sort())) selectedTheme = theme;
      }
    }
    const selection = (setting, allowed) => {
      const value = explicit(sourceConfig, type, setting);
      return value == null ? 'default' : allowed.includes(value) ? value : 'custom';
    };
    const curve = sourceConfig.flowchart?.curve;
    return {diagramType: type, theme: selectedTheme,
      layout: selection('layout', ['elk', 'dagre']), look: selection('look', ['neo', 'classic', 'handDrawn']),
      curve: curve == null ? 'default' : ['basis', 'linear', 'stepAfter'].includes(curve) ? curve : 'custom',
      effectiveTheme, effectiveLook, effectiveLayout,
      supportsLayout: layouts.includes(key),
      supportedLooks: looks.includes(key) ? ['neo', 'classic', 'handDrawn'] : neoLooks.includes(key) ? ['neo', 'classic'] : roughLooks.includes(key) ? ['classic', 'handDrawn'] : [],
      supportsCurve: key === 'flowchart' && effectiveLayout === 'dagre',
      editError: editProblem(source, doc, type)};
  }
  function update(source, type, setting, value, palettes) {
    if (!['theme', 'layout', 'look', 'curve'].includes(setting)) throw new Error('Unknown appearance setting.');
    const {doc, parts} = read(source);
    const problem = editProblem(source, doc, type);
    if (problem) throw new Error(problem);
    const key = configKey(type);
    // Keep comments on removed nodes instead of silently deleting the user's notes.
    function remove(path) {
      const parent = doc.getIn(path.slice(0, -1), true);
      if (!YAML.isMap(parent)) return;
      const pair = parent.items.find(p => p.key?.value === path.at(-1));
      if (!pair) return;
      const comments = [pair.key?.commentBefore, pair.key?.comment, pair.value?.commentBefore, pair.value?.comment].filter(Boolean);
      if (comments.length) parent.comment = [parent.comment, ...comments].filter(Boolean).join('\n');
      parent.delete(path.at(-1));
    }
    function put(path, value) {
      const old = doc.getIn(path, true);
      if (YAML.isScalar(old)) { old.value = value; return; }
      doc.setIn(path, value);
    }
    if (setting === 'curve') {
      if (value === 'default') remove(['config', 'flowchart', 'curve']);
      else if (['basis', 'linear', 'stepAfter'].includes(value)) put(['config', 'flowchart', 'curve'], value);
      else throw new Error('Unknown connection style.');
    } else {
      const scoped = ['config', key, setting];
      const root = ['config', setting];
      const path = doc.hasIn(scoped) ? scoped : root;
      if (value === 'default') { remove(scoped); remove(root); }
      else if (setting === 'theme') {
        if (!themes.includes(value)) throw new Error('Unknown theme.');
        put(path, presetFor(value, palettes).theme);
      } else {
        const allowed = setting === 'layout' ? ['elk', 'dagre'] : ['neo', 'classic', 'handDrawn'];
        if (!allowed.includes(value)) throw new Error('Unknown ' + setting + '.');
        put(path, value);
      }
      if (setting === 'theme') {
        for (const name of paletteKeys(palettes)) remove(['config', 'themeVariables', name]);
        if (value !== 'default') {
          for (const [name, v] of Object.entries(presetFor(value, palettes).themeVariables)) put(['config', 'themeVariables', name], v);
        }
      }
    }
    // Prune only empty containers that have no comments or anchors of their own.
    for (const path of [['config', 'themeVariables'], ['config', key], ['config']]) {
      const node = doc.getIn(path, true);
      if (YAML.isMap(node) && node.items.length === 0 && !node.comment && !node.commentBefore && !node.anchor) remove(path);
    }
    if (!parts.exists && (!doc.contents || doc.contents.items.length === 0)) return source;
    const yaml = doc.toString({lineWidth: 0}).split('\n').map((line, i, lines) => i === lines.length - 1 ? line : parts.indent + line).join(parts.newline);
    if (parts.exists) return parts.prefix + yaml + parts.suffix;
    return '---' + parts.newline + yaml + '---' + parts.newline + source;
  }
  globalThis.MacMermaidAppearance = {read, inspect, update, preset: presetFor, configKey, effective};
})();
