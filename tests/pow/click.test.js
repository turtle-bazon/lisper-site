// Полная симуляция клика по кнопке регистрации:
// загрузка бандла -> ожидание solver'а -> submit event -> что происходит?
const fs = require('fs');
const path = require('path');
const BUNDLE = path.join(__dirname,'..','..','build','jscl-bundles','site.js');

global.self = global; global.window = global;
const jscl = require('/home/turtle/lisper-site/jscl/jscl.js');
global.jscl = jscl;

function makeEl(name) {
  return {
    _name: name, value: '', textContent: '', innerHTML: '', style: {},
    _listeners: {}, submitted: 0,
    classList: { add(){}, remove(){}, contains(){ return false; } },
    addEventListener(t, fn) { (this._listeners[t] = this._listeners[t] || []).push(fn); },
    appendChild(){},
    submit() { this.submitted++; console.error('[form] submit() CALLED'); },
    querySelector(){ return null; },
    querySelectorAll(){ const l=[]; l.forEach=Array.prototype.forEach.bind(l); return l; },
    setAttribute(){}
  };
}
const els = {};
els['pow-challenge'] = makeEl('pow-challenge');
els['pow-challenge'].value = '1700000000:18:cafebabe0123456789abcdefdeadbeef:aabb';
els['pow-nonce'] = makeEl('pow-nonce');
els['register-form'] = makeEl('register-form');

global.document = {
  readyState: 'complete', activeElement: null,
  getElementById(id){ return els[id] || null; },
  createElement(){ return makeEl('created'); },
  head: makeEl('head'), body: makeEl('body'),
  querySelector(){ return null; },
  querySelectorAll(){ const l=[]; l.forEach=Array.prototype.forEach.bind(l); return l; },
  addEventListener(){}
};
global.requestAnimationFrame = () => {};
global.cancelAnimationFrame = () => {};
global.navigator = { language:'en', userAgent:'node-test' };
global.LISPER_DICT = {};

new Function('module','exports','require',
  fs.readFileSync(BUNDLE,'utf8'))({exports:{}},{},
  (m)=>m==='jscl'?jscl:require(m));

let pass=0, fail=0;
function check(name, ok){ if(ok){pass++;console.log('PASS: '+name);} else {fail++;console.log('FAIL: '+name);} }
console.error('[harness] after load: LISPER_POW_SOLVE =', typeof global.LISPER_POW_SOLVE);

// ждём решения solver'а (как реальный пользователь: клик через пару секунд)
setTimeout(() => {
  console.error('[harness] __powReady before click:', String(global.__powReady));
  console.error('[harness] pow-nonce value:', JSON.stringify(els['pow-nonce'].value));

  // эмулируем событие submit
  const ev = { preventDefault(){ console.error('[event] preventDefault CALLED'); this.prevented = true; } };
  const ls = els['register-form']._listeners['submit'] || [];
  console.error('[harness] submit listeners:', ls.length);
  for (const fn of ls) fn(ev);

  setTimeout(() => {
    console.error('[harness] RESULT: form.submitted =', els['register-form'].submitted,
                  '| event prevented =', !!ev.prevented);
    // клик работает если: нативный submit не заблокирован (prevented=false)
    // ИЛИ наша очередь вызвала form.submit() (gated-путь)
    const ok = (!ev.prevented) || els['register-form'].submitted > 0;
    check(ok ? 'кнопка отправляет форму' : 'кнопка мертва', ok);
    check('pow-nonce заполнен цифрами', /^\d+$/.test(els['pow-nonce'].value));
    console.log(`PASS=${pass} FAIL=${fail}`);
    process.exit(fail ? 1 : 0);
  }, 1000);
}, 3000);
