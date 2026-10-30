# Ground-rules CLI validation

This change's product surface is a manually invoked brief generator, not a reviewer launcher. Validation executed the real `bin/fm-brief.sh --scout` and `contrib/iqx-lenses/mk-lens-brief.py` CLIs against a disposable home inside the gate worktree. No external service, real home, login, reviewer, or fleet was used. The pinned-plugin version file was synthetic input; the scaffold and generator were the real product. The output contract under test is the final generated brief delivered to a reviewer. These checks do **not** claim that a language model followed the instructions.

## Product artifacts

- [Panel with ground rules](panel-solutions-architect-enabled.md) / [without ground rules](panel-solutions-architect-default.md)
- [Shadow with ground rules](shadow-security-architect-enabled.md) / [without ground rules](shadow-security-architect-default.md)
- [Run-proof with unsupported explicit plan-test seeds](runproof-explicit-seeds-enabled.md) / [without ground rules](runproof-explicit-seeds-default.md)
- [Run-proof with generated ticket seeds](runproof-generated-seeds-enabled.md) / [without ground rules](runproof-generated-seeds-default.md)
- [Second-model run-proof](runproof-second-model-enabled.md) / [without ground rules](runproof-second-model-default.md)
- [CLI refusals: missing file, directory, actual permission denial](invalid-file-cli-transcript.txt)
- [CLI help](generator-help.txt)

The enabled panel/shadow briefs require the ground-rules page and rule-id citations but do not impose run-proof's unconfirmed-premise policy. Run-proof's emitted section 8 and activation paragraph override inherited probe and checklist seed instructions, including unsupported assumptions listed as plan tests. Both explicit seed interfaces and the no-seeds branch were exercised. An absolute path and a home-relative path containing spaces were resolved from a separate invocation directory.

## Compatibility and regression evidence

- [Default compatibility and write/stdout delivery matrix](default-compatibility-and-delivery.json): all four panel lenses, all four shadow lenses, and three run-proof variants. Each current default output and stderr matched an executed copy of the base generator at `61b748936d05158279c53cefb63db770463283aa` using identical inputs. The opt-in addition removed no default lines; stdout left the scaffold untouched; writing produced precisely the stdout bytes.
- [Exact CLI command transcript](manual-cli-transcript.txt)
- [Emitted pre-review-fix run-proof brief](runproof-prior-fix-emitted.md): executing `a8f7194f` reproduces the former "is still probed" exception and fails the current emitted-contract check; the current output passes.
- [Focused add-on test log](iqx-lenses-targeted-test.log): `TMPDIR="$PWD/.live-ground-rules/tmp" bash contrib/iqx-lenses/iqx-lenses.test.sh`. This is the contrib add-on's suite, not the repository-wide suite.
- [Disposable CLI driver](validate_ground_rules.py): executed as `python3 .live-ground-rules/validate_ground_rules.py`; contains the setup, actual CLI invocations and assertions. To reproduce from the repository root, create `.live-ground-rules/tmp` first and run the archived driver with Python 3.

All checked scenarios passed. Disposable data and extracted historical generator copies were removed; only this evidence remains. This is a CLI/text-output change, so no UI or screenshot evidence applies. No linters, formatters, static analysis, broad repository suite, push, PR, merge, or pipeline-control operations were run.
