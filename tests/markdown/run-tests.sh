#!/usr/bin/env bash
# Тесты чистого CL markdown-парсера (jscl-tools/markdown.lisp).
# Требует node (jscl/jscl-node.js). Компилирует бандл и прогоняет 4 набора.
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT="$PWD"
BUNDLE="${TMPDIR:-/tmp}/markdown.test.bundle.js"

echo "== компиляция jscl-tools/markdown.lisp -> $BUNDLE =="
sed 's#@BUNDLE@#'"$BUNDLE"'#' tests/markdown/compile.lisp > "${TMPDIR:-/tmp}/markdown.compile.lisp"
node --stack-size=65536 jscl/jscl-node.js "${TMPDIR:-/tmp}/markdown.compile.lisp" \
  | grep -E 'MD-COMPILE-OK' || { echo "ОШИБКА: бандл не собран"; exit 1; }
ls -la "$BUNDLE"

total_pass=0; total_fail=0
run() {
  local name="$1"
  echo "== $name =="
  export BUNDLE
  local out
  out=$(node --stack-size=65536 "tests/markdown/$name.test.js" 2>&1 \
          | grep -E '^PASS=|^ALL PASS|^FAIL: ' || true)
  echo "$out"
  local p f
  p=$(echo "$out" | grep -oE 'PASS=[0-9]+' | head -1 | grep -oE '[0-9]+' || true)
  if [ -z "${p:-}" ]; then p=$(echo "$out" | grep -c 'PASS: ' || true); fi
  f=$(echo "$out" | grep -oE 'FAIL=[0-9]+' | head -1 | grep -oE '[0-9]+$' || true)
  total_pass=$((total_pass + ${p:-0})); total_fail=$((total_fail + ${f:-0}))
}

run smoke
run full
run edge
run spec-emphasis

echo
echo "ИТОГО: PASS=$total_pass FAIL=$total_fail"
[ "$total_fail" = 0 ] && echo "ВСЕ ТЕСТЫ ПРОШЛИ" || echo "ЕСТЬ УПАВШИЕ ТЕСТЫ"