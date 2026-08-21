#!/usr/bin/env bash
# Тесты proof-of-work (src/antispam.lisp + solver из site-бандла).
# 1) SBCL: unit-тесты make-pow-challenge/verify-pow/leading-zero-bits
#    (загружает НАСТОЯЩИЙ src/antispam.lisp со стабом config)
# 2) node: solver из build/jscl-bundles/site.js добывает валидный nonce
set -uo pipefail
cd "$(dirname "$0")/../.."
ROOT="$PWD"

total_pass=0; total_fail=0

echo "== SBCL unit: antispam PoW =="
out=$(timeout 120 sbcl --non-interactive --load tests/pow/pow.test.lisp 2>&1 \
        | grep -E '^PASS|^FAIL|^PASS=' || true)
echo "$out"
p=$(echo "$out" | tail -1 | grep -oE 'PASS=[0-9]+' | grep -oE '[0-9]+')
f=$(echo "$out" | tail -1 | grep -oE 'FAIL=[0-9]+' | grep -oE '[0-9]+')
total_pass=$((total_pass + ${p:-0})); total_fail=$((total_fail + ${f:-0}))

if [ ! -f build/jscl-bundles/site.js ]; then
  echo "== SKIP node-solver (нет build/jscl-bundles/site.js — сделай make build) =="
else
  echo "== node: browser solver (site bundle) =="
  out=$(timeout 120 node "tests/pow/solver.test.js" 2>&1 | grep -E '^PASS|^FAIL|^SKIP|PASS=' || true)
  echo "$out"
  p=$(echo "$out" | tail -1 | grep -oE 'PASS=[0-9]+' | grep -oE '[0-9]+')
  f=$(echo "$out" | tail -1 | grep -oE 'FAIL=[0-9]+' | grep -oE '[0-9]+')
  total_pass=$((total_pass + ${p:-0})); total_fail=$((total_fail + ${f:-0}))
fi

echo "== node: клик по кнопке (submit gating) =="
out=$(timeout 60 node --stack-size=65536 tests/pow/click.test.js 2>&1 | grep -E '^PASS|^FAIL|PASS=' || true)
echo "$out"
p=$(echo "$out" | tail -1 | grep -oE 'PASS=[0-9]+' | grep -oE '[0-9]+')
f=$(echo "$out" | tail -1 | grep -oE 'FAIL=[0-9]+' | grep -oE '[0-9]+')
total_pass=$((total_pass + ${p:-0})); total_fail=$((total_fail + ${f:-0}))

echo "== ИТОГО: PASS=$total_pass FAIL=$total_fail =="
[ "$total_fail" -eq 0 ]