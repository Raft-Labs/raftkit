#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/assert.sh"
source "$HERE/../lib/render.sh"

tmp="$(mktemp -d)"
cat > "$tmp/example.tmpl" <<'EOF'
Hello {{NAME}}, your id is {{USER_ID}}.
Block:
{{BLOCK}}
EOF

# Single-line vars
out="$(NAME=Rahul USER_ID=42 BLOCK='-' render "$tmp/example.tmpl")"
assert_contains "$out" "Hello Rahul, your id is 42." "scalar substitution"

# Multi-line block substitution
multi=$'line1\nline2\nline3'
out="$(NAME=X USER_ID=Y BLOCK="$multi" render "$tmp/example.tmpl")"
assert_contains "$out" "line1
line2
line3" "multi-line block substitution"

# Missing var leaves the placeholder so it is visible in review
out="$(NAME=Rahul USER_ID=42 render "$tmp/example.tmpl")"
assert_contains "$out" "{{BLOCK}}" "missing var stays as placeholder"

rm -rf "$tmp"
