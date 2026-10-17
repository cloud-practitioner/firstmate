#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/node/.no-mistakes/worktrees/450411b3e67c/01M55ZEBSTEQDE51HBJ3XNZ6TR
SESSION=fm-lab-empty
if [[ "${1:-}" == --version ]]; then exec /home/node/.local/bin/herdr --version; fi
args=()
while (($#)); do
  case "$1" in
    --session) [[ "$2" == "$SESSION" ]] || { echo 'Refusing non-lab session' >&2; exit 1; }; shift 2 ;;
    --session=*) [[ "${1#*=}" == "$SESSION" ]] || exit 1; shift ;;
    *) args+=("$1"); shift ;;
  esac
done
PATH="$ORIGINAL_PATH" exec "$ROOT/bin/fm-herdr-lab.sh" run "$SESSION" "${args[@]}"
