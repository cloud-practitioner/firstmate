# Bitbucket merge guards: live validation

## Method

Ran the unmodified target `bin/fm-pr-merge.sh` and `bin/fm-pr-check.sh` with real Bash, curl, jq, Git and TLS transport. A loopback HTTPS proxy served a disposable Bitbucket-shaped API, using synthetic credentials only; successful POSTs merged real disposable Git repositories. The product itself was not stubbed. No production API, credentials, fleet home, harness or shared session was used.

## Target CLI evidence

| API scenario | Exit | Merge body / observed refusal | Persisted outcome |
| --- | ---: | --- | --- |
| default-squash | 0 | `{"type":"pullrequest","close_source_branch":false,"merge_strategy":"squash"}` | Destination contains feature; merged state read back. |
| default-merge-commit | 0 | `{"type":"pullrequest","close_source_branch":false,"merge_strategy":"merge_commit"}` | Destination contains feature; merged state read back. |
| default-fast-forward | 0 | `{"type":"pullrequest","close_source_branch":false,"merge_strategy":"fast_forward"}` | Destination contains feature; merged state read back. |
| default-squash-fast-forward | 0 | `{"type":"pullrequest","close_source_branch":false,"merge_strategy":"squash_fast_forward"}` | Destination contains feature; merged state read back. |
| default-rebase-fast-forward | 0 | `{"type":"pullrequest","close_source_branch":false,"merge_strategy":"rebase_fast_forward"}` | Destination contains feature; merged state read back. |
| default-rebase-merge | 0 | `{"type":"pullrequest","close_source_branch":false,"merge_strategy":"rebase_merge"}` | Destination contains feature; merged state read back. |
| slash-destination | 0 | `{"type":"pullrequest","close_source_branch":false,"merge_strategy":"squash"}` | Destination contains feature; merged state read back. |
| default-http500 | 1 | error: refusing to merge https://bitbucket.org/fm-lab/default-http500/pull-requests/7<br>  - the configured default merge strategy of destination branch main could not be read (HTTP 500); name a strategy with --squash, --merge, --rebase, or --method, or fix the read | No merge POST; destination Git ref unchanged. |
| default-http403 | 1 | error: refusing to merge https://bitbucket.org/fm-lab/default-http403/pull-requests/7<br>  - the configured default merge strategy of destination branch main could not be read (HTTP 403); name a strategy with --squash, --merge, --rebase, or --method, or fix the read | No merge POST; destination Git ref unchanged. |
| default-unknown | 1 | error: refusing to merge https://bitbucket.org/fm-lab/default-unknown/pull-requests/7<br>  - destination branch main reports no merge strategy this script knows as its default (got "octopus"); name a strategy with --squash, --merge, --rebase, or --method, or fix the read | No merge POST; destination Git ref unchanged. |
| default-missing | 1 | error: refusing to merge https://bitbucket.org/fm-lab/default-missing/pull-requests/7<br>  - destination branch main reports no merge strategy this script knows as its default (got ""); name a strategy with --squash, --merge, --rebase, or --method, or fix the read | No merge POST; destination Git ref unchanged. |
| default-wrong-branch | 1 | error: refusing to merge https://bitbucket.org/fm-lab/default-wrong-branch/pull-requests/7<br>  - destination branch main reports no merge strategy this script knows as its default (got ""); name a strategy with --squash, --merge, --rebase, or --method, or fix the read | No merge POST; destination Git ref unchanged. |
| default-malformed | 1 | error: refusing to merge https://bitbucket.org/fm-lab/default-malformed/pull-requests/7<br>  - the configured default merge strategy of destination branch main could not be read (HTTP 200); name a strategy with --squash, --merge, --rebase, or --method, or fix the read | No merge POST; destination Git ref unchanged. |
| explicit-squash | 0 | `{"type":"pullrequest","close_source_branch":false,"merge_strategy":"squash"}` | Destination contains feature; merged state read back. |
| explicit-merge | 0 | `{"type":"pullrequest","close_source_branch":false,"merge_strategy":"merge_commit"}` | Destination contains feature; merged state read back. |
| explicit-rebase | 0 | `{"type":"pullrequest","close_source_branch":false,"merge_strategy":"rebase_fast_forward"}` | Destination contains feature; merged state read back. |
| explicit-method | 0 | `{"type":"pullrequest","close_source_branch":false,"merge_strategy":"rebase_merge"}` | Destination contains feature; merged state read back. |
| final-destination | 1 | error: https://bitbucket.org/fm-lab/final-destination/pull-requests/7 now targets release, not the verified destination branch main, so its merge checks were never read; nothing was merged | No merge POST; destination Git ref unchanged. |
| final-withdrawn | 1 | error: the reviews of https://bitbucket.org/fm-lab/final-withdrawn/pull-requests/7 changed after verification (approval withdrawn by {alice}); nothing was merged | No merge POST; destination Git ref unchanged. |
| final-replacement | 1 | error: the reviews of https://bitbucket.org/fm-lab/final-replacement/pull-requests/7 changed after verification (approval withdrawn by {alice}); nothing was merged | No merge POST; destination Git ref unchanged. |
| final-changes | 1 | error: the reviews of https://bitbucket.org/fm-lab/final-changes/pull-requests/7 changed after verification (changes requested by {carol}); nothing was merged | No merge POST; destination Git ref unchanged. |
| final-malformed | 1 | error: the reviews of the pull request could not be interpreted immediately before merging, so a change since verification cannot be ruled out; nothing was merged | No merge POST; destination Git ref unchanged. |
| final-head | 1 | error: https://bitbucket.org/fm-lab/final-head/pull-requests/7 changed after verification (state OPEN, head 7a66e5f242dec9daf30a63ca203ad80a1e3edf1e, verified head 661b18595b3d8f30ce1201fcf71c9090d18af683); nothing was merged | No merge POST; destination Git ref unchanged. |
| final-closed | 1 | error: https://bitbucket.org/fm-lab/final-closed/pull-requests/7 changed after verification (state DECLINED, head a6b8a6e4ad8ff66a93c842a4b6d8605b4f2ccba4, verified head a6b8a6e4ad8ff66a93c842a4b6d8605b4f2ccba4); nothing was merged | No merge POST; destination Git ref unchanged. |
| final-nickname-withdrawn | 1 | error: the reviews of https://bitbucket.org/fm-lab/final-nickname-withdrawn/pull-requests/7 changed after verification (approval withdrawn by alice); nothing was merged | No merge POST; destination Git ref unchanged. |
| final-reordered-reviews | 0 | `{"type":"pullrequest","close_source_branch":false,"merge_strategy":"squash"}` | Destination contains feature; merged state read back. |
| draft-lookup-503 | 1 | error: https://bitbucket.org/fm-lab/draft-lookup-503/pull-requests/7 is a draft pull request; a draft cannot be merged, so merge monitoring would wait for an event that cannot occur - mark it ready for review and arm again, or declare a wait instead of done if the draft is deliberate | No pr= or poll published. |
| draft-lookup-404 | 1 | error: https://bitbucket.org/fm-lab/draft-lookup-404/pull-requests/7 is a draft pull request; a draft cannot be merged, so merge monitoring would wait for an event that cannot occur - mark it ready for review and arm again, or declare a wait instead of done if the draft is deliberate | No pr= or poll published. |
| draft-lookup-malformed | 1 | error: https://bitbucket.org/fm-lab/draft-lookup-malformed/pull-requests/7 is a draft pull request; a draft cannot be merged, so merge monitoring would wait for an event that cannot occur - mark it ready for review and arm again, or declare a wait instead of done if the draft is deliberate | No pr= or poll published. |
| ready-lookup-503 | 0 | armed: state/task-x1.check.sh | PR watch registered without unresolved pr_head. |
| ready-lookup-malformed | 0 | armed: state/task-x1.check.sh | PR watch registered without unresolved pr_head. |

