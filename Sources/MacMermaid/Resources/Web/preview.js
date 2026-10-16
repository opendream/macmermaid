/* MacMermaid's local rendering bridge. No network or remote resources. */
(() => {
  const stage = document.getElementById('stage');
  const viewport = document.getElementById('viewport');
  const scratch = document.getElementById('scratch');
  const post = value => window.webkit?.messageHandlers.preview.postMessage(value);
  let pending = null, running = false, newest = 0, serial = 0;
  let width = 0, height = 0, scale = 1, x = 0, y = 0, fitting = true, dark = false;
  let currentSVG = null;

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
  function config(options) {
    const isDark = options.dark;
    let theme = options.theme;
    let themeVariables = {fontFamily: '-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif', fontSize: '15px'};
    if (theme === 'studio' || theme === 'ocean') {
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
      theme = isDark ? 'dark' : 'default';
    }
    return {startOnLoad: false, securityLevel: 'strict', suppressErrorRendering: true,
      maxTextSize: 200000, maxEdges: 1500, theme, themeVariables,
      fontFamily: themeVariables.fontFamily, htmlLabels: false,
      flowchart: {htmlLabels: false, useMaxWidth: false, curve: options.curve, padding: 18, nodeSpacing: 38, rankSpacing: 48},
      sequence: {useMaxWidth: false}, gantt: {useMaxWidth: false},
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
        dark = options.dark;
        document.documentElement.classList.toggle('dark', dark);
        viewport.classList.toggle('grid', options.grid);
        if (!source.trim()) {
          stage.replaceChildren(); currentSVG = null; width = height = 0;
          post({type: 'empty', revision}); continue;
        }
        const start = performance.now();
        try {
          mermaid.initialize(config(options));
          const result = await mermaid.render(`diagram_${++serial}`, source, scratch);
          if (revision !== newest) continue;
          const dom = new DOMParser().parseFromString(result.svg, 'image/svg+xml');
          const svg = dom.documentElement;
          const box = (svg.getAttribute('viewBox') || '').split(/[ ,]+/).map(Number);
          width = box.length === 4 && box[2] > 0 ? box[2] : parseFloat(svg.getAttribute('width')) || 800;
          height = box.length === 4 && box[3] > 0 ? box[3] : parseFloat(svg.getAttribute('height')) || 600;
          svg.setAttribute('width', width); svg.setAttribute('height', height);
          svg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
          svg.style.maxWidth = 'none';
          currentSVG = new XMLSerializer().serializeToString(svg);
          stage.innerHTML = currentSVG;
          if (fitting || serial === 1) fit(); else transform();
          post({type: 'rendered', revision, svg: currentSVG, width, height, milliseconds: Math.round(performance.now() - start)});
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
    background.setAttribute('fill', dark ? '#172024' : '#f7f9fa');
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
