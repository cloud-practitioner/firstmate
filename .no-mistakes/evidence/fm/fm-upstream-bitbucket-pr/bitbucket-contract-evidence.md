# Targeted Bitbucket contract evidence — mock-backed, not live

Target: `520324b48d396ebec2590763071cb48910a8f251`.

The recorded operator decision limits this turn to the Bitbucket, PR-merge, and PR-check security suites and prohibits live scenarios. No live forge, Herdr session, or operator fleet was used. The tests execute the repository's PR scripts, but curl/forge CLI responses are synthetic; these artifacts do **not** prove real Bitbucket service integration. Synthetic credentials only.

`tests/fm-pr-bitbucket.test.sh` and `tests/fm-pr-check-security.test.sh` completed successfully. The initial PR-merge run hit the test driver's 8-minute limit after steady progress; a standalone repeat of `tests/fm-pr-merge.test.sh` completed successfully under a 12-minute bound. No assertion failure occurred. Lint was not run because the Test phase explicitly forbids it. No full repository suite or other gate phase was run.

An EXIT wrapper copied generated CLI outputs, persisted metadata/poll/authority/wake contracts, merge request bodies, and lock-probe logs before the suites' original cleanup removed fixtures. Raw copies are linked below. No source or test files were modified. The previously untracked `.test-phase/` was removed; the worktree is clean.

For `bb/read-locks.log`, each row is the exit status of (1) the public away-record archive operation and (2) the public task-control lock acquisition during a post-acceptance read. Both `1 1` rows demonstrate refusal at both bounded attempts. The tests also assert successful reacquisition after read-back, success only for confirmed verified-head landings, and no landed marker/wake for unconfirmed cases. Missing-outcome assertions are test evidence, not reconstructed log lines.

The stderr excerpts below omit only fixture supervision-warning lines prefixed with `●`; raw files retain them. The fixture has no real watcher, and those warnings explicitly allow the guarded operation to proceed.

## Register a ready PR

[Raw check-arms/stdout](bitbucket-contracts/check-arms/stdout)

```text
armed: state/task-x1.check.sh
```

[Raw check-arms/state/task-x1.meta](bitbucket-contracts/check-arms/state/task-x1.meta)

```text
window=fm-task-x1
worktree=/home/node/.no-mistakes/evidence/01M4SKS0R6FEJG7GBWFDJ90AEN/fixture-scratch/fm-pr-bitbucket-tests.DcY0M1/check-arms/wt
project=/home/node/.no-mistakes/evidence/01M4SKS0R6FEJG7GBWFDJ90AEN/fixture-scratch/fm-pr-bitbucket-tests.DcY0M1/check-arms/project
kind=ship
mode=no-mistakes
pr=https://bitbucket.org/example-team/sample_repo/pull-requests/7
pr_head=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

[Raw check-arms/state/task-x1.pr-poll](bitbucket-contracts/check-arms/state/task-x1.pr-poll)

```text
bitbucket
https://bitbucket.org/example-team/sample_repo/pull-requests/7
bitbucket.org
example-team/sample_repo
7
```

## Draft is refused even with commit lookup returning 503

[Raw check-draft-lookup/stderr](bitbucket-contracts/check-draft-lookup/stderr)

```text
error: https://bitbucket.org/example-team/sample_repo/pull-requests/7 is a draft pull request; a draft cannot be merged, so merge monitoring would wait for an event that cannot occur - mark it ready for review and arm again, or declare a wait instead of done if the draft is deliberate
```

## Destination default squash is sent explicitly

[Raw merge-default-squash/bb/merge-body.json](bitbucket-contracts/merge-default-squash/bb/merge-body.json)

```text
{"type":"pullrequest","close_source_branch":false,"merge_strategy":"squash"}
```

[Raw merge-default-squash/stdout](bitbucket-contracts/merge-default-squash/stdout)

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/example-team/sample_repo/pull-requests/7 is merged at the verified head aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

## Unreadable, unknown, and missing defaults refuse

[Raw merge-default-unreadable/stderr](bitbucket-contracts/merge-default-unreadable/stderr)

```text
error: refusing to merge https://bitbucket.org/example-team/sample_repo/pull-requests/7
  - the configured default merge strategy of destination branch main could not be read (HTTP 500); name a strategy with --squash, --merge, --rebase, or --method, or fix the read
```

[Raw merge-default-unknown/stderr](bitbucket-contracts/merge-default-unknown/stderr)

```text
error: refusing to merge https://bitbucket.org/example-team/sample_repo/pull-requests/7
  - destination branch main reports no merge strategy this script knows as its default (got "octopus"); name a strategy with --squash, --merge, --rebase, or --method, or fix the read
```

[Raw merge-default-missing/stderr](bitbucket-contracts/merge-default-missing/stderr)

```text
error: refusing to merge https://bitbucket.org/example-team/sample_repo/pull-requests/7
  - destination branch main reports no merge strategy this script knows as its default (got ""); name a strategy with --squash, --merge, --rebase, or --method, or fix the read
