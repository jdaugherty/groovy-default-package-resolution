#!/usr/bin/env bash
# The difference with groovyc alone, no build tool involved: compiles all classes together, then compiles
# Caller against the other classes compiled. Uses groovyc from the PATH, or the command in
# the GROOVYC environment variable.
set -euo pipefail
cd "$(dirname "$0")"
GROOVYC=${GROOVYC:-groovyc}
command -v "${GROOVYC%% *}" > /dev/null || { echo "groovyc not found; put it on the PATH or set GROOVYC"; exit 1; }

SRC=src/main/groovy
OUT=build/groovyc
rm -rf "$OUT"
mkdir -p "$OUT/together" "$OUT/first" "$OUT/second"

show() {
    local out
    out=$(javap -v -p "$1" | grep -E 'Class +.*Factory' | sed -E 's/^ *#[0-9]+ = //; s/ +/ /g' | sort -u || true)
    if [ -n "$out" ]; then echo "$out"; else echo "  (none)"; fi
}

echo "== all classes compiled together"
$GROOVYC -d "$OUT/together" "$SRC/Factory.groovy" "$SRC/Util.groovy" "$SRC/Caller.groovy"
echo "== Caller compiled against the other classes compiled"
$GROOVYC -d "$OUT/first" "$SRC/Factory.groovy" "$SRC/Util.groovy"
$GROOVYC -d "$OUT/second" -cp "$OUT/first" "$SRC/Caller.groovy"

echo
echo "== class Caller refers to as Factory, compiled together:"
show "$OUT/together/Caller.class"
echo "== class Caller refers to as Factory, compiled against the other classes:"
show "$OUT/second/Caller.class"
