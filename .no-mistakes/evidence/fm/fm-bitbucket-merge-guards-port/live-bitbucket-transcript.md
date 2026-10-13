# Live Bitbucket CLI validation

The real public Firstmate shell scripts, real curl, real jq, real Git, and local TLS/HTTP transport were used. A disposable API fixture accepted only synthetic credentials and applied merges to disposable Git repositories. No shared Bitbucket service was accessed. Target expectations were intentionally also applied to the base commit to reproduce regressions.

## default-squash (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/default-squash/pull-requests/7`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/default-squash/pull-requests/7 is merged at the verified head 9a651a1215477d539e15135aac862a8b277c2e4a
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/default-squash/pull-requests/7 is open, with every unwaived build green and every merge check met at head 9a651a1215477d539e15135aac862a8b277c2e4a
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false,
    "merge_strategy": "squash"
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-squash/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-squash/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/default-squash/pull-requests/7",
  "pr_head": "9a651a1215477d539e15135aac862a8b277c2e4a"
}
```

Destination Git history:
```text
8077ba8 Squashed fixture PR 7
1b03d3b baseline
```

Destination tree:
```text
README.md
feature.txt
```

## default-merge-commit (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/default-merge-commit/pull-requests/7`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/default-merge-commit/pull-requests/7 is merged at the verified head 08373482822295f5ec84937e994bff54de9ef450
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/default-merge-commit/pull-requests/7 is open, with every unwaived build green and every merge check met at head 08373482822295f5ec84937e994bff54de9ef450
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false,
    "merge_strategy": "merge_commit"
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-merge-commit/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-merge-commit/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/default-merge-commit/pull-requests/7",
  "pr_head": "08373482822295f5ec84937e994bff54de9ef450"
}
```

Destination Git history:
```text
ba0ed03 Merged fixture PR 7
2158821 baseline
0837348 feature
```

Destination tree:
```text
README.md
feature.txt
```

## default-fast-forward (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/default-fast-forward/pull-requests/7`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/default-fast-forward/pull-requests/7 is merged at the verified head 9897626363a99911a5c15e6fa061ca63be53c53f
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/default-fast-forward/pull-requests/7 is open, with every unwaived build green and every merge check met at head 9897626363a99911a5c15e6fa061ca63be53c53f
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false,
    "merge_strategy": "fast_forward"
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-fast-forward/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-fast-forward/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/default-fast-forward/pull-requests/7",
  "pr_head": "9897626363a99911a5c15e6fa061ca63be53c53f"
}
```

Destination Git history:
```text
9897626 feature
960641a baseline
```

Destination tree:
```text
README.md
feature.txt
```

## default-squash-fast-forward (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/default-squash-fast-forward/pull-requests/7`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/default-squash-fast-forward/pull-requests/7 is merged at the verified head eb2cf829b1623fde08f8929930d09712148679e0
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/default-squash-fast-forward/pull-requests/7 is open, with every unwaived build green and every merge check met at head eb2cf829b1623fde08f8929930d09712148679e0
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false,
    "merge_strategy": "squash_fast_forward"
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-squash-fast-forward/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-squash-fast-forward/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/default-squash-fast-forward/pull-requests/7",
  "pr_head": "eb2cf829b1623fde08f8929930d09712148679e0"
}
```

Destination Git history:
```text
1c4b948 Squashed fixture PR 7
8948af8 baseline
```

Destination tree:
```text
README.md
feature.txt
```

## default-rebase-fast-forward (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/default-rebase-fast-forward/pull-requests/7`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/default-rebase-fast-forward/pull-requests/7 is merged at the verified head f84f6bca56c0431d2ca34185091d4836818078bb
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/default-rebase-fast-forward/pull-requests/7 is open, with every unwaived build green and every merge check met at head f84f6bca56c0431d2ca34185091d4836818078bb
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false,
    "merge_strategy": "rebase_fast_forward"
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-rebase-fast-forward/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-rebase-fast-forward/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/default-rebase-fast-forward/pull-requests/7",
  "pr_head": "f84f6bca56c0431d2ca34185091d4836818078bb"
}
```

Destination Git history:
```text
f84f6bc feature
3172d97 baseline
```

Destination tree:
```text
README.md
feature.txt
```

## default-rebase-merge (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/default-rebase-merge/pull-requests/7`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/default-rebase-merge/pull-requests/7 is merged at the verified head 6ec7e4f40c16d84af381fb393f4a72e780274f08
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/default-rebase-merge/pull-requests/7 is open, with every unwaived build green and every merge check met at head 6ec7e4f40c16d84af381fb393f4a72e780274f08
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false,
    "merge_strategy": "rebase_merge"
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-rebase-merge/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-rebase-merge/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/default-rebase-merge/pull-requests/7",
  "pr_head": "6ec7e4f40c16d84af381fb393f4a72e780274f08"
}
```

Destination Git history:
```text
8f260c5 Merged fixture PR 7
6b0c059 baseline
6ec7e4f feature
```

Destination tree:
```text
README.md
feature.txt
```

## slash-destination (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/slash-destination/pull-requests/7`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/slash-destination/pull-requests/7 is merged at the verified head 3a3be115a14ee747a4f30104edddeb9411b49f66
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/slash-destination/pull-requests/7 is open, with every unwaived build green and every merge check met at head 3a3be115a14ee747a4f30104edddeb9411b49f66
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false,
    "merge_strategy": "squash"
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/slash-destination/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/slash-destination/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/slash-destination/pull-requests/7",
  "pr_head": "3a3be115a14ee747a4f30104edddeb9411b49f66"
}
```

Destination Git history:
```text
92b1360 Squashed fixture PR 7
120bc77 baseline
```

Destination tree:
```text
README.md
feature.txt
```

## default-http500 (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/default-http500/pull-requests/7`

