## https://bitbucket.org/ws/bb-proj.git
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/live-bb-0
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
This project's origin is Bitbucket Cloud, which `gh-axi` cannot reach, so you open and check the PR with firstmate's helper, `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh`.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch with `git push -u origin fm/live-bb-0`, then run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh open` from this copy, which opens a PR that is ready for review, not a draft, using the repository's default destination and your HEAD commit's subject and body, and prints its https URL (it reuses a PR already open from your origin repository and branch rather than creating a second one).
The helper works only on this copy, its Bitbucket origin, and its current branch; it refuses a missing or non-Bitbucket origin and a detached HEAD.
Before you report done, read the PR back from Bitbucket with `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh verify <pr-url>` using the URL that open returned: it must exit 0 and print `draft: no`, which also confirms the PR is open, comes from your origin repository and current branch, and carries this copy's HEAD; if it reports a draft, run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh ready <pr-url>`, and if it reports a different head, push your latest commit and verify again.
The helper takes its credential from the NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN environment variables and never prints them; never print, echo, or write either one anywhere yourself, and if the helper names one as missing, append `blocked [at=<epoch>]: {the missing variable}` and stop.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.

## Promoted https://bitbucket.org/ws/bb-proj.git
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/live-promote-0
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
This project's origin is Bitbucket Cloud, which `gh-axi` cannot reach, so you open and check the PR with firstmate's helper, `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh`.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch with `git push -u origin fm/live-promote-0`, then run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh open` from this copy, which opens a PR that is ready for review, not a draft, using the repository's default destination and your HEAD commit's subject and body, and prints its https URL (it reuses a PR already open from your origin repository and branch rather than creating a second one).
The helper works only on this copy, its Bitbucket origin, and its current branch; it refuses a missing or non-Bitbucket origin and a detached HEAD.
Before you report done, read the PR back from Bitbucket with `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh verify <pr-url>` using the URL that open returned: it must exit 0 and print `draft: no`, which also confirms the PR is open, comes from your origin repository and current branch, and carries this copy's HEAD; if it reports a draft, run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh ready <pr-url>`, and if it reports a different head, push your latest commit and verify again.
The helper takes its credential from the NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN environment variables and never prints them; never print, echo, or write either one anywhere yourself, and if the helper names one as missing, append `blocked [at=<epoch>]: {the missing variable}` and stop.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.

### Persisted task record
```
project=/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/live-lab-home/projects/bb-proj
worktree=/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/live-lab-home/projects/bb-proj
window=fm-live-promote-0
kind=ship
mode=direct-PR
yolo=off
branch=fm/live-promote-0
```

## git@bitbucket.org:ws/bb-proj.git
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/live-bb-1
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
This project's origin is Bitbucket Cloud, which `gh-axi` cannot reach, so you open and check the PR with firstmate's helper, `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh`.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch with `git push -u origin fm/live-bb-1`, then run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh open` from this copy, which opens a PR that is ready for review, not a draft, using the repository's default destination and your HEAD commit's subject and body, and prints its https URL (it reuses a PR already open from your origin repository and branch rather than creating a second one).
The helper works only on this copy, its Bitbucket origin, and its current branch; it refuses a missing or non-Bitbucket origin and a detached HEAD.
Before you report done, read the PR back from Bitbucket with `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh verify <pr-url>` using the URL that open returned: it must exit 0 and print `draft: no`, which also confirms the PR is open, comes from your origin repository and current branch, and carries this copy's HEAD; if it reports a draft, run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh ready <pr-url>`, and if it reports a different head, push your latest commit and verify again.
The helper takes its credential from the NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN environment variables and never prints them; never print, echo, or write either one anywhere yourself, and if the helper names one as missing, append `blocked [at=<epoch>]: {the missing variable}` and stop.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.

## Promoted git@bitbucket.org:ws/bb-proj.git
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/live-promote-1
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
This project's origin is Bitbucket Cloud, which `gh-axi` cannot reach, so you open and check the PR with firstmate's helper, `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh`.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch with `git push -u origin fm/live-promote-1`, then run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh open` from this copy, which opens a PR that is ready for review, not a draft, using the repository's default destination and your HEAD commit's subject and body, and prints its https URL (it reuses a PR already open from your origin repository and branch rather than creating a second one).
The helper works only on this copy, its Bitbucket origin, and its current branch; it refuses a missing or non-Bitbucket origin and a detached HEAD.
Before you report done, read the PR back from Bitbucket with `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh verify <pr-url>` using the URL that open returned: it must exit 0 and print `draft: no`, which also confirms the PR is open, comes from your origin repository and current branch, and carries this copy's HEAD; if it reports a draft, run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh ready <pr-url>`, and if it reports a different head, push your latest commit and verify again.
The helper takes its credential from the NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN environment variables and never prints them; never print, echo, or write either one anywhere yourself, and if the helper names one as missing, append `blocked [at=<epoch>]: {the missing variable}` and stop.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.

