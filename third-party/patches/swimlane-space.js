/* MacMermaid adjustment for Mermaid 12.2.0, MIT licensed.
 * Reserve real layout space for lane headings and for lanes without steps.
 * These geometry-only nodes never enter the parser, DOM, or exported SVG.
 */
function macMermaidSwimlaneCore(layout, core) {
  const originalNodes = layout.nodes;
  const ids = new Set(originalNodes.map(node => node.id));
  const horizontal = layout.direction === 'LR' || layout.direction === 'RL';
  const spacers = originalNodes.filter(node => node.isGroup && !node.parentId).map(lane => {
    let id = '__macmermaid_lane_space_' + lane.id;
    while (ids.has(id)) id += '_';
    ids.add(id);
    // Match the natural-width heading measurement used by the lane painter.
    // Both axes matter in LR: the core first lays out TB, then rotates positions
    // and recomputes lane bounds from child heights without rotating the shapes.
    const span = Math.max(80, (lane.labelBBox?.width || 0) + 40);
    return {id, parentId: lane.id, isGroup: false, width: span,
      height: horizontal ? span : 40, shape: 'rect', padding: 0};
  });
  layout.nodes = [...originalNodes, ...spacers];
  try {
    return core(layout);
  } finally {
    // Keep the computed geometry on the original objects, but remove temporary
    // bounds before painting, including when a layout error needs recovery.
    layout.nodes = originalNodes;
  }
}
