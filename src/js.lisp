(in-package :lisper)

(defun generate-js ()
  "(function() {
  var JSCL_CDN = 'https://jscl-project.github.io/';
  var loaded = false;
  var loading = false;

  function loadScript(src, cb) {
    var s = document.createElement('script');
    s.src = src;
    s.onload = cb;
    s.onerror = function() {
      appendLine('Failed to load: ' + src, 'error');
    };
    document.head.appendChild(s);
  }

  function getConsole() {
    return document.getElementById('repl-console');
  }

  function appendLine(text, cls) {
    var c = getConsole();
    if (!c) return;
    var div = document.createElement('div');
    div.className = 'repl-line' + (cls ? ' ' + cls : '');
    div.textContent = text;
    c.appendChild(div);
    c.scrollTop = c.scrollHeight;
  }

  function appendHTML(html, cls) {
    var c = getConsole();
    if (!c) return;
    var div = document.createElement('div');
    div.className = 'repl-line' + (cls ? ' ' + cls : '');
    div.innerHTML = html;
    c.appendChild(div);
    c.scrollTop = c.scrollHeight;
  }

  function setInputEnabled(enabled) {
    var inp = document.getElementById('repl-input');
    if (inp) {
      inp.disabled = !enabled;
      if (enabled) inp.focus();
    }
  }

  function getPromptText() {
    try {
      var pkg = jscl.CL['*PACKAGE*'];
      if (pkg && pkg.value) {
        var nameFn = jscl.CL['PACKAGE-NAME'];
        if (nameFn) return jscl.internals.xstring(nameFn.fvalue(pkg.value)) + '> ';
      }
    } catch(e) {}
    return 'CL-USER> ';
  }

  function createInputLine() {
    var c = getConsole();
    if (!c) return;
    var line = document.createElement('div');
    line.className = 'repl-line repl-input-line';
    line.id = 'repl-input-line';

    var prompt = document.createElement('span');
    prompt.className = 'repl-prompt-label';
    prompt.id = 'repl-prompt-label';
    prompt.textContent = 'CL-USER> ';

    var inp = document.createElement('input');
    inp.type = 'text';
    inp.id = 'repl-input';
    inp.className = 'repl-input';
    inp.autocomplete = 'off';
    inp.spellcheck = false;

    line.appendChild(prompt);
    line.appendChild(inp);
    c.appendChild(line);
    c.scrollTop = c.scrollHeight;
    inp.focus();
  }

  function removeInputLine() {
    var line = document.getElementById('repl-input-line');
    if (line) line.remove();
  }

  function isBalanced(input) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    var inLineComment = false;
    for (var i = 0; i < input.length; i++) {
      var ch = input[i];
      if (inLineComment) { if (ch === '\\n' || ch === '\\r') inLineComment = false; continue; }
      if (escaped) { escaped = false; continue; }
      if (ch === '\\\\') { escaped = true; continue; }
      if (ch === ';') { inLineComment = true; continue; }
      if (ch === '\\\"') { inString = !inString; continue; }
      if (inString) continue;
      if (ch === '(' || ch === '[' || ch === '{') depth++;
      if (ch === ')' || ch === ']' || ch === '}') depth--;
      if (depth < 0) return false;
    }
    return depth === 0;
  }

  function clEval(input) {
    if (!isBalanced(input)) {
      throw new Error('incomplete input');
    }
    var clInput = jscl.internals.make_lisp_string(input);
    var form = jscl.packages['COMMON-LISP'].symbols['READ-FROM-STRING'].fvalue(clInput);
    return jscl.packages['COMMON-LISP'].symbols['EVAL'].fvalue(form);
  }

  function setupErrorHandler() {
    try {
      var origError = jscl.internals.error;
      jscl.internals.error = function() {
        var parts = [];
        for (var i = 0; i < arguments.length; i++) {
          try {
            parts.push(jscl.internals.xstring(
              jscl.packages['COMMON-LISP'].symbols['PRINC-TO-STRING'].fvalue(arguments[i])
            ));
          } catch(e) { parts.push(String(arguments[i])); }
        }
        throw new Error(parts.join(' '));
      };
    } catch(e) {}
  }

  function clPrint(val) {
    if (val === undefined || val === null) return '';
    try {
      var out = jscl.packages['COMMON-LISP'].symbols['PRINC-TO-STRING'].fvalue(val);
      return jscl.internals.xstring(out);
    } catch(e) { return String(val); }
  }

  function submitInput(input) {
    var promptLabel = document.getElementById('repl-prompt-label');
    var promptText = promptLabel ? promptLabel.textContent : 'CL-USER> ';
    removeInputLine();
    appendLine(promptText + input, 'repl-history');
    var trimmed = input.trim();
    if (trimmed === '(exit)' || trimmed === '(quit)' || trimmed === '(si:quit)') {
      closeRepl();
      return;
    }
    if (!trimmed) {
      createInputLine();
      return;
    }
    try {
      var result = clEval(trimmed);
      var s = clPrint(result);
      if (s && s.length > 0) {
        appendLine('=> ' + s, 'repl-result');
      }
    } catch(e) {
      var msg = (e && e.message) ? e.message : String(e);
      appendLine('Error: ' + msg, 'repl-error');
    }
    createInputLine();
  }

  window.openRepl = function() {
    var overlay = document.getElementById('repl-overlay');
    overlay.classList.add('active');
    var c = getConsole();
    if (!c) return;

    if (loaded) {
      var inp = document.getElementById('repl-input');
      if (inp) inp.focus();
      return;
    }
    if (loading) return;
    loading = true;

    c.innerHTML = '';
    appendLine('Loading JSCL...', 'repl-status');
    createInputLine();
    setInputEnabled(false);

    loadScript(JSCL_CDN + 'jquery.js', function() {
      loadScript(JSCL_CDN + 'jqconsole.js', function() {
        appendLine('Loading JSCL compiler...', 'repl-status');
        loadScript(JSCL_CDN + 'jscl.js', function() {
          appendLine('Loading web runtime...', 'repl-status');
          loadScript(JSCL_CDN + 'jscl-web.js', function() {
            loaded = true;
            loading = false;
            setupErrorHandler();
            removeInputLine();
            c.innerHTML = '';
            try {
              var verSym = jscl.packages['JSCL/WEB-REPL'].symbols['WELCOME-MESSAGE-ITEMS'];
              appendHTML('<span class=\"repl-credit\">Powered by <a href=\"https://github.com/jscl-project/jscl\" target=\"_blank\">JSCL</a> v0.9.0-alpha.0</span>', 'repl-header-line');
            } catch(e) {}
            createInputLine();
            setInputEnabled(true);
          });
        });
      });
    });
  };

  window.closeRepl = function() {
    document.getElementById('repl-overlay').classList.remove('active');
  };

  document.addEventListener('click', function(e) {
    if (e.target.classList && e.target.classList.contains('repl-close')) {
      e.preventDefault();
      e.stopPropagation();
      window.closeRepl();
    }
  });

  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
      var o = document.getElementById('repl-overlay');
      if (o && o.classList.contains('active')) closeRepl();
    }
  });

  document.addEventListener('keydown', function(e) {
    if (e.key === 'Enter') {
      var inp = document.getElementById('repl-input');
      if (inp && document.activeElement === inp && !inp.disabled) {
        e.preventDefault();
        submitInput(inp.value);
        inp.value = '';
      }
    }
  });
})();")
