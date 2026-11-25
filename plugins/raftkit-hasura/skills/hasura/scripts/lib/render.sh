# Tiny {{VAR}} template renderer. Source, do not execute.
#
# Usage: VAR1=foo VAR2=bar render path/to/file.tmpl
# Vars passed via the calling environment. Multi-line values are preserved.
# Unknown placeholders are left intact so reviewers can spot them.

render() {
  local file="$1"
  [ -f "$file" ] || { echo "render: file not found: $file" >&2; return 1; }

  # Defense in depth: callers occasionally leak a non-default IFS into us;
  # restore the default so the placeholder-name iteration below word-splits
  # correctly on whitespace/newlines.
  local IFS=$' \t\n'

  local content; content="$(cat "$file")"

  # Match the unique set of {{VAR}} names in the template.
  local names; names="$(grep -oE '\{\{[A-Z_][A-Z0-9_]*\}\}' "$file" \
    | sed 's/^{{//;s/}}$//' | sort -u)"

  local name value placeholder
  for name in $names; do
    if [ -n "${!name+set}" ]; then
      value="${!name}"
      placeholder="{{${name}}}"
      # Use awk with ENVIRON[] (not -v) so multi-line values pass through
      # safely on both BSD awk (macOS) and GNU awk (Linux). The -v flag
      # rejects literal newlines on BSD awk.
      content="$(
        __RENDER_P="$placeholder" __RENDER_V="$value" awk '
          BEGIN { p = ENVIRON["__RENDER_P"]; v = ENVIRON["__RENDER_V"] }
          {
            while ((i = index($0, p)) > 0) {
              $0 = substr($0,1,i-1) v substr($0,i+length(p))
            }
            print
          }' <<<"$content"
      )"
    fi
  done

  printf '%s\n' "$content"
}
