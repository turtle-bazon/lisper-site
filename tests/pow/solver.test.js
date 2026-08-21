// Тест браузерного PoW-solver'а из собранного site-бандла.
// Проверяет: solver определяется при site-init, добывает nonce с
// нужным числом нулевых бит, nonce валидируется тем же алгоритмом.
const fs = require('fs');
const path = require('path');

const BUNDLE = process.env.SITE_BUNDLE ||
  path.join(__dirname, '..', '..', 'build', 'jscl-bundles', 'site.js');
if (!fs.existsSync(BUNDLE)) {
  console.error('SKIP: site bundle not built (' + BUNDLE + ') — run make build');
  process.exit(0);
}

global.self = global; global.window = global;
const jscl = require(path.join(__dirname, '..', '..', 'jscl', 'jscl.js'));
global.jscl = jscl;

function makeEl() {
  return { value: '', textContent: '', innerHTML: '', style: {},
    classList: { add(){}, remove(){}, contains(){ return false; } },
    addEventListener(){}, appendChild(){},
    querySelector(){ return null; },
    querySelectorAll(){ const l = []; l.forEach = Array.prototype.forEach.bind(l); return l; },
    setAttribute(){} };
}
const els = {};
els['pow-challenge'] = makeEl();
els['pow-challenge'].value = '1700000000:18:deadbeefcafebabe0123456789abcdef:aabb';
els['pow-nonce'] = makeEl();
els['register-form'] = makeEl();

global.document = {
  readyState: 'complete', activeElement: null,
  getElementById(id) { return els[id] || null; },
  createElement() { return makeEl(); },
  head: makeEl(), body: makeEl(),
  querySelector() { return null; },
  querySelectorAll() { const l = []; l.forEach = Array.prototype.forEach.bind(l); return l; },
  addEventListener() {}
};
global.requestAnimationFrame = () => {};
global.cancelAnimationFrame = () => {};
global.navigator = { language: 'en', userAgent: 'node-test' };
global.LISPER_DICT = {};

let pass = 0, fail = 0;
function check(name, ok) {
  if (ok) { pass++; console.log('PASS: ' + name); }
  else { fail++; console.log('FAIL: ' + name); }
}

// load the bundle (site-boot runs site-init -> evals solver)
new Function('module', 'exports', 'require',
  fs.readFileSync(BUNDLE, 'utf8'))({ exports: {} }, {},
  (m) => m === 'jscl' ? jscl : require(m));

check('solver определён после загрузки бандла',
      typeof global.LISPER_POW_SOLVE === 'function');

if (typeof global.LISPER_POW_SOLVE !== 'function') {
  console.log(`PASS=${pass} FAIL=${fail}`);
  process.exit(1);
}

const DIFF = 18;
const SALT = 'cafebabe0123456789abcdefdeadbeef';
global.LISPER_POW_SOLVE(SALT, DIFF).then((nonceStr) => {
  check('solver вернул строку-число', /^\d+$/.test(String(nonceStr)));

  // независимая проверка нулевых бит
  const h = require('crypto').createHash('sha256').update(SALT + nonceStr).digest();
  let bits = 0;
  for (const b of h) {
    if (b === 0) bits += 8;
    else { for (let k = 7; k >= 0; k--) { if (b & (1 << k)) break; bits++; } break; }
  }
  check(`nonce имеет >= ${DIFF} ведущих нулевых бит (получено ${bits})`, bits >= DIFF);

  console.log(`PASS=${pass} FAIL=${fail}`);
  process.exit(fail ? 1 : 0);
}).catch((e) => { console.error('FAIL: solver rejected:', e); process.exit(1); });