#!/usr/bin/env bash
# run-panel.sh - scaffold and spawn the IQX plan-gate reviewers for one ticket.
#
# Fork-only (cloud-practitioner/firstmate), IQX Bitbucket work only, never
# offered upstream; nothing in core bin/ or skills calls it. See README.
# It drives the home's own bin/fm-brief.sh, fm-tasks-axi.sh and fm-spawn.sh and
# fills each brief with mk-lens-brief.py. The firstmate home is explicit:
# --home <dir>, or FM_HOME when --home is not given; it refuses when neither is
# set. Use --dry-run to print every command and run none of them.
#
# Usage:
#   run-panel.sh --ticket-dir <dir under data/> --key <KEY> --plan <plan> [options]
# Options:
#   --home <dir>            firstmate home (else FM_HOME)
#   --mode <m>              real (default): the three panel reviewers
#                           shadow-arch | shadow-sec: one shadow reviewer per model of --models-file
#                           runproof: the run-proof lens (adds the second model when --touches is given)
#   --extra <text>          extra context for the reviewers
#   --models-file <file>    shadow models, one per line (default <home>/state/shadow-models.txt)
#   --dispositions <file> --changes <file>   runproof: the lens's first inputs (both required)
#   --touches <what>        runproof, repeatable: runner | identity | resume (adds the second model)
#   --seed <text>           runproof, repeatable: a seed made for this ticket
#   --project <name>        module clone name (default iqx.orchestration.online)
#   --base-branch <name>    default development/preview
#   --harness <name>        default pi
#   --effort <level>        default high
#   --arch-model, --sec-model, --ba-model, --runproof-model, --runproof-second-model <id>
#   --dry-run               print the commands, run none
# Task ids: <KEY>-rev-arch, <KEY>-rev-sec, <KEY>-rev-ba, <KEY>-sh-arch-<model>,
# <KEY>-sh-sec-<model>, <KEY>-runproof, <KEY>-runproof-2.
set -u

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
ROOT=${FM_CODE_ROOT:-$(cd "$here/../.." && pwd -P)}
GEN="$here/mk-lens-brief.py"

die() { echo "run-panel: $*" >&2; exit 2; }

HOME_DIR=
TD='' K='' PLAN='' EXTRA='' MODE=real MODELS_FILE='' DISP='' CHANGES=''
PROJECT=iqx.orchestration.online BASE=development/preview HARNESS=pi EFFORT=high
ARCH=github-copilot/claude-opus-5.5 SEC=github-copilot/claude-opus-5.5 BA=github-copilot/claude-sonnet-5.5
RP=github-copilot/claude-opus-5.5 RP2=github-copilot/gpt-6.1-sol
DRY=0
TOUCHES=() SEEDS=()

while [ $# -gt 0 ]; do
  case $1 in
    --home) HOME_DIR=${2-}; shift 2;;
    --ticket-dir) TD=${2-}; shift 2;;
    --key) K=${2-}; shift 2;;
    --plan) PLAN=${2-}; shift 2;;
    --extra) EXTRA=${2-}; shift 2;;
    --mode) MODE=${2-}; shift 2;;
    --models-file) MODELS_FILE=${2-}; shift 2;;
    --dispositions) DISP=${2-}; shift 2;;
    --changes) CHANGES=${2-}; shift 2;;
    --touches) TOUCHES+=("${2-}"); shift 2;;
    --seed) SEEDS+=("${2-}"); shift 2;;
    --project) PROJECT=${2-}; shift 2;;
    --base-branch) BASE=${2-}; shift 2;;
    --harness) HARNESS=${2-}; shift 2;;
    --effort) EFFORT=${2-}; shift 2;;
    --arch-model) ARCH=${2-}; shift 2;;
    --sec-model) SEC=${2-}; shift 2;;
    --ba-model) BA=${2-}; shift 2;;
    --runproof-model) RP=${2-}; shift 2;;
    --runproof-second-model) RP2=${2-}; shift 2;;
    --dry-run) DRY=1; shift;;
    -h|--help) sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0;;
    *) die "unknown argument: $1";;
  esac
done

