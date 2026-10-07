## pr-host-home/data/brief-prhost-bb1/brief.md
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/brief-prhost-bb1
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
This project's origin is Bitbucket Cloud, which `gh-axi` cannot reach, so you open and check the PR with firstmate's helper, `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh`.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch with `git push -u origin fm/brief-prhost-bb1`, then run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh open` from this copy, which opens a PR that is ready for review, not a draft, using the repository's default destination and your HEAD commit's subject and body, and prints its https URL (it reuses a PR already open from your origin repository and branch rather than creating a second one).
The helper works only on this copy, its Bitbucket origin, and its current branch; it refuses a missing or non-Bitbucket origin and a detached HEAD.
Before you report done, read the PR back from Bitbucket with `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh verify <pr-url>` using the URL that open returned: it must exit 0 and print `draft: no`, which also confirms the PR is open, comes from your origin repository and current branch, and carries this copy's HEAD; if it reports a draft, run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh ready <pr-url>`, and if it reports a different head, push your latest commit and verify again.
The helper takes its credential from the NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN environment variables and never prints them; never print, echo, or write either one anywhere yourself, and if the helper names one as missing, append `blocked [at=<epoch>]: {the missing variable}` and stop.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.


## pr-host-home/data/brief-prhost-bb2/brief.md
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/brief-prhost-bb2
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
This project's origin is Bitbucket Cloud, which `gh-axi` cannot reach, so you open and check the PR with firstmate's helper, `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh`.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch with `git push -u origin fm/brief-prhost-bb2`, then run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh open` from this copy, which opens a PR that is ready for review, not a draft, using the repository's default destination and your HEAD commit's subject and body, and prints its https URL (it reuses a PR already open from your origin repository and branch rather than creating a second one).
The helper works only on this copy, its Bitbucket origin, and its current branch; it refuses a missing or non-Bitbucket origin and a detached HEAD.
Before you report done, read the PR back from Bitbucket with `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh verify <pr-url>` using the URL that open returned: it must exit 0 and print `draft: no`, which also confirms the PR is open, comes from your origin repository and current branch, and carries this copy's HEAD; if it reports a draft, run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh ready <pr-url>`, and if it reports a different head, push your latest commit and verify again.
The helper takes its credential from the NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN environment variables and never prints them; never print, echo, or write either one anywhere yourself, and if the helper names one as missing, append `blocked [at=<epoch>]: {the missing variable}` and stop.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.


## pr-host-home/data/brief-prhost-bb3/brief.md
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/brief-prhost-bb3
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
This project's origin is Bitbucket Cloud, which `gh-axi` cannot reach, so you open and check the PR with firstmate's helper, `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh`.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch with `git push -u origin fm/brief-prhost-bb3`, then run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh open` from this copy, which opens a PR that is ready for review, not a draft, using the repository's default destination and your HEAD commit's subject and body, and prints its https URL (it reuses a PR already open from your origin repository and branch rather than creating a second one).
The helper works only on this copy, its Bitbucket origin, and its current branch; it refuses a missing or non-Bitbucket origin and a detached HEAD.
Before you report done, read the PR back from Bitbucket with `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh verify <pr-url>` using the URL that open returned: it must exit 0 and print `draft: no`, which also confirms the PR is open, comes from your origin repository and current branch, and carries this copy's HEAD; if it reports a draft, run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh ready <pr-url>`, and if it reports a different head, push your latest commit and verify again.
The helper takes its credential from the NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN environment variables and never prints them; never print, echo, or write either one anywhere yourself, and if the helper names one as missing, append `blocked [at=<epoch>]: {the missing variable}` and stop.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.


## pr-host-home/data/brief-prhost-bb4/brief.md
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/brief-prhost-bb4
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
This project's origin is Bitbucket Cloud, which `gh-axi` cannot reach, so you open and check the PR with firstmate's helper, `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh`.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch with `git push -u origin fm/brief-prhost-bb4`, then run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh open` from this copy, which opens a PR that is ready for review, not a draft, using the repository's default destination and your HEAD commit's subject and body, and prints its https URL (it reuses a PR already open from your origin repository and branch rather than creating a second one).
The helper works only on this copy, its Bitbucket origin, and its current branch; it refuses a missing or non-Bitbucket origin and a detached HEAD.
Before you report done, read the PR back from Bitbucket with `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh verify <pr-url>` using the URL that open returned: it must exit 0 and print `draft: no`, which also confirms the PR is open, comes from your origin repository and current branch, and carries this copy's HEAD; if it reports a draft, run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh ready <pr-url>`, and if it reports a different head, push your latest commit and verify again.
The helper takes its credential from the NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN environment variables and never prints them; never print, echo, or write either one anywhere yourself, and if the helper names one as missing, append `blocked [at=<epoch>]: {the missing variable}` and stop.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.


