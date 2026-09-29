#!/usr/bin/env bash
log='/tmp/fm-lab.fka9Bl/ext/curl-argv.log'
printf '%s\n' "$*" >> "$log"
args=()
for a in "$@"; do
  case "$a" in
    https://api.bitbucket.org/2.0/*) a="http://127.0.0.1:18765/2.0/${a#https://api.bitbucket.org/2.0/}" ;;
  esac
  args+=("$a")
done
exec /usr/bin/curl "${args[@]}"
