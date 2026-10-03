# Bitbucket branching-model merge validation

Unmodified real Firstmate CLI, real jq and curl, disposable stateful Bitbucket-compatible TLS API at loopback only; no cloud repository or real credentials accessed.

The base executable was copied into the disposable workspace; the current CLI and jq programs were not modified. The TLS proxy permits only api.bitbucket.org:443 and serves all data locally.

## baseline-feature-met — pass

Version: base 93d82355; destination: `feature/login`; minimum successful builds: 1; reported: 1.

CLI exit: 1; merge requests: 0; persisted API state: OPEN; merge outcome recorded: False.

Command:
```sh
/home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.validation-bitbucket/base/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/baseline-feature-met/pull-requests/7
```

CLI stdout:
```text
armed: state/task-x1.check.sh
```

CLI stderr:
```text
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
error: refusing to merge https://bitbucket.org/fm-lab/baseline-feature-met/pull-requests/7
  - the branch restrictions for base branch feature/login could not be interpreted, so an unmet merge check cannot be ruled out
```

HTTP activity:
```text
GET /2.0/repositories/fm-lab/baseline-feature-met/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/baseline-feature-met/commit/4f2e1307b0cf?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/baseline-feature-met/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/baseline-feature-met/commit/4f2e1307b0cf?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/baseline-feature-met/commit/4f2e1307b0cfadf8a6927fa4c930d207f1e6a188/statuses?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/baseline-feature-met/branch-restrictions?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/baseline-feature-met/effective-branching-model -> HTTP 200 
```

## feature-met — pass

Version: target 3fdcaa00; destination: `feature/login`; minimum successful builds: 1; reported: 1.

CLI exit: 0; merge requests: 1; persisted API state: MERGED; merge outcome recorded: True.

Command:
```sh
/home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/feature-met/pull-requests/7
```

CLI stdout:
```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/feature-met/pull-requests/7 is merged at the verified head 9581f186df270670ff2dba6d51674b0a462f8a86
```

CLI stderr:
```text
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/feature-met/pull-requests/7 is open, with every unwaived build green and every merge check met at head 9581f186df270670ff2dba6d51674b0a462f8a86
```

HTTP activity:
```text
GET /2.0/repositories/fm-lab/feature-met/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/feature-met/commit/9581f186df27?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/feature-met/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/feature-met/commit/9581f186df27?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/feature-met/commit/9581f186df270670ff2dba6d51674b0a462f8a86/statuses?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/feature-met/branch-restrictions?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/feature-met/effective-branching-model -> HTTP 200 
GET /2.0/repositories/fm-lab/feature-met/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/feature-met/commit/9581f186df27?fields=hash -> HTTP 200 
POST /2.0/repositories/fm-lab/feature-met/pullrequests/7/merge -> HTTP 200 MERGED
{"type": "pullrequest", "close_source_branch": false}
GET /2.0/repositories/fm-lab/feature-met/pullrequests/7 -> HTTP 200 MERGED
```

## feature-unmet — pass

Version: target 3fdcaa00; destination: `feature/login`; minimum successful builds: 2; reported: 1.

CLI exit: 1; merge requests: 0; persisted API state: OPEN; merge outcome recorded: False.

Command:
```sh
/home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/feature-unmet/pull-requests/7
```

CLI stdout:
```text
armed: state/task-x1.check.sh
```

CLI stderr:
```text
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
error: refusing to merge https://bitbucket.org/fm-lab/feature-unmet/pull-requests/7
  - base branch feature/login requires 2 successful builds, and 1 reported at head 2e09aff571ce32f8f29e15a33845a899626b3221
```

HTTP activity:
```text
GET /2.0/repositories/fm-lab/feature-unmet/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/feature-unmet/commit/2e09aff571ce?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/feature-unmet/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/feature-unmet/commit/2e09aff571ce?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/feature-unmet/commit/2e09aff571ce32f8f29e15a33845a899626b3221/statuses?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/feature-unmet/branch-restrictions?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/feature-unmet/effective-branching-model -> HTTP 200 
```

## other-branch — pass

Version: target 3fdcaa00; destination: `main`; minimum successful builds: 3; reported: 1.

CLI exit: 0; merge requests: 1; persisted API state: MERGED; merge outcome recorded: True.

Command:
```sh
/home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/other-branch/pull-requests/7
```

CLI stdout:
```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/other-branch/pull-requests/7 is merged at the verified head 7c65e2bdc587eeef4c6f192883f35abf1ac0b019
```

CLI stderr:
```text
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/other-branch/pull-requests/7 is open, with every unwaived build green and every merge check met at head 7c65e2bdc587eeef4c6f192883f35abf1ac0b019
```

