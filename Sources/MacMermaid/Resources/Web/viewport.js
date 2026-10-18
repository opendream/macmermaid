/* Shared viewport geometry. Fit must include the entire diagram at any size. */
((root) => {
  function fit(width, height, viewWidth, viewHeight) {
    if (![width, height, viewWidth, viewHeight].every(value => Number.isFinite(value) && value > 0)) return null;
    const paddingX = Math.min(50, viewWidth / 4);
    const paddingY = Math.min(70, viewHeight / 4);
    const scale = Math.min((viewWidth - 2 * paddingX) / width,
      (viewHeight - 2 * paddingY) / height, 1.4);
    return {scale, x: (viewWidth - width * scale) / 2,
      y: (viewHeight - height * scale) / 2 - Math.min(10, paddingY)};
  }
  const api = {fit};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  root.MacMermaidViewport = api;
})(globalThis);
