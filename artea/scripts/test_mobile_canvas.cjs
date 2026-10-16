const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const html = fs.readFileSync(path.join(__dirname, '../web_export_shell.html'), 'utf8');
const start = html.indexOf('function keepDrawingBufferInSync()');
const end = html.indexOf('let lastPct', start);
assert(start >= 0 && end > start);
assert.match(html, /GODOT_CONFIG\.canvasResizePolicy = 0/);
assert.match(html, /viewport-fit=cover/);
for (const side of ['top', 'right', 'bottom', 'left']) {
  assert(html.includes(`env(safe-area-inset-${side}, 0px)`));
}

function run(withVisualViewport) {
  const styles = new Map();
  const events = {};
  const visualEvents = {};
  const safe = { x: 0, y: 0 };
  let writes = 0;
  let width = 0;
  let height = 0;
  const canvas = {
    get clientWidth() { return parseFloat(styles.get('--view-width')) - safe.x; },
    get clientHeight() { return parseFloat(styles.get('--view-height')) - safe.y; },
    get width() { return width; },
    set width(value) { width = value; writes++; },
    get height() { return height; },
    set height(value) { height = value; writes++; },
  };
  const visualViewport = withVisualViewport ? {
    width: 390, height: 744, offsetTop: 0, offsetLeft: 0,
    addEventListener(name, callback) { visualEvents[name] = callback; },
  } : null;
  const window = {
    innerWidth: 390, innerHeight: 744, devicePixelRatio: 3, visualViewport,
    addEventListener(name, callback) { events[name] = callback; },
  };
  let observe;
  vm.runInNewContext(html.slice(start, end), {
    window,
    document: {
      getElementById() { return canvas; },
      documentElement: { style: { setProperty(key, value) { styles.set(key, value); } } },
    },
    ResizeObserver: class { constructor(callback) { observe = callback; } observe() {} },
  });
  assert.equal(width, 1170);
  assert.equal(height, 2232);
  const initialWrites = writes;
  observe();
  assert.equal(writes, initialWrites, 'Unchanged dimensions must not clear the WebGL buffer');
  for (const [w, h, dpr, sx, sy] of [[844, 390, 3, 88, 21], [768, 1024, 2, 0, 20], [1024, 768, 2, 0, 20], [390, 420, 3, 0, 34]]) {
    window.innerWidth = w;
    window.innerHeight = h;
    window.devicePixelRatio = dpr;
    safe.x = sx;
    safe.y = sy;
    if (visualViewport) {
      Object.assign(visualViewport, { width: w, height: h, offsetTop: 12 });
      visualEvents.resize();
      visualEvents.scroll();
      assert.equal(styles.get('--view-top'), '12px');
    } else {
      events.resize();
    }
    assert.equal(width, (w - sx) * dpr);
    assert.equal(height, (h - sy) * dpr);
    events.pageshow();
  }
}
run(true);
run(false);
console.log('MOBILE_CANVAS: PASS — rotation, safe areas, keyboard resize, DPR, page restore and fallback');