### Persisted task record
```
project=/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/live-lab-home/projects/bb-proj
worktree=/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/live-lab-home/projects/bb-proj
window=fm-live-promote-1
kind=ship
mode=direct-PR
yolo=off
branch=fm/live-promote-1
```

## ssh://git@bitbucket.org/ws/bb-proj.git
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/live-bb-2
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
This project's origin is Bitbucket Cloud, which `gh-axi` cannot reach, so you open and check the PR with firstmate's helper, `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh`.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch with `git push -u origin fm/live-bb-2`, then run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh open` from this copy, which opens a PR that is ready for review, not a draft, using the repository's default destination and your HEAD commit's subject and body, and prints its https URL (it reuses a PR already open from your origin repository and branch rather than creating a second one).
The helper works only on this copy, its Bitbucket origin, and its current branch; it refuses a missing or non-Bitbucket origin and a detached HEAD.
Before you report done, read the PR back from Bitbucket with `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh verify <pr-url>` using the URL that open returned: it must exit 0 and print `draft: no`, which also confirms the PR is open, comes from your origin repository and current branch, and carries this copy's HEAD; if it reports a draft, run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh ready <pr-url>`, and if it reports a different head, push your latest commit and verify again.
The helper takes its credential from the NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN environment variables and never prints them; never print, echo, or write either one anywhere yourself, and if the helper names one as missing, append `blocked [at=<epoch>]: {the missing variable}` and stop.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.

## Promoted ssh://git@bitbucket.org/ws/bb-proj.git
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/live-promote-2
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
This project's origin is Bitbucket Cloud, which `gh-axi` cannot reach, so you open and check the PR with firstmate's helper, `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh`.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch with `git push -u origin fm/live-promote-2`, then run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh open` from this copy, which opens a PR that is ready for review, not a draft, using the repository's default destination and your HEAD commit's subject and body, and prints its https URL (it reuses a PR already open from your origin repository and branch rather than creating a second one).
The helper works only on this copy, its Bitbucket origin, and its current branch; it refuses a missing or non-Bitbucket origin and a detached HEAD.
Before you report done, read the PR back from Bitbucket with `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh verify <pr-url>` using the URL that open returned: it must exit 0 and print `draft: no`, which also confirms the PR is open, comes from your origin repository and current branch, and carries this copy's HEAD; if it reports a draft, run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh ready <pr-url>`, and if it reports a different head, push your latest commit and verify again.
The helper takes its credential from the NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN environment variables and never prints them; never print, echo, or write either one anywhere yourself, and if the helper names one as missing, append `blocked [at=<epoch>]: {the missing variable}` and stop.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.

### Persisted task record
```
project=/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/live-lab-home/projects/bb-proj
worktree=/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/live-lab-home/projects/bb-proj
window=fm-live-promote-2
kind=ship
mode=direct-PR
yolo=off
branch=fm/live-promote-2
```

## ssh://git@bitbucket.org:22/ws/bb-proj.git
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/live-bb-3
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
This project's origin is Bitbucket Cloud, which `gh-axi` cannot reach, so you open and check the PR with firstmate's helper, `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh`.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch with `git push -u origin fm/live-bb-3`, then run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh open` from this copy, which opens a PR that is ready for review, not a draft, using the repository's default destination and your HEAD commit's subject and body, and prints its https URL (it reuses a PR already open from your origin repository and branch rather than creating a second one).
The helper works only on this copy, its Bitbucket origin, and its current branch; it refuses a missing or non-Bitbucket origin and a detached HEAD.
Before you report done, read the PR back from Bitbucket with `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh verify <pr-url>` using the URL that open returned: it must exit 0 and print `draft: no`, which also confirms the PR is open, comes from your origin repository and current branch, and carries this copy's HEAD; if it reports a draft, run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh ready <pr-url>`, and if it reports a different head, push your latest commit and verify again.
The helper takes its credential from the NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN environment variables and never prints them; never print, echo, or write either one anywhere yourself, and if the helper names one as missing, append `blocked [at=<epoch>]: {the missing variable}` and stop.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.