## pr-host-home/data/brief-prhost-bb5/brief.md
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/brief-prhost-bb5
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
This project's origin is Bitbucket Cloud, which `gh-axi` cannot reach, so you open and check the PR with firstmate's helper, `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh`.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch with `git push -u origin fm/brief-prhost-bb5`, then run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh open` from this copy, which opens a PR that is ready for review, not a draft, using the repository's default destination and your HEAD commit's subject and body, and prints its https URL (it reuses a PR already open from your origin repository and branch rather than creating a second one).
The helper works only on this copy, its Bitbucket origin, and its current branch; it refuses a missing or non-Bitbucket origin and a detached HEAD.
Before you report done, read the PR back from Bitbucket with `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh verify <pr-url>` using the URL that open returned: it must exit 0 and print `draft: no`, which also confirms the PR is open, comes from your origin repository and current branch, and carries this copy's HEAD; if it reports a draft, run `/home/node/.no-mistakes/worktrees/450411b3e67c/01M49Z4JCXXQR6ZMPDQQC08J2K/bin/fm-pr-open.sh ready <pr-url>`, and if it reports a different head, push your latest commit and verify again.
The helper takes its credential from the NO_MISTAKES_BITBUCKET_EMAIL and NO_MISTAKES_BITBUCKET_API_TOKEN environment variables and never prints them; never print, echo, or write either one anywhere yourself, and if the helper names one as missing, append `blocked [at=<epoch>]: {the missing variable}` and stop.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.


## pr-host-home/data/brief-prhost-ghone/brief.md
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/brief-prhost-ghone
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch and open a PR with `gh-axi` that is ready for review, not a draft.
Before you report done, read the PR back from the forge and confirm it is not a draft (`gh-axi pr view <number>` must print `draft: no`, where <number> is the PR number from your PR URL); if it is a draft, mark it ready with `gh-axi pr ready <number>`.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.


## pr-host-home/data/brief-prhost-nm/brief.md
# Definition of done
Delivery contract: mode=no-mistakes
Ship branch: fm/brief-prhost-nm
The task is complete only when committed on your branch.
When you believe it is complete, append `done [at=<epoch>]: {summary}` to the status file and stop.
Firstmate will then instruct you to run /no-mistakes to validate and ship a PR.
That first `done:` is the handoff that starts the pipeline, which owns the push; it is not a request to push from this copy.

You drive no-mistakes by responding to its gates, not by implementing fixes.
Follow the guidance no-mistakes itself provides for the mechanics: it loads when you invoke /no-mistakes, and `no-mistakes axi run --help` plus the `help` lines in each `axi` response are authoritative and version-matched to the installed binary.
When starting no-mistakes, pass `--intent` as only this brief's `## Captain's intent` subsection body, not its heading, plus any later words the captain actually said.
Preserve the actual words without adding speaker labels or direct address; the subsection heading supplies provenance outside the pipeline input.
For a legacy brief with no such subsection, include only words on lines marked `[captain] `, excluding that metadata prefix; never copy its mixed `# Task` wholesale.
If it has no provenance-marked captain words, stop and ask firstmate instead of starting no-mistakes.
Do not include `## Firstmate spec`, later Firstmate build constraints, or your own decisions and tradeoffs.
If you pass `--intent` through a file, write it under your task temp root named in the Rules, never at a fixed path in shared /tmp.
The `--intent` string you pass must be self-sufficient: that string plus the codebase must let a reader reconstruct roughly the same specification, without depending on a separate report, a PR, or context that lives only in this conversation.
When the captain's intent refers to a report, decision, or PR ("do items 1, 2, 3, and 7 of the report"), write the substance of the referenced items into `--intent` in the captain's terms, not only the pointer; that substance is the captain's ask by reference, while Firstmate's build instructions and your own decisions still stay out.
This replaces the no-mistakes skill's advice to enrich `--intent` with decisions and tradeoffs; that advice does not apply to Firstmate-dispatched work.
Do not hand-edit, commit, or fix findings yourself while a run is active - the pipeline applies every fix.