Exit: 1; full PR reads: 2; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
error: refusing to merge https://bitbucket.org/fm-lab/default-http500/pull-requests/7
  - the configured default merge strategy of destination branch main could not be read (HTTP 500); name a strategy with --squash, --merge, --rebase, or --method, or fix the read
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-http500/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-http500/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/default-http500/pull-requests/7",
  "pr_head": "460f249f6034784b310a55323e9a751bf0a80d8f"
}
```

Destination Git history:
```text
0f7ae8b baseline
```

Destination tree:
```text
README.md
```

## default-http403 (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/default-http403/pull-requests/7`

Exit: 1; full PR reads: 2; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
error: refusing to merge https://bitbucket.org/fm-lab/default-http403/pull-requests/7
  - the configured default merge strategy of destination branch main could not be read (HTTP 403); name a strategy with --squash, --merge, --rebase, or --method, or fix the read
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-http403/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-http403/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/default-http403/pull-requests/7",
  "pr_head": "b670d5a373be2864855d01781f870af560a2e47c"
}
```

Destination Git history:
```text
4ac39bd baseline
```

Destination tree:
```text
README.md
```

## default-unknown (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/default-unknown/pull-requests/7`

Exit: 1; full PR reads: 2; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
error: refusing to merge https://bitbucket.org/fm-lab/default-unknown/pull-requests/7
  - destination branch main reports no merge strategy this script knows as its default (got "octopus"); name a strategy with --squash, --merge, --rebase, or --method, or fix the read
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-unknown/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-unknown/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/default-unknown/pull-requests/7",
  "pr_head": "75d5f14bb76abba8db1ac417887b3f3d3a13ec0b"
}
```

Destination Git history:
```text
93b6256 baseline
```

Destination tree:
```text
README.md
```

## default-missing (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/default-missing/pull-requests/7`

