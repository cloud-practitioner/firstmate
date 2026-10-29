# Live IQX brief-generator evidence

The real `bin/fm-brief.sh --scout` and `contrib/iqx-lenses/mk-lens-brief.py` generated these outputs in an isolated worktree-local home. Dependency metadata, plans and ticket inputs were synthetic; no reviewer model, SAP, credentials, network clone, fleet lifecycle or publishing step was driven.

## Generated public outputs

- [panel-architect-brief.md](panel-architect-brief.md) (16878 bytes)
- [panel-clone-path-brief.md](panel-clone-path-brief.md) (15703 bytes)
- [runproof-primary-brief.md](runproof-primary-brief.md) (43874 bytes)
- [runproof-second-model-brief.md](runproof-second-model-brief.md) (43713 bytes)
- [shadow-copilot-brief.md](shadow-copilot-brief.md) (17362 bytes)
- [shadow-openai-brief.md](shadow-openai-brief.md) (17297 bytes)

## Observed CLI and persisted-state behavior

- symlink-spelled scout accepted; preview byte-identical to written brief; exact review, pointer and probe grants agree.
- second model receives its own report/probe paths and freeze-before-comparison instruction.
- panel and two providers with identical model tails retain and run same-named probes without overwriting each other.
- relative credential path emitted absolute; synthetic file content not emitted or consumed. No clone or login attempted.
- base mismatch, missing required files/arguments and second fill refuse without modifying the brief; explicit home leaves foreign home unchanged.
- locked-version mismatch warned and brief generated, per the public compatibility contract.

The [exact CLI transcript](manual-cli-transcript.txt) contains commands, exit codes, stdout and stderr. The [manual driver](manual-cli-driver.py) documents the setup and assertions. The [focused existing test log](iqx-lenses-targeted-test.log) covers all reviewer kinds/lenses, default/named bases, stdout/write, dependency path forms and symlink/report-path refusal variants.

These are public generated instruction contracts, not evidence that a model follows them. The scenario has no visual UI surface; the reviewer-visible outputs are Markdown briefs and CLI transcripts.
