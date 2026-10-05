# Worker scratch guidance: live evidence

Validation scope: b9073dd changes emitted worker guidance only. Temp-folder allocation and PR publication are separate work; no spawn-allocation, no-mistakes pipeline, push, PR, or CI phase was executed.

## Executed product surfaces
- Invoked real `bash bin/fm-brief.sh` for scout and all three ship modes, including a home path containing spaces. The emitted Rules name the correct task metadata, prohibit fixed shared `/tmp` scratch paths, and include task-local file-based `--intent` guidance for no-mistakes.
- Invoked real `bash bin/fm-promote.sh --mode <mode> --yolo off` for all three modes. Both the emitted ship instructions and persisted relaunch delivery contract retain scratch guidance; promotion preserves the recorded `tasktmp` value.
- Launched four actual Claude Code 2.1.288 print-mode workers on a disposable named Herdr lab through `bin/fm-herdr-lab.sh`. Each consumed an actual generated brief plus the product worker-role renderer. No vendor CLI or login was mocked.
- The two ship workers ran with the same task ID and required basename `intent.txt`, but different homes and goals. Both wrote exactly their own goal with a trailing newline under their own metadata-selected root.
- The scout wrote its scratch file under its recorded root. A promoted scout chose a relocated root containing a space, rather than guessing `state/<id>.tasktmp` or using the old scout write restriction.

## Persisted worker outputs
| Worker | Recorded task temp root | Exact intent file content |
| --- | --- | --- |
| alpha | `/home/node/.no-mistakes/worktrees/c98b859efde5/01M46G0PDZ4VFSXNWTR9GE0QEG/.scratch-validation/worker-alpha/state/same-task.tasktmp` | Provide the alpha-only goal: display temperature in Celsius. |
| beta | `/home/node/.no-mistakes/worktrees/c98b859efde5/01M46G0PDZ4VFSXNWTR9GE0QEG/.scratch-validation/worker-beta/state/same-task.tasktmp` | Provide the beta-only goal: display distance in kilometres. |
| scout | `/home/node/.no-mistakes/worktrees/c98b859efde5/01M46G0PDZ4VFSXNWTR9GE0QEG/.scratch-validation/worker-scout/state/same-task.tasktmp` | Prepare the scout-only investigation note. |
| promoted | `/home/node/.no-mistakes/worktrees/c98b859efde5/01M46G0PDZ4VFSXNWTR9GE0QEG/.scratch-validation/worker-promoted/relocated scratch/same-task.tasktmp` | Provide the promoted-only goal: show dates in ISO format. |

Only the four expected `intent.txt` paths existed in the disposable setup, each file matched its assigned goal exactly, and the disposable project remained unchanged. Each Claude result reports success with no permission denials.

## Isolation and test limitations
Task metadata and scratch roots were disposable fixture data inside the gate worktree. The test exercised the real emitted-guidance surface and real model interpretation; it did not invoke `fm-spawn.sh` or claim to prove per-home allocation/legacy cleanup. Read/Write-only restricted workers could access the disposable fixture tree but could not execute commands or write outside it. A preparation-only instruction prohibited all pipeline, Git, lifecycle, and remote operations without telling the workers which scratch directory to choose.

The normal inherited Claude login was available and used without any credential changes. An initial default-directory auth check had no login, but the inherited managed login was confirmed before live execution. Authentication account details were not saved as evidence.

The base commit was executed from a disposable in-worktree archive: its final emitted briefs lacked the new guidance and were correctly rejected by the target contract expectations. This is generated-output regression evidence, not an implementation-source assertion.

Two driver setup assumptions were corrected before the successful live run: relaunch comparison must compare the superseding delivery contract rather than the instruction-file preamble, and a fresh Herdr `provision` performs `prepare` internally. No product changes were needed.

The named Herdr lab was torn down in the live execution turn. The helper verified its default-session tripwire. All in-worktree fixtures and the baseline archive were removed after evidence capture. No repository test suite, linter, formatter, or static-analysis tool was run. The surface is CLI/agent-prompt text, so generated prompts, CLI logs, model replies, and persisted files are the reviewer-visible evidence rather than UI screenshots.