Exit: 1; full PR reads: 2; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
error: refusing to merge https://bitbucket.org/fm-lab/default-missing/pull-requests/7
  - destination branch main reports no merge strategy this script knows as its default (got ""); name a strategy with --squash, --merge, --rebase, or --method, or fix the read
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-missing/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-missing/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/default-missing/pull-requests/7",
  "pr_head": "6152a0171ff5bed321c650bd3f088f7cdf7f1854"
}
```

Destination Git history:
```text
faf7bea baseline
```

Destination tree:
```text
README.md
```

## default-wrong-branch (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/default-wrong-branch/pull-requests/7`

Exit: 1; full PR reads: 2; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
error: refusing to merge https://bitbucket.org/fm-lab/default-wrong-branch/pull-requests/7
  - destination branch main reports no merge strategy this script knows as its default (got ""); name a strategy with --squash, --merge, --rebase, or --method, or fix the read
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-wrong-branch/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-wrong-branch/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/default-wrong-branch/pull-requests/7",
  "pr_head": "7c435989cfb5e2d06373080c0e2e14ec13af228e"
}
```

Destination Git history:
```text
c9b6b2d baseline
```

Destination tree:
```text
README.md
```

## default-malformed (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/default-malformed/pull-requests/7`

Exit: 1; full PR reads: 2; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
error: refusing to merge https://bitbucket.org/fm-lab/default-malformed/pull-requests/7
  - the configured default merge strategy of destination branch main could not be read (HTTP 200); name a strategy with --squash, --merge, --rebase, or --method, or fix the read
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-malformed/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/default-malformed/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/default-malformed/pull-requests/7",
  "pr_head": "faeeea179ee8ea10f0afa1960a5cc791e4a36817"
}
```

Destination Git history:
```text
9099f20 baseline
```

Destination tree:
```text
README.md
```

## explicit-squash (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/explicit-squash/pull-requests/7 -- --squash`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/explicit-squash/pull-requests/7 is merged at the verified head 59c433cefc5a4d3c1c16fb2ac048dba6647ad674
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/explicit-squash/pull-requests/7 is open, with every unwaived build green and every merge check met at head 59c433cefc5a4d3c1c16fb2ac048dba6647ad674
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false,
    "merge_strategy": "squash"
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/explicit-squash/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/explicit-squash/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/explicit-squash/pull-requests/7",
  "pr_head": "59c433cefc5a4d3c1c16fb2ac048dba6647ad674"
}
```

Destination Git history:
```text
2133400 Squashed fixture PR 7
d51dd58 baseline
```

Destination tree:
```text
README.md
feature.txt
```

## explicit-merge (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/explicit-merge/pull-requests/7 -- --merge`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/explicit-merge/pull-requests/7 is merged at the verified head 5864e865d183cd1d3ddc389eb84e4e86fe0cddae
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/explicit-merge/pull-requests/7 is open, with every unwaived build green and every merge check met at head 5864e865d183cd1d3ddc389eb84e4e86fe0cddae
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false,
    "merge_strategy": "merge_commit"
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/explicit-merge/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/explicit-merge/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/explicit-merge/pull-requests/7",
  "pr_head": "5864e865d183cd1d3ddc389eb84e4e86fe0cddae"
}
```

Destination Git history:
```text
5cf8391 Merged fixture PR 7
dd8dd94 baseline
5864e86 feature
```

Destination tree:
```text
README.md
feature.txt
```

## explicit-rebase (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/explicit-rebase/pull-requests/7 -- --rebase`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/explicit-rebase/pull-requests/7 is merged at the verified head d2ef8978d71f7ae7104e0b4af97cb19ed1232106
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/explicit-rebase/pull-requests/7 is open, with every unwaived build green and every merge check met at head d2ef8978d71f7ae7104e0b4af97cb19ed1232106
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false,
    "merge_strategy": "rebase_fast_forward"
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/explicit-rebase/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/explicit-rebase/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/explicit-rebase/pull-requests/7",
  "pr_head": "d2ef8978d71f7ae7104e0b4af97cb19ed1232106"
}
```

Destination Git history:
```text
d2ef897 feature
1e2b83c baseline
```

Destination tree:
```text
README.md
feature.txt
```

## explicit-method (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/explicit-method/pull-requests/7 -- --method rebase_merge`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/explicit-method/pull-requests/7 is merged at the verified head e9ebe8bf21487b0f1deb5f009086eb91eefba0e6
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/explicit-method/pull-requests/7 is open, with every unwaived build green and every merge check met at head e9ebe8bf21487b0f1deb5f009086eb91eefba0e6
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false,
    "merge_strategy": "rebase_merge"
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/explicit-method/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/explicit-method/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/explicit-method/pull-requests/7",
  "pr_head": "e9ebe8bf21487b0f1deb5f009086eb91eefba0e6"
}
```

Destination Git history:
```text
3030a3b Merged fixture PR 7
cfcc23a baseline
e9ebe8b feature
```

Destination tree:
```text
README.md
feature.txt
```

## final-destination (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/final-destination/pull-requests/7`

