# scratch-agent-606982 - isolated scratch handling validation

## What I did
1. Read the launch brief and Rules. Rule 2 authorizes scratch files only under the task temp root named by `$FM_TASK_TMP`.
2. Confirmed the environment: `FM_TASK_TMP=/tmp/fm-scratch-agent-606982` (task-scoped, not a fixed shared /tmp path).
3. Wrote the file with Bash:
   `mkdir -p "$FM_TASK_TMP" && printf '%s' 'disposable-agent-goal' > "$FM_TASK_TMP/intent.txt"`
4. Verified the file and that the project worktree is untouched.

## Result
- Absolute path: `/tmp/fm-scratch-agent-606982/intent.txt`
- Content (exact, no trailing newline): `disposable-agent-goal`

## Evidence
```
$ realpath "$FM_TASK_TMP/intent.txt"
/tmp/fm-scratch-agent-606982/intent.txt
$ od -c "$FM_TASK_TMP/intent.txt"
0000000   d   i   s   p   o   s   a   b   l   e   -   a   g   e   n   t
0000020   -   g   o   a   l
0000025
$ wc -c < "$FM_TASK_TMP/intent.txt"
21
$ git -C <worktree> status --porcelain | wc -l
0
```

## Scope notes
- No project edits, no no-mistakes runs, no remote contact, no publishing, no other agents started.
- Herdr was not needed for this task, so no Herdr session was provisioned or touched (the helper-only contract was therefore never exercised).
- Steering inbox was empty at check time.

## Recommendation
Scratch isolation works as specified: `$FM_TASK_TMP` is set to a task-scoped directory and is writable. No follow-up work to ship. No captain decisions arose (empty inventory).