One drive call blocks until the next gate or outcome, which routinely outlives what your harness lets a single command run: Claude Code kills a command at ten minutes maximum, while one fix round is capped around thirty minutes and up to three rounds chain.
So background the drive call instead of sitting in one blocking hold your harness will kill, and read its return when it finishes.
Declare that wait using the brief's status-reporting rule before waiting on the backgrounded drive call.
Where a harness's own command limit is not established, assume it bounds commands and use that same backgrounded shape.
Only a drive call's return reports the green PR: `no-mistakes axi status` shows progress but never reports `checks-passed` while the ci step is still monitoring the PR for merge, so never wait on a status poll for the next gate or outcome.
Whenever a drive call returns without a gate or an outcome - its own wait elapsed, or it was killed or timed out - reattach at once by re-running `no-mistakes axi run` without flags, backgrounded the same way; once checks are green it returns `checks-passed` immediately, and if it refuses because no run is active, read the finished outcome from `no-mistakes axi status`.
A killed or timed-out call is never evidence the daemon died: the daemon accepts your response immediately and runs the round in the background, so the call was only ever waiting for a read while the run kept working.
Reattach and keep going rather than reporting the pipeline blocked; rule 7 owns the checks that decide when a pipeline block is real.

Two firstmate-specific rules layer on top of that guidance:
- ask-user findings are never yours to answer: escalate to firstmate using rule 6's ask-user format and stop.
  Firstmate applies `ask-user-authority` and obtains any required captain decision.
  When the decision comes back, feed it to the gate with `no-mistakes axi respond` and let the pipeline apply it - do not route the question to "the user" or implement the fix yourself.
- NEVER pass `--yes` (or `-y`) to `no-mistakes axi run` or `no-mistakes axi respond`. It is banned fleet-wide.
  It auto-resolves every gate including ask-user findings with no escalation, and answering your own ask-user finding is a hard rule violation.

After /no-mistakes reports CI green (the CI-ready return point - do not wait for it to keep monitoring in the background until merge), read the PR back from the forge and confirm it is not a draft (`gh-axi pr view <number>` must print `draft: no`, where <number> is the PR number from your PR URL); if it is a draft, mark it ready with `gh-axi pr ready <number>`.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url} checks green` and stop. You are finished.
That CI-ready `done:` is accepted only when this copy's HEAD - your latest commit - is one the /no-mistakes run pushed, so commit nothing after the run; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.


## ship-home/data/brief-directpr-a2/brief.md
# Definition of done
Delivery contract: mode=direct-PR
Ship branch: fm/brief-directpr-a2
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch and open a PR with `gh-axi` that is ready for review, not a draft.
Before you report done, read the PR back from the forge and confirm it is not a draft (`gh-axi pr view <number>` must print `draft: no`, where <number> is the PR number from your PR URL); if it is a draft, mark it ready with `gh-axi pr ready <number>`.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url}` to the status file and stop.
That `done:` is accepted only when this copy's HEAD - your latest commit - is pushed to your PR branch; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.


## ship-home/data/brief-localonly-a3/brief.md
# Definition of done
Delivery contract: mode=local-only
Ship branch: fm/brief-localonly-a3
This task ships **local-only**: no remote, no PR, no pipeline.
The task is complete only when committed on your branch `fm/brief-localonly-a3`. Do NOT push, do NOT open a PR, do NOT merge.
A `done:` is accepted when the named head is on this project's shared local branch, not only on a detached copy; the check tests that head, not merely that a branch moved.
Keep your branch a clean fast-forward onto the current default branch - if `main` has advanced, rebase onto it so the eventual merge stays a fast-forward.
When it is implemented and committed, append `done [at=<epoch>]: ready in branch fm/brief-localonly-a3` to the status file and stop.
The configured merge authority approves the ready branch, then firstmate merges it into local `main` through the guarded fast-forward path.


## ship-home/data/brief-nomistakes-a1/brief.md
# Definition of done
Delivery contract: mode=no-mistakes
Ship branch: fm/brief-nomistakes-a1
The task is complete only when committed on your branch.
When you believe it is complete, append `done [at=<epoch>]: {summary}` to the status file and stop.
Firstmate will then instruct you to run /no-mistakes to validate and ship a PR.
That first `done:` is the handoff that starts the pipeline, which owns the push; it is not a request to push from this copy.