## Promoted ssh://git@bitbucket.org:22/ws/bb-proj.git
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/live-promote-3
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
This project's origin is Bitbucket Cloud, which `gh-axi` cannot reach, so you open and check the PR with firstmate's helper, `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh`.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch with `git push -u origin fm/live-promote-3`, then run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh open` from this copy, which opens a PR that is ready for review, not a draft, using the repository's default destination and your HEAD commit's subject and body, and prints its https URL (it reuses a PR already open from your origin repository and branch rather than creating a second one).
The helper works only on this copy, its Bitbucket origin, and its current branch; it refuses a missing or non-Bitbucket origin and a detached HEAD.
Before you report done, read the PR back from Bitbucket with `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh verify <pr-url>` using the URL that open returned: it must exit 0 and print `draft: no`, which also confirms the PR is open, comes from your origin repository and current branch, and carries this copy's HEAD; if it reports a draft, run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh ready <pr-url>`, and if it reports a different head, push your latest commit and verify again.
The helper takes its credential from the NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN environment variables and never prints them; never print, echo, or write either one anywhere yourself, and if the helper names one as missing, append `blocked [at=<epoch>]: {the missing variable}` and stop.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.

### Persisted task record
```
project=/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/live-lab-home/projects/bb-proj
worktree=/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/live-lab-home/projects/bb-proj
window=fm-live-promote-3
kind=ship
mode=direct-PR
yolo=off
branch=fm/live-promote-3
```

## ssh://git@altssh.bitbucket.org:443/ws/bb-proj.git
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/live-bb-4
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
This project's origin is Bitbucket Cloud, which `gh-axi` cannot reach, so you open and check the PR with firstmate's helper, `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh`.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch with `git push -u origin fm/live-bb-4`, then run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh open` from this copy, which opens a PR that is ready for review, not a draft, using the repository's default destination and your HEAD commit's subject and body, and prints its https URL (it reuses a PR already open from your origin repository and branch rather than creating a second one).
The helper works only on this copy, its Bitbucket origin, and its current branch; it refuses a missing or non-Bitbucket origin and a detached HEAD.
Before you report done, read the PR back from Bitbucket with `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh verify <pr-url>` using the URL that open returned: it must exit 0 and print `draft: no`, which also confirms the PR is open, comes from your origin repository and current branch, and carries this copy's HEAD; if it reports a draft, run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh ready <pr-url>`, and if it reports a different head, push your latest commit and verify again.
The helper takes its credential from the NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN environment variables and never prints them; never print, echo, or write either one anywhere yourself, and if the helper names one as missing, append `blocked [at=<epoch>]: {the missing variable}` and stop.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.

## Promoted ssh://git@altssh.bitbucket.org:443/ws/bb-proj.git
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/live-promote-4
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
This project's origin is Bitbucket Cloud, which `gh-axi` cannot reach, so you open and check the PR with firstmate's helper, `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh`.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch with `git push -u origin fm/live-promote-4`, then run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh open` from this copy, which opens a PR that is ready for review, not a draft, using the repository's default destination and your HEAD commit's subject and body, and prints its https URL (it reuses a PR already open from your origin repository and branch rather than creating a second one).
The helper works only on this copy, its Bitbucket origin, and its current branch; it refuses a missing or non-Bitbucket origin and a detached HEAD.
Before you report done, read the PR back from Bitbucket with `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh verify <pr-url>` using the URL that open returned: it must exit 0 and print `draft: no`, which also confirms the PR is open, comes from your origin repository and current branch, and carries this copy's HEAD; if it reports a draft, run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/first\ mate\'s\ files/bin/fm-pr-open.sh ready <pr-url>`, and if it reports a different head, push your latest commit and verify again.
The helper takes its credential from the NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN environment variables and never prints them; never print, echo, or write either one anywhere yourself, and if the helper names one as missing, append `blocked [at=<epoch>]: {the missing variable}` and stop.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.

### Persisted task record
```
project=/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/live-lab-home/projects/bb-proj
worktree=/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/.gate-test-tmp/live-lab-home/projects/bb-proj
window=fm-live-promote-4
kind=ship
mode=direct-PR
yolo=off
branch=fm/live-promote-4
```
