#!/usr/bin/env bash
set -euo pipefail
E=/home/node/.no-mistakes/evidence/01M47HX8Y8BQRSDDHWXNW190JH
ROOT=$PWD
[ ! -e .targeted-test-tmp ] && [ ! -e tests/.herdr-targeted-runtime.test.sh ] || exit 1
mkdir -p .targeted-test-tmp
export TMPDIR="$ROOT/.targeted-test-tmp"
cleanup() { chmod -R u+w .targeted-test-tmp 2>/dev/null || true; rm -rf .targeted-test-tmp tests/.herdr-targeted-runtime.test.sh; }
trap cleanup EXIT
# Execute the existing regression functions, not the unrelated backend suite.
# Copy only to retain its normal BASH_SOURCE-relative shared helper imports.
python3 - <<'PY'
from pathlib import Path
s=Path('tests/fm-backend-herdr.test.sh').read_text().split('\ntest_version_check_accepts_current_protocol\n',1)[0]
selectors=[
 'test_recorded_endpoint_from_a_previous_session_is_never_the_tasks_agent',
 'test_process_bound_endpoint_rejects_matching_labels_and_worktrees',
 'test_process_identity_is_portable_and_distinguishes_pid_reuse',
 'test_spawn_and_relaunch_continue_without_process_identity',
 'test_projection_abort_cleans_response_owned_pane_despite_stale_record',
 'test_active_operations_check_ownership_after_server_restore',
 'test_secondmate_probe_cannot_borrow_another_tasks_binding',
 'test_teardown_uses_descendant_state_and_confirms_closed_bound_panes',
]
Path('tests/.herdr-targeted-runtime.test.sh').write_text(s+'\n'+'\n'.join(selectors)+'\n')
print('Selected executable regressions:\n'+'\n'.join(selectors))
PY
bash tests/.herdr-targeted-runtime.test.sh
bash tests/fm-remote-secondmate-control.test.sh