HTTP activity:
```text
GET /2.0/repositories/fm-lab/other-branch/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/other-branch/commit/7c65e2bdc587?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/other-branch/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/other-branch/commit/7c65e2bdc587?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/other-branch/commit/7c65e2bdc587eeef4c6f192883f35abf1ac0b019/statuses?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/other-branch/branch-restrictions?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/other-branch/effective-branching-model -> HTTP 200 
GET /2.0/repositories/fm-lab/other-branch/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/other-branch/commit/7c65e2bdc587?fields=hash -> HTTP 200 
POST /2.0/repositories/fm-lab/other-branch/pullrequests/7/merge -> HTTP 200 MERGED
{"type": "pullrequest", "close_source_branch": false}
GET /2.0/repositories/fm-lab/other-branch/pullrequests/7 -> HTTP 200 MERGED
```

## near-prefix — pass

Version: target 3fdcaa00; destination: `features/login`; minimum successful builds: 3; reported: 1.

CLI exit: 0; merge requests: 1; persisted API state: MERGED; merge outcome recorded: True.

Command:
```sh
/home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/near-prefix/pull-requests/7
```

CLI stdout:
```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/near-prefix/pull-requests/7 is merged at the verified head ab1cbe9e1b42553c877bae9164f6f6696253a701
```

CLI stderr:
```text
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/near-prefix/pull-requests/7 is open, with every unwaived build green and every merge check met at head ab1cbe9e1b42553c877bae9164f6f6696253a701
```

HTTP activity:
```text
GET /2.0/repositories/fm-lab/near-prefix/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/near-prefix/commit/ab1cbe9e1b42?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/near-prefix/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/near-prefix/commit/ab1cbe9e1b42?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/near-prefix/commit/ab1cbe9e1b42553c877bae9164f6f6696253a701/statuses?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/near-prefix/branch-restrictions?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/near-prefix/effective-branching-model -> HTTP 200 
GET /2.0/repositories/fm-lab/near-prefix/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/near-prefix/commit/ab1cbe9e1b42?fields=hash -> HTTP 200 
POST /2.0/repositories/fm-lab/near-prefix/pullrequests/7/merge -> HTTP 200 MERGED
{"type": "pullrequest", "close_source_branch": false}
GET /2.0/repositories/fm-lab/near-prefix/pullrequests/7 -> HTTP 200 MERGED
```

## custom-prefix-met — pass

Version: target 3fdcaa00; destination: `topic/login`; minimum successful builds: 1; reported: 1.

CLI exit: 0; merge requests: 1; persisted API state: MERGED; merge outcome recorded: True.

Command:
```sh
/home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/custom-prefix-met/pull-requests/7
```

CLI stdout:
```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/custom-prefix-met/pull-requests/7 is merged at the verified head 5df35e34a641a8e0bf123acfc027e0917c685c20
```

CLI stderr:
```text
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/custom-prefix-met/pull-requests/7 is open, with every unwaived build green and every merge check met at head 5df35e34a641a8e0bf123acfc027e0917c685c20
```

HTTP activity:
```text
GET /2.0/repositories/fm-lab/custom-prefix-met/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/custom-prefix-met/commit/5df35e34a641?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/custom-prefix-met/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/custom-prefix-met/commit/5df35e34a641?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/custom-prefix-met/commit/5df35e34a641a8e0bf123acfc027e0917c685c20/statuses?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/custom-prefix-met/branch-restrictions?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/custom-prefix-met/effective-branching-model -> HTTP 200 
GET /2.0/repositories/fm-lab/custom-prefix-met/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/custom-prefix-met/commit/5df35e34a641?fields=hash -> HTTP 200 
POST /2.0/repositories/fm-lab/custom-prefix-met/pullrequests/7/merge -> HTTP 200 MERGED
{"type": "pullrequest", "close_source_branch": false}
GET /2.0/repositories/fm-lab/custom-prefix-met/pullrequests/7 -> HTTP 200 MERGED
```

## custom-prefix-unmet — pass

Version: target 3fdcaa00; destination: `topic/login`; minimum successful builds: 2; reported: 1.

CLI exit: 1; merge requests: 0; persisted API state: OPEN; merge outcome recorded: False.

Command:
```sh
/home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/custom-prefix-unmet/pull-requests/7
```

CLI stdout:
```text
armed: state/task-x1.check.sh
```

CLI stderr:
```text
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
error: refusing to merge https://bitbucket.org/fm-lab/custom-prefix-unmet/pull-requests/7
  - base branch topic/login requires 2 successful builds, and 1 reported at head 1bc707ddb1edac28edd9ea8182e3d54cc36cf0bd
```

HTTP activity:
```text
GET /2.0/repositories/fm-lab/custom-prefix-unmet/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/custom-prefix-unmet/commit/1bc707ddb1ed?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/custom-prefix-unmet/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/custom-prefix-unmet/commit/1bc707ddb1ed?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/custom-prefix-unmet/commit/1bc707ddb1edac28edd9ea8182e3d54cc36cf0bd/statuses?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/custom-prefix-unmet/branch-restrictions?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/custom-prefix-unmet/effective-branching-model -> HTTP 200 
```