Final-drift cases changed only on the third full PR read, after recording and verification. Approval replacement preserved the approval count while replacing Alice with Carol. Participant reordering alone still merged. The slash destination was looked up as `q=name%20%3D%20%22release%2F2026.06%22`. Explicit strategy choices made no branch-default lookup.

## Before/after regression proof

| Base scenario (expected broken behavior) | Observed on base commit | Target behavior |
| --- | --- | --- |
| base-default-squash | Merge POST omitted merge_strategy. | Refused or sent explicit strategy as required. |
| base-default-unreadable | Merge POST accepted; destination changed despite unsafe state. | Refused or sent explicit strategy as required. |
| base-final-destination | Merge POST accepted; destination changed despite unsafe state. | Refused or sent explicit strategy as required. |
| base-final-withdrawn | Merge POST accepted; destination changed despite unsafe state. | Refused or sent explicit strategy as required. |
| base-final-changes | Merge POST accepted; destination changed despite unsafe state. | Refused or sent explicit strategy as required. |
| base-draft-lookup-503 | Draft PR watch armed with pr= despite commit HTTP 503. | Refused or sent explicit strategy as required. |

Base commit: `3ed72cc39094de5501b60d3ac269e2291127ca89`; target: `7df30a6a4a1657df225f4b21b5d63e6bea7207ed`. Base results marked fail in the detailed JSON/log are intentional reproductions, not failures of the current target.

## Other test-step checks and setup correction

`TMPDIR="$PWD/.bitbucket-test-tmp" bash tests/fm-pr-bitbucket.test.sh` passed. This targeted existing suite uses a curl stub and is supplemental regression evidence, not the live evidence above. No complete repository suite, linter, formatter or static analysis was run.

The initial disposable repos lacked published feature refs. Ready/non-draft PR checks therefore hit the independent named-head reachability guard. Added a disposable bare origin and fetched the feature ref within the workspace; reran every case successfully. This also let the base draft bug reproduce as an actually armed watch rather than just a missed draft diagnostic. No product code was changed.

All fixture repos, lab homes, certificates, base-script copies and the local proxy were torn down. The worktree is unchanged. This is a CLI-only change: CLI transcripts and API/persisted-state artifacts show the end-user surface; no visual UI exists to screenshot.

## Detailed artifacts

- `live-bitbucket-transcript.md`: full user-facing CLI output, request bodies, task metadata and destination history/tree.
- `live-bitbucket-api-requests.json`: ordered HTTP requests and responses, without authentication headers.
- `live-bitbucket-results.json`: commands and observable results.
- `live-bitbucket-driver.py`: disposable validation driver, preserved for reproducibility.
- `targeted-bitbucket-tests.log`: targeted existing regression suite output.
- `live-bitbucket-setup-attempt.*`: initial fixture publication failures, retained transparently.
