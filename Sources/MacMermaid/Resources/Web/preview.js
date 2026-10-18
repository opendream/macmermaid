/* MacMermaid's local rendering bridge. No network or remote resources. */
(() => {
  const stage = document.getElementById('stage');
  const viewport = document.getElementById('viewport');
  const scratch = document.getElementById('scratch');
  const post = value => window.webkit?.messageHandlers.preview.postMessage(value);
  let pending = null, running = false, newest = 0, serial = 0;
  let width = 0, height = 0, scale = 1, x = 0, y = 0, fitting = true, dark = false;
  let currentSVG = null;
  let lastDiagnostics = null;
  let currentBackground = '#eff1f5';

  function transform() {
    stage.style.transform = `translate(${x}px, ${y}px) scale(${scale})`;
    post({type: 'zoom', scale});
  }
  function fit() {
    if (!width || !height) return;
    const w = viewport.clientWidth, h = viewport.clientHeight;
    scale = Math.max(0.05, Math.min((w - 100) / width, (h - 140) / height, 1.4));
    x = (w - width * scale) / 2;
    y = (h - height * scale) / 2 - 10;
    fitting = true;
    transform();
  }
  function zoom(factor, cx = viewport.clientWidth / 2, cy = viewport.clientHeight / 2) {
    const next = Math.max(0.05, Math.min(8, scale * factor));
    x = cx - (cx - x) * next / scale;
    y = cy - (cy - y) * next / scale;
    scale = next;
    fitting = false;
    transform();
  }
  function config() {
    return {startOnLoad: false, securityLevel: 'strict', suppressErrorRendering: true,
      maxTextSize: 200000, maxEdges: 1500, theme: 'redux-color',
      fontFamily: '-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif',
      secure: ['secure', 'securityLevel', 'startOnLoad', 'maxTextSize', 'maxEdges', 'suppressErrorRendering']};
  }
  async function drain() {
    if (running) return;
    running = true;
    try {
      while (pending) {
        const request = pending;
        pending = null;
        const {source, options, revision} = request;
        viewport.classList.toggle('grid', options.grid);
        if (!source.trim()) {
          stage.replaceChildren(); currentSVG = null; width = height = 0;
          post({type: 'empty', revision}); continue;
        }
        const start = performance.now();
        try {
          MacMermaidAppearance.read(source);
          mermaid.initialize(config());
          const parsed = await mermaid.parse(source);
          const sourceConfig = structuredClone(parsed.config);
          const result = await mermaid.render(`diagram_${++serial}`, source, scratch);
          if (revision !== newest) continue;
          const appearance = MacMermaidAppearance.inspect(source, result.diagramType, sourceConfig,
            mermaid.mermaidAPI.defaultConfig, options.palettes);
          const vars = sourceConfig.themeVariables || {};
          const selected = MacMermaidAppearance.preset(appearance.theme, options.palettes);
          const background = vars.background || selected.themeVariables.background ||
            (['dark', 'redux-dark', 'redux-dark-color'].includes(appearance.effectiveTheme) ? '#1f2020' : '#ffffff');
          dark = vars.darkMode === true || ['mocha', 'tokyo-night', 'dark'].includes(appearance.theme) ||
            ['dark', 'redux-dark', 'redux-dark-color'].includes(appearance.effectiveTheme);
          appearance.isDark = dark;
          lastDiagnostics = {appearance, config: sourceConfig};
          document.documentElement.style.setProperty('--canvas', background);
          document.documentElement.style.setProperty('--dot', dark ? '#4a4e59' : '#d7dce0');
          document.documentElement.classList.toggle('dark', dark);
          const dom = new DOMParser().parseFromString(result.svg, 'image/svg+xml');
          const svg = dom.documentElement;
          const box = (svg.getAttribute('viewBox') || '').split(/[ ,]+/).map(Number);
          width = box.length === 4 && box[2] > 0 ? box[2] : parseFloat(svg.getAttribute('width')) || 800;
          height = box.length === 4 && box[3] > 0 ? box[3] : parseFloat(svg.getAttribute('height')) || 600;
          svg.setAttribute('width', width); svg.setAttribute('height', height);
          svg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
          svg.style.maxWidth = 'none';
          currentSVG = new XMLSerializer().serializeToString(svg);
          currentBackground = background;
          stage.innerHTML = currentSVG;
          if (fitting || serial === 1) fit(); else transform();
          post({type: 'rendered', revision, appearance, svg: currentSVG, width, height, milliseconds: Math.round(performance.now() - start)});
        } catch (error) {
          if (revision !== newest) continue;
          const message = String(error?.message || error).replace(/<[^>]*>/g, '').slice(0, 2500);
          post({type: 'error', revision, message});
        } finally { scratch.replaceChildren(); }
      }
    } finally { running = false; }
  }
  function exportSVG() {
    if (!currentSVG) throw new Error('Render a diagram first.');
    // Add a real background so standalone SVGs and raster exports remain legible.
    const dom = new DOMParser().parseFromString(currentSVG, 'image/svg+xml');
    const svg = dom.documentElement;
    const box = svg.getAttribute('viewBox').split(/[ ,]+/).map(Number);
    const background = dom.createElementNS('http://www.w3.org/2000/svg', 'rect');
    background.setAttribute('x', box[0]); background.setAttribute('y', box[1]);
    background.setAttribute('width', box[2]); background.setAttribute('height', box[3]);
    background.setAttribute('fill', currentBackground);
    svg.insertBefore(background, svg.firstChild);
    return new XMLSerializer().serializeToString(svg);
  }
  async function png() {
    const svg = exportSVG();
    const factor = Math.min(2, 8192 / width, 8192 / height, Math.sqrt(24000000 / (width * height)));
    const canvas = document.createElement('canvas');
    canvas.width = Math.ceil(width * factor); canvas.height = Math.ceil(height * factor);
    const image = new Image();
    await new Promise((resolve, reject) => {
      image.onload = resolve; image.onerror = () => reject(new Error('This diagram could not be rasterized. Try SVG or PDF.'));
      image.src = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(svg)));
    });
    canvas.getContext('2d').drawImage(image, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL('image/png').split(',')[1];
  }
  window.macmermaid = {
    request(value) { newest = value.revision; pending = value; drain(); },
    fit, zoom, exportSVG, png,
    diagnostics() { return lastDiagnostics; },
    editAppearance(source, diagramType, setting, value, palettes) {
      return MacMermaidAppearance.update(source, diagramType, setting, value, palettes);
    },
    setGrid(value) { viewport.classList.toggle('grid', value); }
  };
  let drag = null;
  viewport.addEventListener('pointerdown', event => {
    if (event.button !== 0) return;
    drag = {x: event.clientX, y: event.clientY, originX: x, originY: y};
    viewport.setPointerCapture(event.pointerId); viewport.classList.add('dragging');
  });
  viewport.addEventListener('pointermove', event => {
    if (!drag) return;
    x = drag.originX + event.clientX - drag.x; y = drag.originY + event.clientY - drag.y;
    fitting = false; transform();
  });
  const endDrag = () => { drag = null; viewport.classList.remove('dragging'); };
  viewport.addEventListener('pointerup', endDrag);
  viewport.addEventListener('pointercancel', endDrag);
  viewport.addEventListener('wheel', event => {
    event.preventDefault();
    if (event.ctrlKey || event.metaKey) zoom(Math.exp(-event.deltaY * 0.01), event.clientX, event.clientY);
    else { x -= event.deltaX; y -= event.deltaY; fitting = false; transform(); }
  }, {passive: false});
  viewport.addEventListener('dblclick', fit);
  new ResizeObserver(() => { if (fitting) fit(); }).observe(viewport);
  post({type: 'ready'});
})();
