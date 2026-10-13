# PR CLI live validation

Target: `302bcb21bd5ee9249afd7b8e82fd7cb391b00404`.

## Scope and isolation

The actual `bin/fm-pr-check.sh`, `bin/fm-pr-state.sh`, generated poll scripts (run with `bash`, as their owner does), `bin/fm-pr-merge.sh`, and `bin/fm-review-diff.sh` ran from the target worktree. No Firstmate CLI, curl, jq, Git, or tea implementation was replaced. Ten scenarios passed in the final run.

A private Python HTTP/TLS service implemented disposable Bitbucket/Forgejo API records. Real curl used a loopback CONNECT proxy and a fixture certificate for the fixed `api.bitbucket.org` hostname; no DNS, host trust store, credential store, or global configuration was changed. Real tea 0.16.0 used a disposable login and private HOME. All credentials were synthetic. Each task used a marked lab home minted by `bin/fm-lab-home.sh create`, without a gate bypass or production path overrides. A private Git repository and local origin supplied actual commits, fetches, and destination/source tree checks. No Herdr, tmux, harness primary, operator fleet, hosted forge, or pipeline-control command was driven.

This validates the real product's CLI/HTTP/state behavior against disposable services, **not Atlassian's hosted API or a deployed Forgejo server**. The accepted Bitbucket race after the last read remains: the mismatch scenario deliberately demonstrates detection, not atomic prevention. The previously declined review decisions were not changed.

## Product evidence

- `live-pr-transcript.log`: actual CLI output, persisted task metadata, durable landed wake, Git tree comparison, and refusal messages.
- `live-pr-http.jsonl`: requests received by the private service, including methods, paths, merge JSON, and whether the disposable credential authenticated. Authorization headers are omitted.
- `live-pr-scenarios.json`: final scenario results.
- `live-pr-driver.py`: reproduction driver; supporting setup is described below.

Observable results include a full resolved `pr_head`, private armed poll, missing-environment-token refusal even with an ambient `.curlrc`, positive draft refusal, reported failed build/review, silent clean state, terminal state, exact merged-only polling, live-head review over stale metadata, warned recorded-head fallback, explicit squash with source retention, durable merge wake, build/approval/task refusals without a merge POST, moved/unreadable-final-head refusals without a merge POST, landed-head mismatch without a landed wake, and Forgejo's `head_commit_id` binding with a stale-head rejection.

No screenshot was captured: the changed end-user surfaces are command-line scripts and persisted state, not rendered UI.

## Targeted automated checks and earlier attempts

All test HOME/TMPDIR values were workspace-local.

Completed full affected behavior suites: `tests/fm-pr-bitbucket.test.sh`, `tests/fm-pr-state.test.sh`, `tests/fm-pr-reviewers.test.sh`, `tests/fm-review-diff.test.sh`, and `tests/fm-crew-state.test.sh`.

The initial affected-suite batch also attempted PR merge, PR check security, teardown, and captain-hold lifecycle. Nested fixture homes inside the source root caused teardown/captain-hold fixture refusals; the batch reached its 600-second bound before PR merge/security completed. A bounded retry using a workspace-local source copy reached ordinary teardown cases but timed out at 180 seconds. These are not claimed as complete green suites.

Relevant existing test functions were then executed from an unchanged workspace-local copy of `bin/`, `docs/`, and tests, with fixture homes in a sibling directory rather than underneath that copied code root. Only their top-level test invocation lists were replaced to select the relevant cases; assertions and implementation remained unchanged. All four selected runs completed successfully. `affected-test-selectors.json` records their exact functions, including Bitbucket teardown/retained-PR cases and Forgejo compatibility cases. No complete repository suite, linter, formatter, or static analyzer was run.

Initial live-driver assertions were corrected for the product's actual poll contract (mode 0600 and invocation via bash), the documented lookup-refusal exit code (2), and fixture Git reachability/pagination. The final full scenario run passed; no product source was modified.

## Reproduction setup

From the target worktree, make `.validation/tmp`, `.validation/tools`, `.validation/tls`, and `.validation/home`. Obtain the official workspace-local tea binary from `https://dl.gitea.com/tea/0.16.0/tea-0.16.0-linux-amd64` as `.validation/tools/tea`, then `chmod +x` it. Generate the fixture TLS certificate with:

```sh
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout .validation/tls/key.pem -out .validation/tls/cert.pem -days 1 \
  -subj '/CN=api.bitbucket.org' -addext 'subjectAltName=DNS:api.bitbucket.org'
```

Run the evidence driver's Python file from the worktree; it uses the designated evidence directory and cleans each lab home in its finalizer. Remove `.validation` after completion. The validation turn removed its own service, lab homes, source copy, local tool binary, certificate, Git fixtures, temporary test directories, and logs. No source/test changes remain.
