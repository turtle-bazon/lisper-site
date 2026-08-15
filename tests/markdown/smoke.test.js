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
  ['para with *em* and **bold** and `code`.', '<p>para with <em>em</em> and <strong>bold</strong> and <code>code</code>.</p>\n'],
  ['*em only', '<p>*em only</p>\n'],
  ['**strong**', '<p><strong>strong</strong></p>\n'],
  ['***both***', '<p><em><strong>both</strong></em></p>\n'],
  ['# Title', '<h1>Title</h1>\n'],
  ['> quote', '<blockquote>\n<p>quote</p>\n</blockquote>\n'],
  ['- a\n- b', '<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n'],
  ['```\ncode\n```', '<pre><code>code\n</code></pre>\n'],
  ['[link](https://x.com)', '<p><a href="https://x.com">link</a></p>\n'],
];
let pass=0, fail=0;
for (const [inp, expected] of cases) {
  let out;
  try { out = toStr(render(clstr(inp))); } catch(e){ out='EXC:'+e.message; }
  const ok = out===expected;
  if (ok) pass++;
  else { fail++; console.log('FAIL: '+JSON.stringify(inp)+'\n  exp '+JSON.stringify(expected)+'\n  got '+JSON.stringify(out)); }
  console.log('PASS: '+JSON.stringify(inp));
}
console.log('PASS='+pass+' FAIL='+fail);
