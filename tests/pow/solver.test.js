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
check('чистый JS sha256 экспортирован (фолбэк для не-secure context)',
      typeof global.LISPER_SHA256 === 'function');

if (typeof global.LISPER_POW_SOLVE !== 'function') {
  console.log(`PASS=${pass} FAIL=${fail}`);
  process.exit(1);
}

// --- векторы чистого JS sha256 против node crypto
const sha = global.LISPER_SHA256;
const nodeSha = (s) => require('crypto').createHash('sha256').update(s).digest();
for (const v of ['', 'abc', 'lisper', 'a'.repeat(200), 'deadbeef0123456789']) {
  const got = Buffer.from(sha(new TextEncoder().encode(v))).toString('hex');
  check(`sha256(${JSON.stringify(v.length > 20 ? v.slice(0, 8) + '…' : v)}) совпадает`,
        got === nodeSha(v).toString('hex'));
}

const DIFF = 18;
const SALT = 'cafebabe0123456789abcdefdeadbeef';

function zeroBits(buf) {
  let bits = 0;
  for (const b of buf) {
    if (b === 0) bits += 8;
    else { for (let k = 7; k >= 0; k--) { if (b & (1 << k)) break; bits++; } break; }
  }
  return bits;
}

global.LISPER_POW_SOLVE(SALT, DIFF).then((nonceStr) => {
  check('solver вернул строку-число', /^\d+$/.test(String(nonceStr)));

  const h = require('crypto').createHash('sha256').update(SALT + nonceStr).digest();
  const bits = zeroBits(h);
  check(`subtle: nonce >= ${DIFF} бит (${bits})`, bits >= DIFF);

  // форсируем чистый JS путь (как в не-secure context)
  global.LISPER_FORCE_JS_SHA = true;
  return global.LISPER_POW_SOLVE(SALT, DIFF).then((n2) => {
    const b2 = zeroBits(require('crypto').createHash('sha256').update(SALT + n2).digest());
    check(`js-sha: nonce >= ${DIFF} бит (${b2})`, b2 >= DIFF);
    finish();
  });
}).catch((e) => { console.error('FAIL: solver rejected:', e); finish(1); });

function finish(code) {
  console.log(`PASS=${pass} FAIL=${fail}`);
  process.exit(code !== undefined ? code : (fail ? 1 : 0));
}