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
    if (typeof DOMPurify !== 'undefined') {
      div.innerHTML = DOMPurify.sanitize(html);
    } else {
      div.textContent = html.replace(/<[^>]+>/g, '');
    }
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
            if (typeof jscl === 'undefined') {
              appendLine('Error: JSCL failed to load', 'repl-error');
              loaded = false;
              loading = false;
              setInputEnabled(true);
              return;
            }
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
    var tryBtn = document.getElementById('try-repl-btn');
    if (tryBtn && (e.target === tryBtn || tryBtn.contains(e.target))) {
      e.preventDefault();
      window.openRepl();
    }
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

  // === Markdown Editor ===
  document.addEventListener('DOMContentLoaded', function() {
    // Initialize marked with highlight.js
    if (typeof marked !== 'undefined') {
      marked.setOptions({
        highlight: function(code, lang) {
          if (typeof hljs !== 'undefined' && lang && hljs.getLanguage(lang)) {
            try { return hljs.highlight(code, {language: lang}).value; } catch(e) {}
          }
          if (typeof hljs !== 'undefined') {
            try { return hljs.highlightAuto(code).value; } catch(e) {}
          }
          return code;
        },
        breaks: true,
        gfm: true
      });
    }

    // Render existing .md-content elements
    document.querySelectorAll('.md-content').forEach(function(el) {
      if (typeof marked !== 'undefined') {
        var raw = marked.parse(el.textContent);
        el.innerHTML = (typeof DOMPurify !== 'undefined') ? DOMPurify.sanitize(raw) : raw;
        el.querySelectorAll('pre code').forEach(function(block) {
          if (typeof hljs !== 'undefined') hljs.highlightElement(block);
        });
      }
    });

    // Initialize editors
    document.querySelectorAll('.md-editor').forEach(function(editor) {
      var textarea = editor.querySelector('.md-textarea');
      var preview = editor.querySelector('.md-preview');
      var btns = editor.querySelectorAll('.md-btn');
      var previewBtn = editor.querySelector('.md-preview-btn');
      var isPreview = false;

      function insertAround(before, after) {
        var start = textarea.selectionStart;
        var end = textarea.selectionEnd;
        var sel = textarea.value.substring(start, end);
        textarea.value = textarea.value.substring(0, start) + before + sel + after + textarea.value.substring(end);
        textarea.selectionStart = start + before.length;
        textarea.selectionEnd = start + before.length + sel.length;
        textarea.focus();
      }

      function insertLine(prefix) {
        var start = textarea.selectionStart;
        var lineStart = textarea.value.lastIndexOf('\\n', start - 1) + 1;
        textarea.value = textarea.value.substring(0, lineStart) + prefix + textarea.value.substring(lineStart);
        textarea.selectionStart = textarea.selectionEnd = start + prefix.length;
        textarea.focus();
      }

      btns.forEach(function(btn) {
        btn.addEventListener('click', function() {
          var action = btn.getAttribute('data-action');
          switch(action) {
            case 'bold': insertAround('**', '**'); break;
            case 'italic': insertAround('*', '*'); break;
            case 'strike': insertAround('~~', '~~'); break;
            case 'h1': insertLine('# '); break;
            case 'h2': insertLine('## '); break;
            case 'h3': insertLine('### '); break;
            case 'ul': insertLine('- '); break;
            case 'ol': insertLine('1. '); break;
            case 'quote': insertLine('> '); break;
            case 'code': insertAround('\\n```\\n', '\\n```\\n'); break;
            case 'link': insertAround('[', '](url)'); break;
            case 'image': insertAround('![alt](', ')'); break;
            case 'preview':
              isPreview = !isPreview;
              if (isPreview) {
                if (typeof marked !== 'undefined') {
                  var raw = marked.parse(textarea.value || '_Пусто_');
                  preview.innerHTML = (typeof DOMPurify !== 'undefined') ? DOMPurify.sanitize(raw) : raw;
                  preview.querySelectorAll('pre code').forEach(function(block) {
                    if (typeof hljs !== 'undefined') hljs.highlightElement(block);
                  });
                }
                preview.style.display = 'block';
                textarea.style.display = 'none';
                btn.classList.add('active');
              } else {
                preview.style.display = 'none';
                textarea.style.display = 'block';
                btn.classList.remove('active');
                textarea.focus();
              }
              break;
          }
        });
      });

      // Tab support in textarea
      textarea.addEventListener('keydown', function(e) {
        if (e.key === 'Tab') {
          e.preventDefault();
          var start = textarea.selectionStart;
          textarea.value = textarea.value.substring(0, start) + '  ' + textarea.value.substring(textarea.selectionEnd);
          textarea.selectionStart = textarea.selectionEnd = start + 2;
        }
      });
    });

    // === GAMES (JSCL-based) ===
    var gameOverlay = document.getElementById('games-overlay');
    var gameCanvas = document.getElementById('game-canvas');
    var gameScoreEl = document.getElementById('game-score');
    var gameTitleEl = document.getElementById('games-modal-title');
    var gamesMenu = document.getElementById('games-menu');
    var gamePlay = document.getElementById('game-play');
    var currentGame = null;
    var gameAnimFrame = null;

    // JSCL loading
    var jsclLoaded = false;
    var jsclLoading = false;
    var jsclLoadQueue = [];
    var JSCL_CDN = 'https://jscl-project.github.io/';

    function loadGameJscl(callback) {
      if (jsclLoaded) { callback(); return; }
      jsclLoadQueue.push(callback);
      if (jsclLoading) return;
      jsclLoading = true;
      loadScript(JSCL_CDN + 'jscl.js', function() {
        jsclLoaded = true;
        jsclLoading = false;
        while (jsclLoadQueue.length > 0) jsclLoadQueue.shift()();
      });
    }

    function evalGameSource(source, lang) {
      var canvas = document.getElementById('game-canvas');
      window._canvas = canvas;
      window._ctx = canvas.getContext('2d');
      window._keys = {};

      // Helper: convert JSCL strings (char arrays) to native JS strings
      function toJS(s) { return (typeof s === 'string') ? s : (Array.isArray(s) ? s.join('') : '' + s); }
      window._cl = function(ctx, w, h) { ctx.fillStyle='#0a0a0a'; ctx.fillRect(0,0,w,h); };
      window._fr = function(ctx, x, y, w, h) { ctx.fillRect(x,y,w,h); };
      window._sc = function(ctx, c) { ctx.fillStyle = toJS(c); };
      window._fs = function(ctx, f) { ctx.font = toJS(f); };
      window._ta = function(ctx, a) { ctx.textAlign = toJS(a); };
      window._ft = function(ctx, s, x, y) { ctx.fillText(toJS(s),x,y); };
      window._bp = function(ctx) { ctx.beginPath(); };
      window._mt = function(ctx, x, y) { ctx.moveTo(x,y); };
      window._lt = function(ctx, x, y) { ctx.lineTo(x,y); };
      window._cp = function(ctx) { ctx.closePath(); };
      window._fl = function(ctx) { ctx.fill(); };
      window._ac = function(ctx, x, y, r, s, e) { ctx.arc(x,y,r,s,e); };
      // Keyboard bridge: JS only captures raw keyCode → _pk[keyCode]
      // ALL key mapping and logic is in CL
      window._pk = new Array(256).fill(0);  // _pk[keyCode] = 1 when pressed, 0 when released
      window._kpc = function(code) { return window._pk[code] || 0; };
      document.addEventListener('keydown', function(e) {
        window._pk[e.keyCode] = 1;
        if ([37,38,39,40,32].indexOf(e.keyCode) !== -1) e.preventDefault();
      });
      document.addEventListener('keyup', function(e) {
        window._pk[e.keyCode] = 0;
      });
      // Sound effects via Web Audio API — retro 8-bit style
      window._actx = null;
      function _getAC() {
        if (!window._actx) window._actx = new (window.AudioContext || window.webkitAudioContext)();
        if (window._actx.state === 'suspended') window._actx.resume();
        return window._actx;
      }
      window._snd = function(type) {
        try {
          var ac = _getAC();
          var o = ac.createOscillator();
          var g = ac.createGain();
          o.connect(g); g.connect(ac.destination);
          var t = ac.currentTime;
          if (type === 'shoot') {
            o.type = 'square'; o.frequency.setValueAtTime(880, t);
            o.frequency.exponentialRampToValueAtTime(440, t + 0.1);
            g.gain.setValueAtTime(0.15, t);
            g.gain.exponentialRampToValueAtTime(0.001, t + 0.1);
            o.start(t); o.stop(t + 0.1);
          } else if (type === 'hit') {
            o.type = 'sawtooth'; o.frequency.setValueAtTime(300, t);
            o.frequency.exponentialRampToValueAtTime(50, t + 0.2);
            g.gain.setValueAtTime(0.2, t);
            g.gain.exponentialRampToValueAtTime(0.001, t + 0.2);
            o.start(t); o.stop(t + 0.2);
          } else if (type === 'hurt') {
            o.type = 'sawtooth'; o.frequency.setValueAtTime(200, t);
            o.frequency.exponentialRampToValueAtTime(80, t + 0.3);
            g.gain.setValueAtTime(0.2, t);
            g.gain.exponentialRampToValueAtTime(0.001, t + 0.3);
            o.start(t); o.stop(t + 0.3);
          } else if (type === 'over') {
            o.type = 'square'; o.frequency.setValueAtTime(440, t);
            o.frequency.exponentialRampToValueAtTime(55, t + 0.8);
            g.gain.setValueAtTime(0.15, t);
            g.gain.exponentialRampToValueAtTime(0.001, t + 0.8);
            o.start(t); o.stop(t + 0.8);
          }
        } catch(e) {}
      };
      if (lang === 'js') {
        new Function(source)();
        if (window._lispInvadersStart) { window._lispInvadersStart(); }
        return;
      }

      // CL game — use JSCL
      // Eval each top-level form SEPARATELY (progn creates IIFE that isolates all symbols)
      var _clRead = jscl.packages['COMMON-LISP'].symbols['READ-FROM-STRING'];
      var _clEval = jscl.packages['COMMON-LISP'].symbols['EVAL'];

      function skipComments(src, pos) {
        while (pos < src.length) {
          if (src[pos] === ';') {
            while (pos < src.length && src[pos] !== '\\n') pos++;
          } else if (src[pos] === ' ' || src[pos] === '\\n' || src[pos] === '\\t' || src[pos] === '\\r') {
            pos++;
          } else {
            break;
          }
        }
        return pos;
      }

      function readOneForm(src, startPos) {
        var pos = skipComments(src, startPos);
        if (pos >= src.length) return -1;
        var ch = src[pos];
        // If not starting with (, it's not a form we can parse
        if (ch !== '(') return -1;
        var depth = 0, inStr = false, esc = false;
        var start = pos;
        while (pos < src.length) {
          var c = src[pos];
          if (esc) { esc = false; pos++; continue; }
          if (c === '\\\\' && inStr) { esc = true; pos++; continue; }
          if (c === '\"' && !esc) { inStr = !inStr; pos++; continue; }
          if (inStr) { pos++; continue; }
          if (c === ';') { while (pos < src.length && src[pos] !== '\\n') pos++; continue; }
          if (c === '(') depth++;
          else if (c === ')') { depth--; }
          pos++;
          if (depth === 0) return pos;
        }
        return -1; // unclosed
      }

      try {
        var pos = 0;
        var formCount = 0;
        while (pos < source.length) {
          var end = readOneForm(source, pos);
          if (end <= 0) { break; }
          var form = source.substring(pos, end);
          pos = end;
          try {
            var clInput = jscl.internals.make_lisp_string(form);
            var readForm = _clRead.fvalue(clInput);
            _clEval.fvalue(readForm);
            formCount++;
          } catch(e) {
          }
        }
      } catch(e) {
      }

      // JS-driven game loop with sound effects
      var frameCount = 0;
      var prevScore = 0, prevLives = 3, prevBullets = 0;

      // Helper to call CL functions by form string
      function callClForm(formStr) {
        var f = _clRead.fvalue(jscl.internals.make_lisp_string(formStr));
        var result = _clEval.fvalue(f);
        if (result === null || result === undefined) return 0;
        if (typeof result === 'object' && result.name === 'NIL') return 0;
        return result;
      }

      // Export state from CL to JS (called by game-loop-raw)
      window._clScore = 0;
      window._clLives = 3;
      window._clGameOver = 0;
      window._exportGameState = function(score, lives, gameOver, bullets) {
        window._clScore = (typeof score === 'number') ? score : 0;
        window._clLives = (typeof lives === 'number') ? lives : 3;
        window._clGameOver = gameOver ? 1 : 0;
        window._clBullets = (typeof bullets === 'number') ? bullets : 0;
      };

      // Call start
      try {
        callClForm('(start-lisp-invaders)');
      } catch(e) {
      }

      // Cache CL function references for performance (avoid read+eval each frame)
      var _clGameLoopRef = null;
      try {
        _clGameLoopRef = jscl.packages['CL-USER'].symbols['GAME-LOOP-RAW'];
      } catch(e) {}

      function jsGameLoop() {
        try {
          if (_clGameLoopRef && _clGameLoopRef.fvalue) {
            _clGameLoopRef.fvalue();
          } else {
            callClForm('(game-loop-raw)');
          }
          var score = window._clScore;
          var lives = window._clLives;
          var gameOver = window._clGameOver;
          var bullets = window._clBullets;
          if (score !== prevScore) { _snd('hit'); prevScore = score; }
          if (bullets !== prevBullets) { _snd('shoot'); prevBullets = bullets; }
          if (lives !== prevLives) { _snd('hurt'); prevLives = lives; }
          if (gameOver) { _snd('over'); return; }
          frameCount++;
        } catch(e) {
          return;
        }
        gameAnimFrame = requestAnimationFrame(jsGameLoop);
      }
      gameAnimFrame = requestAnimationFrame(jsGameLoop);
    }

    function openGamesOverlay() {
      if (!gameOverlay) return;
      gameOverlay.classList.add('active');
      showGamesMenu();
    }

    function showGamesMenu() {
      if (gamesMenu) gamesMenu.style.display = '';
      if (gamePlay) gamePlay.style.display = 'none';
      if (gameTitleEl) gameTitleEl.textContent = 'Lisp \u0418\u0433\u0440\u044b';
    }

    function startGame(name) {
      if (!gameCanvas) return;
      if (gamesMenu) gamesMenu.style.display = 'none';
      if (gamePlay) gamePlay.style.display = 'flex';
      if (gameTitleEl) gameTitleEl.textContent = name;

      // CL games need JSCL
      loadGameJscl(function() {
        var sourceEl = document.getElementById('game-source-' + name);
        if (sourceEl) {
          try {
            evalGameSource(sourceEl.textContent);
          } catch(e) {
            if (gamePlay) gamePlay.innerHTML = '<div style=\"color:#ef4444;padding:40px;text-align:center\"><h3>\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0441\u043a\u0438 \u0438\u0433\u0440\u044b</h3><p>' + e.message + '</p></div>';
          }
        }
      });
    }

    function closeGame() {
      if (gameOverlay) gameOverlay.classList.remove('active');
      if (gameAnimFrame) { cancelAnimationFrame(gameAnimFrame); gameAnimFrame = null; }
      if (window._lispInvadersStop) window._lispInvadersStop();
      currentGame = null;
      showGamesMenu();
    }

    // Game card clicks
    document.querySelectorAll('.game-card').forEach(function(card) {
      card.addEventListener('click', function() {
        var game = card.getAttribute('data-game');
        if (game) startGame(game);
      });
    });

    // Games nav button
    var gamesNav = document.getElementById('games-nav-btn');
    if (gamesNav) {
      gamesNav.addEventListener('click', function(e) {
        e.preventDefault();
        openGamesOverlay();
      });
    }

    // Back button
    var backBtn = document.querySelector('.game-back-btn');
    if (backBtn) {
      backBtn.addEventListener('click', function() {
        if (gameAnimFrame) { cancelAnimationFrame(gameAnimFrame); gameAnimFrame = null; }
        currentGame = null;
        showGamesMenu();
      });
    }

    // Close game
    document.querySelectorAll('.game-close').forEach(function(btn) {
      btn.addEventListener('click', function(e) {
        e.preventDefault();
        e.stopPropagation();
        closeGame();
      });
    });

    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape' && gameOverlay && gameOverlay.classList.contains('active')) {
        closeGame();
      }
    });
  });
})();")
