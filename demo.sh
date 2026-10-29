#!/usr/bin/env bash
# Shows that an incremental build compiles Caller.groovy differently than a full build although it did not change.
# Restores the source it edits. Pass Gradle options through, for example: ./demo.sh -PgroovyVersion=5.1.4-SNAPSHOT
set -euo pipefail
cd "$(dirname "$0")"

UTIL=src/main/groovy/Util.groovy
CLASS=build/classes/groovy/main/Caller.class
OUT=build/demo
show() {
    local out
    out=$(javap -v -p "$1" | grep -E 'Class +.*Factory' | sed -E 's/^ *#[0-9]+ = //; s/ +/ /g' | sort -u || true)
    if [ -n "$out" ]; then echo "$out"; else echo "  (none)"; fi
}

echo "== 1. Full build: all classes are compiled together"
./gradlew --console=plain -q "$@" clean classes
mkdir -p "$OUT"
cp "$CLASS" "$OUT/full.class"
RUN_FULL=$(./gradlew --console=plain -q "$@" run 2>&1 | tail -1)

echo
echo "== 2. Change a method body in Util, which Caller uses only inside a method body"
sed -i.bak "s/'loading'/'loading...'/" "$UTIL"
trap 'mv "$UTIL.bak" "$UTIL"' EXIT

echo
echo "== 3. Incremental build: Caller is recompiled against the other classes compiled"
./gradlew --console=plain --info "$@" classes | grep -E "Incremental compilation of|Full recompilation is required" || true
cp "$CLASS" "$OUT/incremental.class"
RUN_INCREMENTAL=$(./gradlew --console=plain -q "$@" run 2>&1 | grep -m1 -E 'Exception|hello' || true)

echo
echo "== 4. class Caller refers to as Factory, full build:"
show "$OUT/full.class"
echo "== class Caller refers to as Factory, incremental build:"
show "$OUT/incremental.class"

echo
echo "== 5. Running Caller"
echo "full build:        $RUN_FULL"
echo "incremental build: $RUN_INCREMENTAL"