Exit: 1; full PR reads: 3; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/final-destination/pull-requests/7 is open, with every unwaived build green and every merge check met at head 55c3535746d10cf7ca11638a90e10d4fa60ffbb6
error: https://bitbucket.org/fm-lab/final-destination/pull-requests/7 now targets release, not the verified destination branch main, so its merge checks were never read; nothing was merged
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-destination/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-destination/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/final-destination/pull-requests/7",
  "pr_head": "55c3535746d10cf7ca11638a90e10d4fa60ffbb6"
}
```

Destination Git history:
```text
5661315 baseline
```

Destination tree:
```text
README.md
```

## final-withdrawn (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/final-withdrawn/pull-requests/7`

Exit: 1; full PR reads: 3; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/final-withdrawn/pull-requests/7 is open, with every unwaived build green and every merge check met at head 0d23b60934ad58b6ab97e21145a03be63d1a3002
error: the reviews of https://bitbucket.org/fm-lab/final-withdrawn/pull-requests/7 changed after verification (approval withdrawn by {alice}); nothing was merged
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-withdrawn/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-withdrawn/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/final-withdrawn/pull-requests/7",
  "pr_head": "0d23b60934ad58b6ab97e21145a03be63d1a3002"
}
```

Destination Git history:
```text
4cfe80a baseline
```

Destination tree:
```text
README.md
```

## final-replacement (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/final-replacement/pull-requests/7`

Exit: 1; full PR reads: 3; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/final-replacement/pull-requests/7 is open, with every unwaived build green and every merge check met at head fc3eaa8ccac3952816f5ad8b370da98d4559eb8b
error: the reviews of https://bitbucket.org/fm-lab/final-replacement/pull-requests/7 changed after verification (approval withdrawn by {alice}); nothing was merged
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-replacement/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-replacement/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/final-replacement/pull-requests/7",
  "pr_head": "fc3eaa8ccac3952816f5ad8b370da98d4559eb8b"
}
```

Destination Git history:
```text
4557421 baseline
```

Destination tree:
```text
README.md
```

## final-changes (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/final-changes/pull-requests/7`

Exit: 1; full PR reads: 3; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/final-changes/pull-requests/7 is open, with every unwaived build green and every merge check met at head d8446e697c68ad4d7115cfcfefd5fb766ecc9e88
error: the reviews of https://bitbucket.org/fm-lab/final-changes/pull-requests/7 changed after verification (changes requested by {carol}); nothing was merged
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-changes/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-changes/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/final-changes/pull-requests/7",
  "pr_head": "d8446e697c68ad4d7115cfcfefd5fb766ecc9e88"
}
```

Destination Git history:
```text
c1aa785 baseline
```

Destination tree:
```text
README.md
```

## final-malformed (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/final-malformed/pull-requests/7`

