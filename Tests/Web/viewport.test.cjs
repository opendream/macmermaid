const {test} = require('node:test');
const assert = require('node:assert/strict');
const {fit} = require('../../Sources/MacMermaid/Resources/Web/viewport.js');

test('Fit contains very wide and tall diagrams, including below five percent', () => {
  for (const [width, height] of [[16888, 9866], [300000, 80], [80, 300000]]) {
    for (const [w, h] of [[400, 540], [600, 800], [1260, 820]]) {
      const view = fit(width, height, w, h);
      assert.ok(view.scale > 0);
      assert.ok(view.x >= 0 && view.y >= 0);
      assert.ok(view.x + width * view.scale <= w + 1e-8);
      assert.ok(view.y + height * view.scale <= h + 1e-8);
    }
  }
  assert.ok(fit(16888, 9866, 600, 800).scale < 0.05);
});

test('Fit handles resizing, tiny viewports and transient zero dimensions', () => {
  assert.ok(fit(1000, 500, 400, 540).scale < fit(1000, 500, 1260, 820).scale);
  assert.equal(fit(10, 10, 1000, 800).scale, 1.4);
  const tiny = fit(1000, 1000, 20, 20);
  assert.ok(tiny.x >= 0 && tiny.y >= 0 && tiny.y + 1000 * tiny.scale <= 20);
  for (const values of [[0, 50, 400, 540], [50, 50, 0, 540], [NaN, 5, 5, 5], [Infinity, 5, 5, 5]]) {
    assert.equal(fit(...values), null);
  }
});
