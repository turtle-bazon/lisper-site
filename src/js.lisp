(in-package :lisper)

;;; Versioned, cache-busting URL for /jscl.js. The bundled JSCL runtime
;;; (~2.4MB) is served with Cache-Control: max-age=1y, immutable; the
;;; version query is a SHA-256 of the content, so any JSCL bump produces
;;; a new URL and clients re-download exactly once.

(defun string-replace-all (needle replacement haystack)
  "Replace every occurrence of NEEDLE with REPLACEMENT in HAYSTACK."
  (if (zerop (length needle))
      haystack
      (with-output-to-string (out)
        (loop with start = 0
              for pos = (search needle haystack :start2 start)
              while pos
              do (write-string haystack out :start start :end pos)
                 (write-string replacement out)
                 (setf start (+ pos (length needle)))
              finally (write-string haystack out :start start)))))

(defvar *jscl-cache-key* nil)

(defun jscl-cache-key ()
  "SHA-256 hex of the embedded *jscl-js*; stable for identical content."
  (or *jscl-cache-key*
      (setf *jscl-cache-key*
            (format nil "~{~2,'0x~}"
                    (coerce (ironclad:digest-sequence
                             :sha256 (sb-ext:string-to-octets *jscl-js*))
                            'list)))))

(defun jscl-url ()
  (format nil "/jscl.js?v=~a" (jscl-cache-key)))

(defvar *jscl-bundle-cache-keys* (make-hash-table :test #'equal))

(defun jscl-bundle-cache-key (name)
  "SHA-256 hex of the bundle content for the versioned URL; memoized."
  (or (gethash name *jscl-bundle-cache-keys*)
      (setf (gethash name *jscl-bundle-cache-keys*)
            (let ((src (get-jscl-bundle name)))
              (when src
                (format nil "~{~2,'0x~}"
                        (coerce (ironclad:digest-sequence
                                 :sha256 (sb-ext:string-to-octets src))
                                'list)))))))

(defun jscl-bundle-url (name)
  (let ((key (jscl-bundle-cache-key name)))
    (when key
      (format nil "/jscl-bundle/~a?v=~a" name key))))

(defun generate-js ()
  (let ((bundle-urls
          (with-output-to-string (out)
            (dolist (name '("repl" "lisp-invaders" "lambda-runner"
                            "paren-matcher" "s-dungeon"))
              (let ((url (jscl-bundle-url name)))
                (when url
                  (format out "    \"~a\": \"~a\",~%" name url)))))))
    (string-replace-all "/jscl.js" (jscl-url)
      (string-replace-all "/*__JSCL_BUNDLE_URLS__*/" bundle-urls
        "(function() {
  var loaded = false;
  var loading = false;
  var jsclLoaded = false;
  var jsclLoading = false;
  var jsclLoadQueue = [];
  var _clRead = null;
  var _clEval = null;
  var bundleUrls = { /*__JSCL_BUNDLE_URLS__*/
  };

  function isJsclReady() {
    return typeof jscl !== 'undefined' && jscl.packages;
  }

  function onJsclLoaded(cb) {
    if (isJsclReady()) { jsclLoaded = true; jsclLoading = false; cb(); return; }
    jsclLoadQueue.push(cb);
    if (jsclLoading) return;
    jsclLoading = true;
    loadScript('/jscl.js', function() {
      jsclLoading = false;
      jsclLoaded = isJsclReady();
      while (jsclLoadQueue.length > 0) jsclLoadQueue.shift()();
    });
  }

  document.addEventListener('DOMContentLoaded', function() {
    if (isJsclReady()) { jsclLoaded = true; jsclLoading = false; }
    while (jsclLoadQueue.length > 0) jsclLoadQueue.shift()();
  });

  function loadScript(src, cb) {
    var s = document.createElement('script');
    s.src = src;
    s.onload = cb;
    s.onerror = function() {
      var c = document.getElementById('repl-console');
      if (!c) return;
      var div = document.createElement('div');
      div.className = 'repl-line error';
      div.textContent = 'Failed to load: ' + src;
      c.appendChild(div);
      c.scrollTop = c.scrollHeight;
    };
    document.head.appendChild(s);
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

  function evalToolSource(source, statusEl, callback) {
    _clRead = jscl.packages['COMMON-LISP'].symbols['READ-FROM-STRING'];
    _clEval = jscl.packages['COMMON-LISP'].symbols['EVAL'];

    function skipWs(src, pos) {
      while (pos < src.length) {
        if (src[pos] === ';') { while (pos < src.length && src[pos] !== '\\n') pos++; }
        else if (src[pos] === ' ' || src[pos] === '\\n' || src[pos] === '\\t' || src[pos] === '\\r') { pos++; }
        else break;
      }
      return pos;
    }

    function readForm(src, sp) {
      var p = skipWs(src, sp);
      if (p >= src.length) return -1;
      if (src[p] !== '(') return -1;
      var d = 0, s = false, e = false;
      while (p < src.length) {
        var c = src[p];
        if (e) { e = false; p++; continue; }
        if (c === '\\\\' && s) { e = true; p++; continue; }
        if (c === '\"' && !e) { s = !s; p++; continue; }
        if (s) { p++; continue; }
        if (c === ';') { while (p < src.length && src[p] !== '\\n') p++; continue; }
        if (c === '#' && p + 1 < src.length && src[p + 1] === '\\\\') { p += 2; if (/[a-zA-Z]/.test(src[p])) { while (p < src.length && /[a-zA-Z0-9]/.test(src[p])) p++; } else { p++; } continue; }
        if (c === '(') d++; else if (c === ')') d--;
        p++;
        if (d === 0) return p;
      }
      return -1;
    }

    var forms = [];
    var pos = 0;
    while (pos < source.length) {
      var end = readForm(source, pos);
      if (end <= 0) break;
      forms.push(source.substring(pos, end));
      pos = end;
    }
    var total = forms.length;
    var idx = 0;
    var batchSize = 5;

    function compileBatch() {
      var batchEnd = Math.min(idx + batchSize, total);
      while (idx < batchEnd) {
        try {
          var clForm = _clRead.fvalue(jscl.internals.make_lisp_string(forms[idx]));
          _clEval.fvalue(clForm);
        } catch(e) { console.error('Tool form ' + idx + '/' + total + ' FAILED:', e.message, forms[idx].substring(0, 80)); }
        idx++;
      }
      if (statusEl) statusEl.textContent = 'Compiling REPL code... ' + idx + '/' + total;
      if (idx < total) {
        setTimeout(compileBatch, 0);
      } else {
        console.log('evalToolSource: compiled ' + total + ' forms');
        if (callback) callback();
      }
    }
    compileBatch();
  }

  window.openRepl = function() {
    var overlay = document.getElementById('repl-overlay');
    overlay.classList.add('active');
    var c = document.getElementById('repl-console');
    if (!c) return;

    if (loaded) {
      try { _clEval.fvalue(_clRead.fvalue(jscl.internals.make_lisp_string('(dom-focus-last-input)'))); } catch(ex) {}
      return;
    }
    if (loading) return;
    loading = true;

    c.innerHTML = '';

    function onJsclReady(existingStatus) {
      setupErrorHandler();
      _clRead = jscl.packages['COMMON-LISP'].symbols['READ-FROM-STRING'];
      _clEval = jscl.packages['COMMON-LISP'].symbols['EVAL'];

      var statusEl = existingStatus || document.createElement('div');
      if (!existingStatus) {
        statusEl.className = 'repl-line repl-status';
        statusEl.textContent = 'Loading REPL...';
        c.appendChild(statusEl);
      }

      var url = bundleUrls['repl'];
      if (!url) {
        statusEl.className = 'repl-line repl-error';
        statusEl.textContent = 'Error: repl bundle not available (was the build done with node?)';
        loaded = false;
        loading = false;
        return;
      }

      loadScript(url, function() {
        loaded = true;
        loading = false;
        c.innerHTML = '';

        try {
          _clEval.fvalue(_clRead.fvalue(jscl.internals.make_lisp_string('(repl-start)')));
        } catch(e) {
          var errDiv = document.createElement('div');
          errDiv.className = 'repl-line repl-error';
          errDiv.textContent = 'Error starting REPL: ' + e.message;
          c.appendChild(errDiv);
          _clEval.fvalue(_clRead.fvalue(jscl.internals.make_lisp_string('(repl-create-input-line)')));
        }
      });
    }

    var statusEl = document.createElement('div');
    statusEl.className = 'repl-line repl-status';
    statusEl.textContent = 'Loading JSCL...';
    c.appendChild(statusEl);
    c.scrollTop = c.scrollHeight;

    onJsclLoaded(function() {
      if (!isJsclReady()) {
        statusEl.className = 'repl-line repl-error';
        statusEl.textContent = 'Error: JSCL failed to load';
        loading = false;
        return;
      }
      onJsclReady(statusEl);
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
      var inp = document.querySelector('.repl-input-line:last-child .repl-input');
      if (inp && document.activeElement === inp && !inp.disabled) {
        e.preventDefault();
        if (e.shiftKey) {
          _clEval.fvalue(_clRead.fvalue(jscl.internals.make_lisp_string('(repl-enter t)')));
        } else {
          _clEval.fvalue(_clRead.fvalue(jscl.internals.make_lisp_string('(repl-enter nil)')));
        }
      }
    }
    if (e.key === 'ArrowUp') {
      var inp = document.activeElement;
      if (inp && inp.classList.contains('repl-input')) {
        e.preventDefault();
        try { _clEval.fvalue(_clRead.fvalue(jscl.internals.make_lisp_string('(repl-arrow-up)'))); } catch(ex) { console.error('ArrowUp error:', ex); }
      }
    }
    if (e.key === 'ArrowDown') {
      var inp = document.activeElement;
      if (inp && inp.classList.contains('repl-input')) {
        e.preventDefault();
        try { _clEval.fvalue(_clRead.fvalue(jscl.internals.make_lisp_string('(repl-arrow-down)'))); } catch(ex) { console.error('ArrowDown error:', ex); }
      }
    }
  });

  // === Markdown Editor ===
  document.addEventListener('DOMContentLoaded', function() {
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

    document.querySelectorAll('.md-content').forEach(function(el) {
      if (typeof marked !== 'undefined') {
        var raw = marked.parse(el.textContent);
        el.innerHTML = (typeof DOMPurify !== 'undefined') ? DOMPurify.sanitize(raw) : raw;
        el.querySelectorAll('pre code').forEach(function(block) {
          if (typeof hljs !== 'undefined') hljs.highlightElement(block);
        });
      }
    });

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

    function loadGameJscl(callback) {
      onJsclLoaded(callback);
    }

    function evalGameSource(source, gameName) {
      var pkgName = gameName.toUpperCase();
      var startFn = gameName + ':start-' + gameName;
      var loopFn = gameName + ':game-loop-raw';
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
        if (ch !== '(') return -1;
        var depth = 0, inStr = false, esc = false;
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
        return -1;
      }

      var loadingEl = document.getElementById('game-loading');
      var fillEl = document.getElementById('game-loading-fill');
      var textEl = loadingEl ? loadingEl.querySelector('.game-loading-text') : null;

      var _forms = [];
      var _splitPos = 0;
      while (_splitPos < source.length) {
        var _end = readOneForm(source, _splitPos);
        if (_end <= 0) break;
        _forms.push(source.substring(_splitPos, _end));
        _splitPos = _end;
      }
      var _totalForms = _forms.length;

      function callClForm(formStr) {
        var f = _clRead.fvalue(jscl.internals.make_lisp_string(formStr));
        var result = _clEval.fvalue(f);
        if (result === null || result === undefined) return 0;
        if (typeof result === 'object' && result.name === 'NIL') return 0;
        return result;
      }
      var _clGameLoopRef = null;

      var _formIdx = 0;

      function compileNextBatch() {
        var batchEnd = Math.min(_formIdx + 1, _totalForms);
        while (_formIdx < batchEnd) {
          try {
            var clInput = jscl.internals.make_lisp_string(_forms[_formIdx]);
            var readForm = _clRead.fvalue(clInput);
            _clEval.fvalue(readForm);
          } catch(e) { console.error('Form ' + _formIdx + '/' + _totalForms + ' FAILED:', e.message, _forms[_formIdx].substring(0, 80)); }
          _formIdx++;
        }
        if (fillEl) fillEl.style.width = Math.round(_formIdx / _totalForms * 100) + '%';
        if (textEl) textEl.textContent = 'Загрузка... ' + _formIdx + '/' + _totalForms;
        if (_formIdx < _totalForms) {
          setTimeout(compileNextBatch, 0);
        } else {
          if (loadingEl) loadingEl.style.display = 'none';
          startGame();
        }
      }

      function startGame() {
        try {
          callClForm('(' + startFn + ')');
        } catch(e) {}
        try {
          _clGameLoopRef = jscl.packages[pkgName].symbols['GAME-LOOP-RAW'];
        } catch(e) {}
        var _firstFrame = true;
        function jsGameLoop() {
          try {
            if (_clGameLoopRef && _clGameLoopRef.fvalue) {
              _clGameLoopRef.fvalue();
            } else {
              callClForm('(' + loopFn + ')');
            }
          } catch(e) { return; }
          gameAnimFrame = requestAnimationFrame(jsGameLoop);
        }
        gameAnimFrame = requestAnimationFrame(jsGameLoop);
      }

      compileNextBatch();
    }

    function openGamesOverlay() {
      if (!gameOverlay) return;
      gameOverlay.classList.add('active');
      showGamesMenu();
    }

    function showGamesMenu() {
      if (gamesMenu) gamesMenu.style.display = '';
      if (gamePlay) gamePlay.style.display = 'none';
      if (gameTitleEl) { gameTitleEl.textContent = 'Lisp Игры'; gameTitleEl.href = '#'; }
    }

    function startGame(name) {
      if (!gameCanvas) return;
      if (gameAnimFrame) { cancelAnimationFrame(gameAnimFrame); gameAnimFrame = null; }
      currentGame = null;
      if (gamesMenu) gamesMenu.style.display = 'none';
      if (gamePlay) gamePlay.style.display = 'flex';
      if (gameTitleEl) { gameTitleEl.textContent = name; gameTitleEl.href = '/game-source/' + name; }

      var hints = {
        'lisp-invaders': '\\u2190 \\u2192 \\u2014 движение | пробел \\u2014 стрелять | P \\u2014 пауза | Enter \\u2014 заново',
        'lambda-runner': 'пробел \\u2014 прыжок | P \\u2014 пауза | Enter \\u2014 заново',
        'paren-matcher': '\\u2190 \\u2192 A D \\u2014 лови скобки | P \\u2014 пауза | Enter \\u2014 заново',
        's-dungeon': '\\u2190 \\u2192 \\u2191 \\u2193 WASD \\u2014 движение | . \\u2014 ждать | Enter \\u2014 заново'
      };
      var hintEl = document.getElementById('game-hint');
      if (hintEl) hintEl.textContent = hints[name] || '';

      var loadingEl = document.getElementById('game-loading');
      var fillEl = document.getElementById('game-loading-fill');
      if (loadingEl) loadingEl.style.display = '';
      if (fillEl) fillEl.style.width = '0%';

      var ctx = gameCanvas.getContext('2d');
      if (ctx) ctx.clearRect(0, 0, gameCanvas.width, gameCanvas.height);

      loadGameJscl(function() {
        var url = bundleUrls[name];
        var sourceEl = document.getElementById('game-source-' + name);
        if (url) {
          loadScript(url, function() {
            if (loadingEl) loadingEl.style.display = 'none';
            startCompiledGame(name);
          });
        } else if (sourceEl) {
          try {
            evalGameSource(sourceEl.textContent, name);
          } catch(e) {
            if (gamePlay) gamePlay.innerHTML = '<div style=\"color:#ef4444;padding:40px;text-align:center\"><h3>\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438 \u0438\u0433\u0440\u044b</h3><p>' + e.message + '</p></div>';
          }
        } else {
          if (loadingEl) loadingEl.style.display = 'none';
          if (gamePlay) gamePlay.innerHTML = '<div style=\"color:#ef4444;padding:40px;text-align:center\"><h3>\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438 \u0438\u0433\u0440\u044b</h3><p>Bundle \u0438 \u0438\u0441\u0445\u043e\u0434\u043d\u0438\u043a \u043d\u0435 \u0434\u043e\u0441\u0442\u0443\u043f\u043d\u044b</p></div>';
        }
      });
    }

    function startCompiledGame(name) {
      var pkgName = name.toUpperCase();
      var startFn = name + ':start-' + name;
      var _read = jscl.packages['COMMON-LISP'].symbols['READ-FROM-STRING'];
      var _eval = jscl.packages['COMMON-LISP'].symbols['EVAL'];
      try {
        _eval.fvalue(_read.fvalue(jscl.internals.make_lisp_string('(' + startFn + ')')));
      } catch(e) {
        console.error('startCompiledGame: start-' + name + ' failed', e);
      }
      var clGameLoopRef = null;
      try { clGameLoopRef = jscl.packages[pkgName].symbols['GAME-LOOP-RAW']; } catch(e) {}
      function jsGameLoop() {
        try {
          if (clGameLoopRef && clGameLoopRef.fvalue) clGameLoopRef.fvalue();
        } catch(e) { return; }
        gameAnimFrame = requestAnimationFrame(jsGameLoop);
      }
      gameAnimFrame = requestAnimationFrame(jsGameLoop);
    }

    function closeGame() {
      if (gameOverlay) gameOverlay.classList.remove('active');
      if (gameAnimFrame) { cancelAnimationFrame(gameAnimFrame); gameAnimFrame = null; }
      currentGame = null;
      showGamesMenu();
    }

    document.querySelectorAll('.game-card').forEach(function(card) {
      card.addEventListener('click', function() {
        var game = card.getAttribute('data-game');
        if (game) startGame(game);
      });
    });

    var gamesNav = document.getElementById('games-nav-btn');
    if (gamesNav) {
      gamesNav.addEventListener('click', function(e) {
        e.preventDefault();
        openGamesOverlay();
      });
    }

    var backBtn = document.querySelector('.game-back-btn');
    if (backBtn) {
      backBtn.addEventListener('click', function() {
        if (gameAnimFrame) { cancelAnimationFrame(gameAnimFrame); gameAnimFrame = null; }
        currentGame = null;
        showGamesMenu();
      });
    }

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
})();"))))
