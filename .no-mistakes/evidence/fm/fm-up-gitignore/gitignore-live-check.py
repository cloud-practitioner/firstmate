#!/usr/bin/env python3
"""Exercise the candidate .gitignore through real Git in disposable repositories.
Run from the assigned gate worktree. Only synthetic configuration is created.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path.cwd()
BASE = "b936f04076b1822fceaace5dad08c8682329235d"
TARGET = "f14274f4d4333e8090de45cc9f72624ebf856d87"
env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
env.update(GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1", LC_ALL="C", GIT_TERMINAL_PROMPT="0")


def run_git(repo, *args, expected=0, show=True):
    command = ["git", "-c", "core.excludesFile=/dev/null", "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgsign=false", "-C", str(repo), *args]
    result = subprocess.run(command, env=env, text=True, capture_output=True, check=False)
    if show:
        print("$ git " + " ".join(args), flush=True)
        print(result.stdout if result.stdout else "(no stdout)", end="" if result.stdout else "\n", flush=True)
        if result.stderr:
            print(result.stderr, end="", flush=True)
        print(f"[exit {result.returncode}]", flush=True)
    assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)
    return result.stdout


with tempfile.TemporaryDirectory(prefix=".fm-gitignore-live-", dir=ROOT) as temp:
    temp = Path(temp)
    print("Git consumer:", subprocess.check_output(["git", "--version"], env=env, text=True).strip(), flush=True)
    print("All JSON below is synthetic; no credentials or user configuration are used.", flush=True)
    for variant in ("baseline", "candidate"):
        repo = temp / variant
        repo.mkdir()
        run_git(repo, "init", "-q", "--template=", show=False)
        if variant == "baseline":
            (repo / ".gitignore").write_text(run_git(ROOT, "show", f"{BASE}:.gitignore", show=False))
        else:
            shutil.copyfile(ROOT / ".gitignore", repo / ".gitignore")
        run_git(repo, "add", ".gitignore", show=False)
        run_git(repo, "-c", "user.name=Disposable Git Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "Seed synthetic fixture", show=False)
        (repo / ".claude").mkdir()
        (repo / ".claude/settings.local.json").write_text('{"permissions":{"allow":[]}}\n')
        print(f"\n=== {variant}: create .claude/settings.local.json ===", flush=True)
        status = run_git(repo, "status", "--porcelain=v1", "--untracked-files=all")
        if variant == "baseline":
            assert status == "?? .claude/settings.local.json\n", status
            run_git(repo, "check-ignore", "-v", ".claude/settings.local.json", expected=1)
            print("Reported regression reproduced against the supplied upstream baseline.", flush=True)
            continue
        assert status == "", status
        ignored = run_git(repo, "check-ignore", "-v", ".claude/settings.local.json")
        assert ignored.split("\t")[-1].strip() == ".claude/settings.local.json", ignored
        ignored_status = run_git(repo, "status", "--porcelain=v1", "--ignored", "--untracked-files=all")
        assert ignored_status == "!! .claude/settings.local.json\n", ignored_status
        run_git(repo, "add", ".")
        assert run_git(repo, "diff", "--cached", "--name-only") == ""
        print("Local settings stay out of both normal status and the index after git add .", flush=True)

        print("\n=== adversarial: shared and similarly named files remain visible ===", flush=True)
        visible = [".claude/settings.json", ".claude/settings.local.json.example", ".claude/settings.local.json.bak", ".claude/README.md", "settings.local.json"]
        for path in visible:
            (repo / path).write_text('{}\n' if path.endswith('.json') else 'synthetic public fixture\n')
        status = run_git(repo, "status", "--porcelain=v1", "--untracked-files=all")
        assert set(status.splitlines()) == {"?? " + path for path in visible}, status
        run_git(repo, "add", ".")
        staged = run_git(repo, "diff", "--cached", "--name-only")
        assert set(staged.splitlines()) == set(visible), staged
        print("Shared settings and controls stage normally; the per-user settings file does not.", flush=True)
        run_git(repo, "-c", "user.name=Disposable Git Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "Track synthetic shared controls", show=False)
        (repo / ".claude/settings.json").write_text('{"syntheticSharedChange":true}\n')
        (repo / ".claude/settings.local.json").write_text('{"syntheticLocalChange":true}\n')
        print("\n=== edit tracked shared settings alongside ignored local settings ===", flush=True)
        status = run_git(repo, "status", "--porcelain=v1", "--untracked-files=all")
        assert status == " M .claude/settings.json\n", status
        run_git(repo, "add", ".")
        assert run_git(repo, "diff", "--cached", "--name-only") == ".claude/settings.json\n"
        print("Only the shared-settings edit is stageable by normal add-all.", flush=True)

print("\nDisposable fixture repositories removed.", flush=True)
print("\n=== supplied upstream baseline incorporated into candidate ===", flush=True)
run_git(ROOT, "show", "-s", "--format=%H%n%P%n%s", TARGET)
run_git(ROOT, "merge-base", "--is-ancestor", BASE, TARGET)
