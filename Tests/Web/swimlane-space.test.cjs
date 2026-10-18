const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('third-party/patches/swimlane-space.js', 'utf8');
const core = vm.runInNewContext(source + '\nmacMermaidSwimlaneCore;');

test('reserves empty and long lanes without leaking synthetic content or colliding with user IDs', () => {
  for (const direction of ['LR', 'TB']) {
    const lane = {id:'empty', isGroup:true, labelBBox:{width:400}};
    const collision = {id:'__macmermaid_lane_space_empty', width:80, height:40};
    const original = [lane, collision];
    const layout = {nodes:original, direction};
    const result = core(layout, data => {
      assert.equal(data.nodes.length, 3);
      const spacer = data.nodes[2];
      assert.equal(spacer.id, '__macmermaid_lane_space_empty_');
      assert.equal(spacer.parentId, lane.id);
      assert.equal(spacer.width, 440);
      assert.equal(spacer.height, direction==='LR' ? 440 : 40);
      lane.x = 200;
      return direction;
    });
    assert.equal(result, direction);
    assert.equal(layout.nodes, original);
    assert.equal(lane.x, 200);
  }
});

test('failed layout restores original nodes for subsequent render recovery', () => {
  const nodes = [{id:'lane', isGroup:true}];
  const layout = {nodes, direction:'LR'};
  assert.throws(() => core(layout, () => {throw new Error('failed layout');}), /failed layout/);
  assert.equal(layout.nodes, nodes);
});