Exit: 1; full PR reads: 3; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/final-malformed/pull-requests/7 is open, with every unwaived build green and every merge check met at head a8362fe4936d84311e7345a5db4d618e60a9b25c
error: the reviews of the pull request could not be interpreted immediately before merging, so a change since verification cannot be ruled out; nothing was merged
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-malformed/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-malformed/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/final-malformed/pull-requests/7",
  "pr_head": "a8362fe4936d84311e7345a5db4d618e60a9b25c"
}
```

Destination Git history:
```text
65274a0 baseline
```

Destination tree:
```text
README.md
```

## final-head (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/final-head/pull-requests/7`

Exit: 1; full PR reads: 3; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/final-head/pull-requests/7 is open, with every unwaived build green and every merge check met at head 661b18595b3d8f30ce1201fcf71c9090d18af683
error: https://bitbucket.org/fm-lab/final-head/pull-requests/7 changed after verification (state OPEN, head 7a66e5f242dec9daf30a63ca203ad80a1e3edf1e, verified head 661b18595b3d8f30ce1201fcf71c9090d18af683); nothing was merged
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-head/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-head/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/final-head/pull-requests/7",
  "pr_head": "661b18595b3d8f30ce1201fcf71c9090d18af683"
}
```

Destination Git history:
```text
6492349 baseline
```

Destination tree:
```text
README.md
```

## final-closed (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/final-closed/pull-requests/7`

Exit: 1; full PR reads: 3; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/final-closed/pull-requests/7 is open, with every unwaived build green and every merge check met at head a6b8a6e4ad8ff66a93c842a4b6d8605b4f2ccba4
error: https://bitbucket.org/fm-lab/final-closed/pull-requests/7 changed after verification (state DECLINED, head a6b8a6e4ad8ff66a93c842a4b6d8605b4f2ccba4, verified head a6b8a6e4ad8ff66a93c842a4b6d8605b4f2ccba4); nothing was merged
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-closed/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-closed/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/final-closed/pull-requests/7",
  "pr_head": "a6b8a6e4ad8ff66a93c842a4b6d8605b4f2ccba4"
}
```

Destination Git history:
```text
32d6e85 baseline
```

Destination tree:
```text
README.md
```

## final-nickname-withdrawn (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/final-nickname-withdrawn/pull-requests/7`

Exit: 1; full PR reads: 3; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/final-nickname-withdrawn/pull-requests/7 is open, with every unwaived build green and every merge check met at head 26932e5a3020bcab84e3db0c7f87df537d5ccd08
error: the reviews of https://bitbucket.org/fm-lab/final-nickname-withdrawn/pull-requests/7 changed after verification (approval withdrawn by alice); nothing was merged
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-nickname-withdrawn/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-nickname-withdrawn/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/final-nickname-withdrawn/pull-requests/7",
  "pr_head": "26932e5a3020bcab84e3db0c7f87df537d5ccd08"
}
```

Destination Git history:
```text
82338b8 baseline
```

Destination tree:
```text
README.md
```

## final-reordered-reviews (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/final-reordered-reviews/pull-requests/7`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/final-reordered-reviews/pull-requests/7 is merged at the verified head df8f5bc80789f7531f9c7bf6557d4dc71fd88097
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/final-reordered-reviews/pull-requests/7 is open, with every unwaived build green and every merge check met at head df8f5bc80789f7531f9c7bf6557d4dc71fd88097
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false,
    "merge_strategy": "squash"
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-reordered-reviews/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/final-reordered-reviews/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/final-reordered-reviews/pull-requests/7",
  "pr_head": "df8f5bc80789f7531f9c7bf6557d4dc71fd88097"
}
```

Destination Git history:
```text
8d4d36d Squashed fixture PR 7
0509ca6 baseline
```

Destination tree:
```text
README.md
feature.txt
```

## draft-lookup-503 (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-check.sh task-x1 https://bitbucket.org/fm-lab/draft-lookup-503/pull-requests/7`

Exit: 1; full PR reads: 1; merge POSTs: 0; poll armed: False.

