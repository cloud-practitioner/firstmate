# Direct-PR validation scope

Validated target b9029225ff891c22df47132ea8db8ea45eeb6e87 against base 17a7b57015e3b3c8575d7e8775782e4b08b44869.

## Live product checks

The real shell scripts ran with real Git, Bash, jq, and curl on PATH. No fake executable, API, worker, login, or production credential was used in these checks. All fixtures were inside the run worktree; the disposable home was marked through `bin/fm-lab-home.sh create`. No Herdr or tmux lifecycle was involved.

- Scaffolded ship briefs and promoted isolated scout records for HTTPS, scp-style SSH, SSH without a port, SSH port 22, and alternative SSH port 443 origins. Captured the resulting worker delivery contracts and persisted promotion records.
- Invoked open/verify/ready with missing credentials; confirmed supported origins reach the missing-variable refusal rather than the wrong-forge refusal. A synthetic token supplied without an email did not reach output.
- Actively tried missing/non-Bitbucket origins, detached HEAD, an unrelated PR repository, a directory outside Git discovery, removed override flags, and URL-less verify/ready. Each was refused.
- Executed generated push/open/verify/ready snippets from a copied real installation whose path contains a space and an apostrophe. Pushed to a worktree-local bare remote using a literal `$USER` and apostrophe in the branch. Inspected the remote ref and HEAD; it was exactly the intended branch. The real helper commands reached the expected missing-credential guard.
- Generated GitHub direct-PR and Bitbucket no-mistakes contracts. Executed the base and current DoD renderers and confirmed unchanged GitHub, no-mistakes, local-only, and Gerrit contracts were byte-identical.

The manual fixture driver initially stopped twice on setup assertions, not product failures: its non-repository directory inherited the parent worktree's Git identity, and a chosen branch was an existing ref's descendant. Added a Git discovery ceiling for the first case and selected a nonconflicting quoted branch prefix for the second. Rebuilt the fixtures and reran all manual checks successfully, then repeated the successful run with clearer origin/context transcript labels.

## Targeted deterministic checks (not live Cloud proof)

Executed only the direct-PR/origin tests in `tests/fm-pr-bitbucket.test.sh`, the forge/draft/quoting tests in `tests/fm-dod-lib.test.sh`, and the mode/scaffold/forge tests in `tests/fm-brief.test.sh`. The selectors are recorded in the targeted test logs and reproducibility driver. No complete test suite, static analysis, lint, formatting, pipeline control, push phase, PR phase, or CI phase ran.

The API checks used the repository's existing curl stub. All selected checks passed for commit-derived creation metadata, non-draft payloads, default destination omission, reuse, draft repair, stale/closed/wrong-source refusals, fork-safe discovery, recovery after a missing creation ID, and credential handling. `fm-pr-bitbucket-product-output.md` records helper output and submitted payloads and explicitly identifies these as stubbed responses, not live Bitbucket evidence.

## Live Cloud authority blocker

A local Git repository and bare remote were built and driven successfully, but neither supplies Bitbucket Cloud pull-request records. The helper fixes its REST base to `https://api.bitbucket.org/2.0`, and the scoped product has no supported workspace-local Cloud server or sandbox endpoint. A local API imitation would remain a stub and would not establish live Cloud behavior. Bitbucket Data Center is a different product/API, not a local substitute for Cloud.

Environment variable presence was checked without reading or using either operator credential. Operator credentials are present, but this run has no authorization to read or mutate shared services or to create a disposable Cloud repository outside the worktree. No Cloud request was sent. Thus authenticated creation, live read-back, draft updates, fork discrimination, and authentication-error secrecy remain live-untested despite passing deterministic checks. Supply a disposable Bitbucket Cloud repository and test-only credentials with PR write access, and explicitly authorize mutations of that external sandbox, to close this evidence gap.

## Evidence and cleanup

Evidence is CLI transcripts, generated worker Markdown, and persisted local records; no rendered GUI or UI layout changed, so no screenshot was needed. `live-driver.py` and `targeted-driver.py` preserve the evidence-producing recipes (their transient `.gate-test-tmp` setup must be recreated before running). All disposable installations, repositories, homes, selector drivers, and scratch files were removed from the worktree after validation. No source or test changes remain.
