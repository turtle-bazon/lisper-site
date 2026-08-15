global.self = global; global.window = global;
const jscl = require('/home/turtle/lisper-site/jscl/jscl.js');
global.jscl = jscl;
const fs = require('fs');
new Function(fs.readFileSync(process.env.BUNDLE || '/tmp/md_iter6.js','utf8'))();
const md = jscl.packages['MARKDOWN'].symbols;
const clstr = s => jscl.internals.make_lisp_string(s);
const render = md['RENDER-TO-HTML'].fvalue;
function toStr(x) {
  if (x === null || x === undefined) return '';
  if (typeof x === 'string') return x;
  if (Array.isArray(x)) return x.map(toStr).join('');
  if (x.string !== undefined) return x.string;
  if (x.$$jscl_car !== undefined) return toStr(x.$$jscl_car)+toStr(x.$$jscl_cdr);
  return String(x);
}
const cases = [
  ['_a_b_c', '<p>_a_b_c</p>\n'],
  ['*foo**bar*', '<p><em>foo**bar</em></p>\n'],
  ['a*b*c', '<p>a<em>b</em>c</p>\n'],
  ['**foo*', '<p>*<em>foo</em></p>\n'],
  ['foo_bar_baz', '<p>foo_bar_baz</p>\n'],
];
let pass=0, fail=0;
for (const [inp, expected] of cases) {
  const out = toStr(render(clstr(inp)));
  if (out===expected) pass++; else { fail++; console.log('FAIL: '+JSON.stringify(inp)+' -> '+JSON.stringify(out)); }
}
console.log('PASS='+pass+' FAIL='+fail);