H=${HOME_DIR:-${FM_HOME:-}}
[ -n "$H" ] || die "no firstmate home: pass --home <dir> or set FM_HOME (refusing to guess one)"
[ -d "$H/data" ] || die "$H is not a firstmate home (no data/ directory)"
H=$(cd "$H" && pwd -P)
{ [ -n "$TD" ] && [ -n "$K" ] && [ -n "$PLAN" ]; } || die "--ticket-dir, --key and --plan are required"
case $MODE in real|shadow-arch|shadow-sec|runproof) ;; *) die "unknown --mode: $MODE";; esac

run() { # run <command...>: print it in dry-run mode, run it otherwise
  if [ "$DRY" = 1 ]; then printf 'would run:'; printf ' %q' "$@"; printf '\n'; return 0; fi
  "$@"
}
qrun() { # like run, with the command's own stdout dropped
  if [ "$DRY" = 1 ]; then run "$@"; else "$@" >/dev/null; fi
}

spawn() { # spawn <task-id> <title> <model> <generator args...>
  local tid=$1 title=$2 model=$3
  shift 3
  run rm -f "$H/data/$tid/brief.md"
  qrun env FM_HOME="$H" "$ROOT/bin/fm-brief.sh" "$tid" "$PROJECT" --scout --base-branch "$BASE" || return 1
  if [ "$DRY" = 1 ]; then
    echo "would run: fm-tasks-axi.sh add $tid (only when show finds none)"
  else
    FM_HOME="$H" "$ROOT/bin/fm-tasks-axi.sh" show "$tid" >/dev/null 2>&1 ||
      FM_HOME="$H" "$ROOT/bin/fm-tasks-axi.sh" add "$tid" "iqx $K $title" --kind scout --repo "$PROJECT" \
        --body "Plan-gate reviewer for $K ($title). Output under data/$TD/plans/reviews/." >/dev/null
  fi
  qrun python3 "$GEN" "$@" --home "$H" --task "$tid" --ticket "$TD" --plan "$PLAN" --base-branch "$BASE" --extra "$EXTRA" || return 1
  if [ "$DRY" = 1 ]; then
    echo "would run: env FM_HOME=$H $ROOT/bin/fm-spawn.sh $tid $H/projects/$PROJECT --scout --base-branch $BASE --harness $HARNESS --model $model --effort $EFFORT"
  else
    FM_HOME="$H" "$ROOT/bin/fm-spawn.sh" "$tid" "$H/projects/$PROJECT" --scout --base-branch "$BASE" \
      --harness "$HARNESS" --model "$model" --effort "$EFFORT" 2>&1 | tail -1
  fi
}

case $MODE in
  real)
    spawn "$K-rev-arch" "panel: solutions-architect reviewer" "$ARCH" panel --lens solutions-architect
    spawn "$K-rev-sec" "panel: security-architect reviewer" "$SEC" panel --lens security-architect
    spawn "$K-rev-ba" "panel: business-analyst reviewer" "$BA" panel --lens business-analyst
    ;;
  shadow-arch | shadow-sec)
    MODELS_FILE=${MODELS_FILE:-$H/state/shadow-models.txt}
    [ -r "$MODELS_FILE" ] || die "shadow models file not readable: $MODELS_FILE"
    if [ "$MODE" = shadow-arch ]; then lens=solutions-architect short=arch; else lens=security-architect short=sec; fi
    while read -r m; do
      [ -n "$m" ] || continue
      slug=${m##*/}
      slug=${slug//./}
      spawn "$K-sh-$short-$slug" "panel: $lens reviewer (shadow $m)" "$m" shadow --lens "$lens" --shadow-model "$m"
    done <"$MODELS_FILE"
    ;;
  runproof)
    { [ -n "$DISP" ] && [ -n "$CHANGES" ]; } || die "runproof needs --dispositions and --changes"
    rp_args=(runproof --dispositions "$DISP" --changes "$CHANGES")
    for t in "${TOUCHES[@]+"${TOUCHES[@]}"}"; do rp_args+=(--touches "$t"); done
    for s in "${SEEDS[@]+"${SEEDS[@]}"}"; do rp_args+=(--seed "$s"); done
    spawn "$K-runproof" "run-proof lens ($RP)" "$RP" "${rp_args[@]}" --model "$RP"
    if [ "${#TOUCHES[@]}" -gt 0 ]; then
      spawn "$K-runproof-2" "run-proof lens, second model ($RP2)" "$RP2" "${rp_args[@]}" --model "$RP2"
    fi
    ;;
esac