You drive no-mistakes by responding to its gates, not by implementing fixes.
Follow the guidance no-mistakes itself provides for the mechanics: it loads when you invoke /no-mistakes, and `no-mistakes axi run --help` plus the `help` lines in each `axi` response are authoritative and version-matched to the installed binary.
When starting no-mistakes, pass `--intent` as only this brief's `## Captain's intent` subsection body, not its heading, plus any later words the captain actually said.
Preserve the actual words without adding speaker labels or direct address; the subsection heading supplies provenance outside the pipeline input.
For a legacy brief with no such subsection, include only words on lines marked `[captain] `, excluding that metadata prefix; never copy its mixed `# Task` wholesale.
If it has no provenance-marked captain words, stop and ask firstmate instead of starting no-mistakes.
Do not include `## Firstmate spec`, later Firstmate build constraints, or your own decisions and tradeoffs.
If you pass `--intent` through a file, write it under your task temp root named in the Rules, never at a fixed path in shared /tmp.
The `--intent` string you pass must be self-sufficient: that string plus the codebase must let a reader reconstruct roughly the same specification, without depending on a separate report, a PR, or context that lives only in this conversation.
When the captain's intent refers to a report, decision, or PR ("do items 1, 2, 3, and 7 of the report"), write the substance of the referenced items into `--intent` in the captain's terms, not only the pointer; that substance is the captain's ask by reference, while Firstmate's build instructions and your own decisions still stay out.
This replaces the no-mistakes skill's advice to enrich `--intent` with decisions and tradeoffs; that advice does not apply to Firstmate-dispatched work.
Do not hand-edit, commit, or fix findings yourself while a run is active - the pipeline applies every fix.

One drive call blocks until the next gate or outcome, which routinely outlives what your harness lets a single command run: Claude Code kills a command at ten minutes maximum, while one fix round is capped around thirty minutes and up to three rounds chain.
So background the drive call instead of sitting in one blocking hold your harness will kill, and read its return when it finishes.
Declare that wait using the brief's status-reporting rule before waiting on the backgrounded drive call.
Where a harness's own command limit is not established, assume it bounds commands and use that same backgrounded shape.
Only a drive call's return reports the green PR: `no-mistakes axi status` shows progress but never reports `checks-passed` while the ci step is still monitoring the PR for merge, so never wait on a status poll for the next gate or outcome.
Whenever a drive call returns without a gate or an outcome - its own wait elapsed, or it was killed or timed out - reattach at once by re-running `no-mistakes axi run` without flags, backgrounded the same way; once checks are green it returns `checks-passed` immediately, and if it refuses because no run is active, read the finished outcome from `no-mistakes axi status`.
A killed or timed-out call is never evidence the daemon died: the daemon accepts your response immediately and runs the round in the background, so the call was only ever waiting for a read while the run kept working.
Reattach and keep going rather than reporting the pipeline blocked; rule 7 owns the checks that decide when a pipeline block is real.

Two firstmate-specific rules layer on top of that guidance:
- ask-user findings are never yours to answer: escalate to firstmate using rule 6's ask-user format and stop.
  Firstmate applies `ask-user-authority` and obtains any required captain decision.
  When the decision comes back, feed it to the gate with `no-mistakes axi respond` and let the pipeline apply it - do not route the question to "the user" or implement the fix yourself.
- NEVER pass `--yes` (or `-y`) to `no-mistakes axi run` or `no-mistakes axi respond`. It is banned fleet-wide.
  It auto-resolves every gate including ask-user findings with no escalation, and answering your own ask-user finding is a hard rule violation.

After /no-mistakes reports CI green (the CI-ready return point - do not wait for it to keep monitoring in the background until merge), read the PR back from the forge and confirm it is not a draft (`gh-axi pr view <number>` must print `draft: no`, where <number> is the PR number from your PR URL); if it is a draft, mark it ready with `gh-axi pr ready <number>`.
A draft cannot be merged, so a done report on one leaves the merge unasked.
Then append `done [at=<epoch>]: PR {url} checks green` and stop. You are finished.
That CI-ready `done:` is accepted only when this copy's HEAD - your latest commit - is one the /no-mistakes run pushed, so commit nothing after the run; the check tests that commit, not merely that a branch moved.
If you deliberately keep the PR a draft, append `paused [at=<epoch>]: {why the draft is held}` instead of done.