```text
error: https://bitbucket.org/fm-lab/draft-lookup-503/pull-requests/7 is a draft pull request; a draft cannot be merged, so merge monitoring would wait for an event that cannot occur - mark it ready for review and arm again, or declare a wait instead of done if the draft is deliberate
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/draft-lookup-503/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/draft-lookup-503/repo",
  "kind": "ship",
  "mode": "no-mistakes"
}
```

Destination Git history:
```text
532eb39 baseline
```

Destination tree:
```text
README.md
```

## draft-lookup-404 (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-check.sh task-x1 https://bitbucket.org/fm-lab/draft-lookup-404/pull-requests/7`

Exit: 1; full PR reads: 1; merge POSTs: 0; poll armed: False.

```text
error: https://bitbucket.org/fm-lab/draft-lookup-404/pull-requests/7 is a draft pull request; a draft cannot be merged, so merge monitoring would wait for an event that cannot occur - mark it ready for review and arm again, or declare a wait instead of done if the draft is deliberate
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/draft-lookup-404/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/draft-lookup-404/repo",
  "kind": "ship",
  "mode": "no-mistakes"
}
```

Destination Git history:
```text
532eb39 baseline
```

Destination tree:
```text
README.md
```

## draft-lookup-malformed (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-check.sh task-x1 https://bitbucket.org/fm-lab/draft-lookup-malformed/pull-requests/7`

Exit: 1; full PR reads: 1; merge POSTs: 0; poll armed: False.

```text
error: https://bitbucket.org/fm-lab/draft-lookup-malformed/pull-requests/7 is a draft pull request; a draft cannot be merged, so merge monitoring would wait for an event that cannot occur - mark it ready for review and arm again, or declare a wait instead of done if the draft is deliberate
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/draft-lookup-malformed/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/draft-lookup-malformed/repo",
  "kind": "ship",
  "mode": "no-mistakes"
}
```

Destination Git history:
```text
bf23af7 baseline
```

Destination tree:
```text
README.md
```

## ready-lookup-503 (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-check.sh task-x1 https://bitbucket.org/fm-lab/ready-lookup-503/pull-requests/7`

Exit: 0; full PR reads: 1; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/ready-lookup-503/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/ready-lookup-503/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/ready-lookup-503/pull-requests/7"
}
```

Destination Git history:
```text
bf23af7 baseline
```

Destination tree:
```text
README.md
```

## ready-lookup-malformed (target)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/bin/fm-pr-check.sh task-x1 https://bitbucket.org/fm-lab/ready-lookup-malformed/pull-requests/7`

