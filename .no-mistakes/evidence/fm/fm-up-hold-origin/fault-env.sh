# Runtime fault injection only: the product and tasks-axi are never replaced.
# Interrupt the real process or revoke its real disposable backlog permissions.
if [[ ( "$0" == */bin/fm-captain-hold.sh || "$0" == */before-fix-captain-hold.sh ) && -n "${VALIDATION_FAULT:-}" ]]; then
  validation_fault() {
    local cmd=$1
    if [[ "$VALIDATION_FAULT" == interrupt && "$cmd" == tasks_axi\ hold* ]]; then
      trap - DEBUG
      printf 'FAULT: TERM before real backend hold; stamped body retains previous origin\n' >&2
      kill -TERM "$$"
    elif [[ "$VALIDATION_FAULT" == refuse && "$cmd" == tasks_axi\ hold* ]]; then
      trap - DEBUG
      printf 'FAULT: remove write permission from disposable backlog and data dir before backend hold\n' >&2
      chmod 400 "$FM_HOME/data/backlog.md"
      chmod 500 "$FM_HOME/data"
    elif [[ "$VALIDATION_FAULT" == origin-write && "$cmd" == tasks_axi\ update* ]] && [[ -n "${tmp:-}" ]] && grep -qx 'Captain hold origin: origin-b' "$tmp"; then
      trap - DEBUG
      printf 'FAULT: remove write permission only at origin publication, after successful real backend hold\n' >&2
      chmod 400 "$FM_HOME/data/backlog.md"
      chmod 500 "$FM_HOME/data"
    fi
    return 0
  }
  set -T
  trap 'validation_fault "$BASH_COMMAND"' DEBUG
fi