```

## Retarget, approval withdrawal, and new changes-requested verdict refuse

[Raw merge-drift-dest/stderr](bitbucket-contracts/merge-drift-dest/stderr)

```text
verified: https://bitbucket.org/example-team/sample_repo/pull-requests/7 is open, with every unwaived build green and every verified merge check met at head aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
error: https://bitbucket.org/example-team/sample_repo/pull-requests/7 now targets release, not the verified destination branch main, so its merge checks were never read; nothing was merged
```

[Raw merge-drift-withdrawn/stderr](bitbucket-contracts/merge-drift-withdrawn/stderr)

```text
verified: https://bitbucket.org/example-team/sample_repo/pull-requests/7 is open, with every unwaived build green and every verified merge check met at head aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
error: the reviews of https://bitbucket.org/example-team/sample_repo/pull-requests/7 changed after verification (approval withdrawn by {alice}); nothing was merged
```

[Raw merge-drift-changes/stderr](bitbucket-contracts/merge-drift-changes/stderr)

```text
verified: https://bitbucket.org/example-team/sample_repo/pull-requests/7 is open, with every unwaived build green and every verified merge check met at head aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
error: the reviews of https://bitbucket.org/example-team/sample_repo/pull-requests/7 changed after verification (changes requested by {bob}); nothing was merged
```

## Changed head refuses before merge; wrong landed head is not recorded

[Raw merge-moved/stderr](bitbucket-contracts/merge-moved/stderr)

```text
verified: https://bitbucket.org/example-team/sample_repo/pull-requests/7 is open, with every unwaived build green and every verified merge check met at head aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
error: https://bitbucket.org/example-team/sample_repo/pull-requests/7 changed after verification (state OPEN, head bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb, verified head aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa); nothing was merged
```

[Raw merge-wrong-head/stderr](bitbucket-contracts/merge-wrong-head/stderr)

```text
verified: https://bitbucket.org/example-team/sample_repo/pull-requests/7 is open, with every unwaived build green and every verified merge check met at head aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
error: https://bitbucket.org/example-team/sample_repo/pull-requests/7 merged, but it reads back at head bbbbbbbbbbbb, not the verified head aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; the landed commits were never verified, so no landed outcome is recorded - review what landed in the destination branch
```

## Away async HTTP 202 confirms on the final read

[Raw merge-away-async-202-landed/stdout](bitbucket-contracts/merge-away-async-202-landed/stdout)

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/example-team/sample_repo/pull-requests/7 is merged at the verified head aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

[Raw merge-away-async-202-landed/bb/read-locks.log](bitbucket-contracts/merge-away-async-202-landed/bb/read-locks.log)

```text
1 1
1 1
```

[Raw merge-away-async-202-landed/state/.wake-queue](bitbucket-contracts/merge-away-async-202-landed/state/.wake-queue)

```text
1791863241	1	check	merged-task-x1-https://bitbucket.org/example-team/sample_repo/pull-requests/7	check: merge landed: task-x1 https://bitbucket.org/example-team/sample_repo/pull-requests/7 away
```

## Away async HTTP 202 remains unconfirmed and refuses

[Raw merge-away-async-202-unconfirmed/stderr](bitbucket-contracts/merge-away-async-202-unconfirmed/stderr)

```text
verified: https://bitbucket.org/example-team/sample_repo/pull-requests/7 is open, with every unwaived build green and every verified merge check met at head aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
actionable: Bitbucket accepted the merge request for https://bitbucket.org/example-team/sample_repo/pull-requests/7 but its landed state could not be confirmed; the merge poll remains armed
error: Bitbucket landing unconfirmed while away for https://bitbucket.org/example-team/sample_repo/pull-requests/7; no landed outcome is recorded; the merge poll remains armed
```

[Raw merge-away-async-202-unconfirmed/bb/read-locks.log](bitbucket-contracts/merge-away-async-202-unconfirmed/bb/read-locks.log)

```text
1 1
1 1
```

## Away async HTTP 555 follows the same contract

[Raw merge-away-async-555-landed/stdout](bitbucket-contracts/merge-away-async-555-landed/stdout)

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/example-team/sample_repo/pull-requests/7 is merged at the verified head aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

[Raw merge-away-async-555-landed/bb/read-locks.log](bitbucket-contracts/merge-away-async-555-landed/bb/read-locks.log)

```text
1 1
1 1
```

[Raw merge-away-async-555-unconfirmed/stderr](bitbucket-contracts/merge-away-async-555-unconfirmed/stderr)

```text
verified: https://bitbucket.org/example-team/sample_repo/pull-requests/7 is open, with every unwaived build green and every verified merge check met at head aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
actionable: Bitbucket accepted the merge request for https://bitbucket.org/example-team/sample_repo/pull-requests/7 but its landed state could not be confirmed; the merge poll remains armed
error: Bitbucket landing unconfirmed while away for https://bitbucket.org/example-team/sample_repo/pull-requests/7; no landed outcome is recorded; the merge poll remains armed
```

[Raw merge-away-async-555-unconfirmed/bb/read-locks.log](bitbucket-contracts/merge-away-async-555-unconfirmed/bb/read-locks.log)

```text
1 1
1 1
```

## Attended async landing may remain pending with poll armed

[Raw merge-unconfirmed/stderr](bitbucket-contracts/merge-unconfirmed/stderr)

```text
verified: https://bitbucket.org/example-team/sample_repo/pull-requests/7 is open, with every unwaived build green and every verified merge check met at head aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
actionable: Bitbucket accepted the merge request for https://bitbucket.org/example-team/sample_repo/pull-requests/7 but its landed state could not be confirmed; the merge poll remains armed
```
