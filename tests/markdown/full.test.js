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
  ['# H1', '<h1>H1</h1>\n'],
  ['## H2', '<h2>H2</h2>\n'],
  ['### H3', '<h3>H3</h3>\n'],
  ['# H1 `x` and *y*', '<h1>H1 <code>x</code> and <em>y</em></h1>\n'],
  ['> a\n> b', '<blockquote>\n<p>a\nb</p>\n</blockquote>\n'],
  ['> # t\n> p', '<blockquote>\n<h1>t</h1>\n<p>p</p>\n</blockquote>\n'],
  ['a\n\nb', '<p>a</p>\n<p>b</p>\n'],
  ['para\nwith\nsoft', '<p>para\nwith\nsoft</p>\n'],
  ['- a\n- b\n- c', '<ul>\n<li>a</li>\n<li>b</li>\n<li>c</li>\n</ul>\n'],
  ['1. one\n2. two', '<ol>\n<li>one</li>\n<li>two</li>\n</ol>\n'],
  ['- *a* and **b**', '<ul>\n<li><em>a</em> and <strong>b</strong></li>\n</ul>\n'],
  ['[x](url)', '<p><a href="url">x</a></p>\n'],
  ['[x](url "t")', '<p><a href="url" title="t">x</a></p>\n'],
  ['<https://ex.com>', '<p><a href="https://ex.com">https://ex.com</a></p>\n'],
  ['<foo@bar.com>', null],
  ['![alt](img.png)', '<p><img src="img.png" alt="alt"/></p>\n'],
  ['`code`', '<p><code>code</code></p>\n'],
  ['`` ` ``', '<p><code>`</code></p>\n'],
  ['*a **b** c*', '<p><em>a <strong>b</strong> c</em></p>\n'],
  ['**a *b* c**', '<p><strong>a <em>b</em> c</strong></p>\n'],
  ['___', '<hr/>\n'],
  ['***', '<hr/>\n'],
  ['a  \nb', '<p>a<br/>\nb</p>\n'],
  ['unclosed *star', '<p>unclosed *star</p>\n'],
  ['tab\there', '<p>tab\there</p>\n'],
  ['\\*not em\\*', '<p>*not em*</p>\n'],
  ['<b>raw</b>', '<p>&lt;b&gt;raw&lt;/b&gt;</p>\n'],
  ['jscl://x [bad](javascript:alert(1))', '<p>jscl://x bad</p>\n'],
  ['& < > "', '<p>&amp; &lt; &gt; &quot;</p>\n'],
];
let pass=0, fail=0;
for (const [inp, expected] of cases) {
  let out;
  try { out = toStr(render(clstr(inp))); } catch(e){ out='EXC:'+(e.message||e); }
  if (expected===null) {
    console.log('INFO: '+JSON.stringify(inp)+' -> '+JSON.stringify(out));
    continue;
  }
  if (out===expected) { pass++; }
  else { fail++; console.log('FAIL: '+JSON.stringify(inp)+'\n  exp '+JSON.stringify(expected)+'\n  got '+JSON.stringify(out)); }
}
console.log('PASS='+pass+' FAIL='+fail);
