#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD
EV=/home/node/.no-mistakes/evidence/01M3ZZZDR9X2H5N8PJ7ABWHZ3C
export TMPDIR="$ROOT/.test-phase-tmp"
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE TASKS_AXI_FILE TASKS_AXI_BACKEND FM_GATE_REFUSE_BYPASS
LAB=$(mktemp -d "$TMPDIR/fm-lab.XXXXXX")
trap 'rm -rf "$LAB"' EXIT
bin/fm-lab-home.sh create "$LAB" >/dev/null
export FM_HOME=$LAB
cp .tasks.toml "$LAB/.tasks.toml"
printf '## In flight\n\n## Queued\n\n## Done\n' > "$LAB/data/backlog.md"
URL=https://github.com/example/disposable-lab/pull/1
HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
{
  printf 'Real verdict command against an isolated owned contribution record; no network or forge mutations\n'
  bin/fm-captain-hold.sh hold delivery --title "Lab delivery $URL" --reason 'Choose contribution scope' --repo lab
  mkdir -p "$LAB/data/delivery"
  jq -n --arg url "$URL" --arg head "$HEAD" '{schema:"fm-contributions.v1",task:"delivery",records:[{url:$url,kind:"pr",checked_at:"2026-10-03T00:00:00Z",error:null,pending:[],seen:[],verdict:null,observation:{head:$head,state:"open",draft:false,mergeable:"mergeable",review_decision:"APPROVED",can_merge:false,checks:[],reviews:[],events:[]}}]}' > "$LAB/data/delivery/contributions.json"
  for ACTOR in captain fleet maintainer nobody; do
    bin/fm-contributions.sh verdict delivery "$URL" "$HEAD" "$URL#issuecomment-1" "$ACTOR" 'Lab judgment'
    jq -e --arg actor "$ACTOR" '.records[0].verdict.actor==$actor' "$LAB/data/delivery/contributions.json" >/dev/null
    jq '.records[0].verdict' "$LAB/data/delivery/contributions.json"
  done
  BEFORE=$(sha256sum "$LAB/data/delivery/contributions.json")
  if bin/fm-contributions.sh verdict delivery "$URL" "$HEAD" "$URL#issuecomment-1" bogus 'Invalid actor'; then echo 'ERROR invalid actor accepted'; exit 1; fi
  test "$BEFORE" = "$(sha256sum "$LAB/data/delivery/contributions.json")"
  echo 'Invalid actor left persisted contribution record unchanged.'
} > "$EV/contribution-actors.log" 2>&1