Exit: 0; full PR reads: 1; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/ready-lookup-malformed/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/ready-lookup-malformed/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/ready-lookup-malformed/pull-requests/7"
}
```

Destination Git history:
```text
659c865 baseline
```

Destination tree:
```text
README.md
```

## base-default-squash (base)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/base-default-squash/pull-requests/7`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/base-default-squash/pull-requests/7 is merged at the verified head 6deca35080b9b5aaaf358e8bc75b2f98099f5702
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/base-default-squash/pull-requests/7 is open, with every unwaived build green and every merge check met at head 6deca35080b9b5aaaf358e8bc75b2f98099f5702
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base-default-squash/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base-default-squash/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/base-default-squash/pull-requests/7",
  "pr_head": "6deca35080b9b5aaaf358e8bc75b2f98099f5702"
}
```

Destination Git history:
```text
c856ec2 Merged fixture PR 7
e0d77b9 baseline
6deca35 feature
```

Destination tree:
```text
README.md
feature.txt
```

## base-default-unreadable (base)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/base-default-unreadable/pull-requests/7`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/base-default-unreadable/pull-requests/7 is merged at the verified head 4d2c5bffde94836d34f73f6fb617f388a918252e
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/base-default-unreadable/pull-requests/7 is open, with every unwaived build green and every merge check met at head 4d2c5bffde94836d34f73f6fb617f388a918252e
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base-default-unreadable/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base-default-unreadable/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/base-default-unreadable/pull-requests/7",
  "pr_head": "4d2c5bffde94836d34f73f6fb617f388a918252e"
}
```

Destination Git history:
```text
7fa77d7 Merged fixture PR 7
542a031 baseline
4d2c5bf feature
```

Destination tree:
```text
README.md
feature.txt
```

## base-final-destination (base)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/base-final-destination/pull-requests/7`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/base-final-destination/pull-requests/7 is merged at the verified head 1b05391b749349bcf996c78f56e54ed437eeda0a
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/base-final-destination/pull-requests/7 is open, with every unwaived build green and every merge check met at head 1b05391b749349bcf996c78f56e54ed437eeda0a
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base-final-destination/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base-final-destination/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/base-final-destination/pull-requests/7",
  "pr_head": "1b05391b749349bcf996c78f56e54ed437eeda0a"
}
```

Destination Git history:
```text
ffb2f86 Merged fixture PR 7
5c84a75 baseline
1b05391 feature
```

Destination tree:
```text
README.md
feature.txt
```

## base-final-withdrawn (base)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/base-final-withdrawn/pull-requests/7`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/base-final-withdrawn/pull-requests/7 is merged at the verified head c2b0ff9b592d0310fc2cae4a69115ae8ec7dfe29
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/base-final-withdrawn/pull-requests/7 is open, with every unwaived build green and every merge check met at head c2b0ff9b592d0310fc2cae4a69115ae8ec7dfe29
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base-final-withdrawn/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base-final-withdrawn/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/base-final-withdrawn/pull-requests/7",
  "pr_head": "c2b0ff9b592d0310fc2cae4a69115ae8ec7dfe29"
}
```

Destination Git history:
```text
7ee5113 Merged fixture PR 7
dbe5e37 baseline
c2b0ff9 feature
```

Destination tree:
```text
README.md
feature.txt
```

## base-final-changes (base)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/base-final-changes/pull-requests/7`

Exit: 0; full PR reads: 4; merge POSTs: 1; poll armed: True.

```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/base-final-changes/pull-requests/7 is merged at the verified head 2854c9aeb80187c1ba6f51bc02934e3864d6384b
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/base-final-changes/pull-requests/7 is open, with every unwaived build green and every merge check met at head 2854c9aeb80187c1ba6f51bc02934e3864d6384b
```

Merge request body:
```json
[
  {
    "type": "pullrequest",
    "close_source_branch": false
  }
]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base-final-changes/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base-final-changes/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/base-final-changes/pull-requests/7",
  "pr_head": "2854c9aeb80187c1ba6f51bc02934e3864d6384b"
}
```

Destination Git history:
```text
b2557fb Merged fixture PR 7
04b18a8 baseline
2854c9a feature
```

Destination tree:
```text
README.md
feature.txt
```

## base-draft-lookup-503 (base)

Command: `/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/bin/fm-pr-check.sh task-x1 https://bitbucket.org/fm-lab/base-draft-lookup-503/pull-requests/7`

Exit: 0; full PR reads: 1; merge POSTs: 0; poll armed: True.

```text
armed: state/task-x1.check.sh
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Merge request body:
```json
[]
```

Persisted task metadata:
```json
{
  "window": "fm-task-x1",
  "worktree": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base-draft-lookup-503/repo",
  "project": "/home/node/.no-mistakes/worktrees/450411b3e67c/01M4SV111DPBMGY82J84GZ53QX/.bitbucket-test-tmp/live/base-draft-lookup-503/repo",
  "kind": "ship",
  "mode": "no-mistakes",
  "pr": "https://bitbucket.org/fm-lab/base-draft-lookup-503/pull-requests/7"
}
```

Destination Git history:
```text
b48e6f6 baseline
```

Destination tree:
```text
README.md
```