## wrong-type — pass

Version: target 3fdcaa00; destination: `release/login`; minimum successful builds: 3; reported: 1.

CLI exit: 0; merge requests: 1; persisted API state: MERGED; merge outcome recorded: True.

Command:
```sh
/home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/wrong-type/pull-requests/7
```

CLI stdout:
```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/wrong-type/pull-requests/7 is merged at the verified head a9a4b42e18059697fdae9d3dd32346ecc9b734fb
```

CLI stderr:
```text
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/wrong-type/pull-requests/7 is open, with every unwaived build green and every merge check met at head a9a4b42e18059697fdae9d3dd32346ecc9b734fb
```

HTTP activity:
```text
GET /2.0/repositories/fm-lab/wrong-type/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/wrong-type/commit/a9a4b42e1805?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/wrong-type/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/wrong-type/commit/a9a4b42e1805?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/wrong-type/commit/a9a4b42e18059697fdae9d3dd32346ecc9b734fb/statuses?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/wrong-type/branch-restrictions?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/wrong-type/effective-branching-model -> HTTP 200 
GET /2.0/repositories/fm-lab/wrong-type/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/wrong-type/commit/a9a4b42e1805?fields=hash -> HTTP 200 
POST /2.0/repositories/fm-lab/wrong-type/pullrequests/7/merge -> HTTP 200 MERGED
{"type": "pullrequest", "close_source_branch": false}
GET /2.0/repositories/fm-lab/wrong-type/pullrequests/7 -> HTTP 200 MERGED
```

## development-unmet — pass

Version: target 3fdcaa00; destination: `main`; minimum successful builds: 2; reported: 1.

CLI exit: 1; merge requests: 0; persisted API state: OPEN; merge outcome recorded: False.

Command:
```sh
/home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/development-unmet/pull-requests/7
```

CLI stdout:
```text
armed: state/task-x1.check.sh
```

CLI stderr:
```text
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
error: refusing to merge https://bitbucket.org/fm-lab/development-unmet/pull-requests/7
  - base branch main requires 2 successful builds, and 1 reported at head 53b883f48b5a0716954be49ce4f5ffbe321d1842
```

HTTP activity:
```text
GET /2.0/repositories/fm-lab/development-unmet/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/development-unmet/commit/53b883f48b5a?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/development-unmet/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/development-unmet/commit/53b883f48b5a?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/development-unmet/commit/53b883f48b5a0716954be49ce4f5ffbe321d1842/statuses?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/development-unmet/branch-restrictions?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/development-unmet/effective-branching-model -> HTTP 200 
```

## production-met — pass

Version: target 3fdcaa00; destination: `production`; minimum successful builds: 1; reported: 1.

CLI exit: 0; merge requests: 1; persisted API state: MERGED; merge outcome recorded: True.

Command:
```sh
/home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/bin/fm-pr-merge.sh task-x1 https://bitbucket.org/fm-lab/production-met/pull-requests/7
```

CLI stdout:
```text
armed: state/task-x1.check.sh
verified: https://bitbucket.org/fm-lab/production-met/pull-requests/7 is merged at the verified head bc4de6b09d44f8d68d56e297664fdbc25cb093ee
```

CLI stderr:
```text
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no watcher has a fresh beacon (last beat: never, grace 300s).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-turnend-guard.ts -e /home/node/.no-mistakes/worktrees/450411b3e67c/01M40YXRAMDJ28ZJ78WK9ZGBSB/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
verified: https://bitbucket.org/fm-lab/production-met/pull-requests/7 is open, with every unwaived build green and every merge check met at head bc4de6b09d44f8d68d56e297664fdbc25cb093ee
```

HTTP activity:
```text
GET /2.0/repositories/fm-lab/production-met/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/production-met/commit/bc4de6b09d44?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/production-met/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/production-met/commit/bc4de6b09d44?fields=hash -> HTTP 200 
GET /2.0/repositories/fm-lab/production-met/commit/bc4de6b09d44f8d68d56e297664fdbc25cb093ee/statuses?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/production-met/branch-restrictions?pagelen=100 -> HTTP 200 
GET /2.0/repositories/fm-lab/production-met/effective-branching-model -> HTTP 200 
GET /2.0/repositories/fm-lab/production-met/pullrequests/7 -> HTTP 200 OPEN
GET /2.0/repositories/fm-lab/production-met/commit/bc4de6b09d44?fields=hash -> HTTP 200 
POST /2.0/repositories/fm-lab/production-met/pullrequests/7/merge -> HTTP 200 MERGED
{"type": "pullrequest", "close_source_branch": false}
GET /2.0/repositories/fm-lab/production-met/pullrequests/7 -> HTTP 200 MERGED
```

Loopback proxy stopped: True. All lab homes, Git fixtures, certificates and copied executables are removed after the checks.
