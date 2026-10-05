# Fixture shell environment only: remove redundant stock-layout relocations
# introduced by the Pi adapter so the existing marked-lab guard remains active.
if [[ ${FM_HOME:-} == "${PROOF_ROOT:-/nonexistent}"/l.* ]] && [ -f "$FM_HOME/.fm-lab-home" ]; then
  for key in ROOT STATE DATA CONFIG PROJECTS; do
    variable="FM_${key}_OVERRIDE"
    case "$key" in
      ROOT) expected=$PROOF_ROOT ;;
      STATE) expected=$FM_HOME/state ;;
      DATA) expected=$FM_HOME/data ;;
      CONFIG) expected=$FM_HOME/config ;;
      PROJECTS) expected=$FM_HOME/projects ;;
    esac
    [ "${!variable:-}" != "$expected" ] || unset "$variable"
  done
  export PATH="$PROOF_ROOT/.validation/tools/usr/bin:$PATH"
fi
