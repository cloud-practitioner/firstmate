#!/usr/bin/env bash
# Restore only disposable fixture permissions so their read-only Git hook
# templates can be removed. Never change the actual product's hook store.
for arg in "$@"; do
  case "$arg" in
    /home/node/.no-mistakes/worktrees/c98b859efde5/01M469KHGAXW3MXGQ83EVZD7E8/.v/tmp/*)
      if [ -d "$arg" ] && [ ! -L "$arg" ]; then chmod -R u+w -- "$arg"; fi
      ;;
  esac
done
exec /usr/bin/rm "$@"
