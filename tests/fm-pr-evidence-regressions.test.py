#!/usr/bin/env python3
import argparse
import contextlib
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).parent.parent
spec = importlib.util.spec_from_file_location("evidence", ROOT / "bin/fm-pr-evidence-lib.py")
ev = importlib.util.module_from_spec(spec)
with patch.dict(os.environ, {"FM_PR_EVIDENCE_MARK_MIN": "0"}):
    spec.loader.exec_module(ev)


def exchange():
    return {"request": {"method": "POST", "url": "https://example.test/login", "headers": [["Accept", "application/json"]], "body": ""},
            "response": {"status": 200, "reason": "OK", "headers": [["Content-Type", "application/json"]], "body": ""}}


class EvidenceRegressions(unittest.TestCase):
    def test_sensitive_fields_are_masked_and_rejected_on_both_sides(self):
        for side in ("request", "response"):
            for body in ('{"password":"correct-horse","token":"short-secret"}',
                         '{"items":[{"credentials":{"password":"short-secret"}}]}',
                         'password=correct-horse&token=short-secret'):
                with self.subTest(side=side, body=body):
                    data = exchange()
                    data[side]["body"] = body
                    self.assertTrue(ev.sidecar_problems(data))
                    masked = ev.mask_sidecar(copy.deepcopy(data))
                    self.assertNotIn("correct-horse", json.dumps(masked))
                    self.assertNotIn("short-secret", json.dumps(masked))
                    self.assertFalse(ev.sidecar_problems(masked))
                    self.assertEqual(masked, ev.mask_sidecar(copy.deepcopy(masked)))

    def test_urls_commands_and_terminal_text_are_masked(self):
        samples = ("https://user:correct-horse@example.test/items?token=short-secret",
                   "tool --password correct-horse --token 'short-secret'",
                   'PASSWORD="correct-horse" token=short-secret',
                   'curl --header Authorization: Bearer short-secret',
                   'Proxy-Authorization: Basic Y29ycmVjdC1ob3JzZQ==')
        for text in samples:
            masked = ev.mask_text(text)
            self.assertNotIn("correct-horse", masked)
            self.assertNotIn("short-secret", masked)
            self.assertNotIn("Y29ycmVjdC1ob3JzZQ==", masked)
            self.assertEqual(masked, ev.mask_text(masked))
        with tempfile.TemporaryDirectory() as tmp:
            raw, out = Path(tmp) / "raw", Path(tmp) / "out"
            raw.write_text(samples[2])
            ev.cmd_capture_ui_text(argparse.Namespace(raw=str(raw), out=str(out), command=samples[1], rc=0))
            self.assertNotIn("correct-horse", out.read_text())
            self.assertNotIn("short-secret", out.read_text())
            self.assertIn("exit status 0", out.read_text())

    def test_annotation_checks_all_drawn_text_before_rendering(self):
        with tempfile.TemporaryDirectory() as tmp:
            text = Path(tmp) / "text"
            text.write_text("new text\n")
            sidecar = Path(tmp) / "sidecar"
            sidecar.write_text(json.dumps(exchange()))
            for command in (ev.cmd_annotate_ui, ev.cmd_annotate_api):
                for field in ("purpose", "label", "mark"):
                    if command == ev.cmd_annotate_api and field == "mark":
                        continue
                    args = argparse.Namespace(image=None, text=str(text), against=None, mark_line=[0],
                                              label=["Text changed"], mark=None, purpose="The tool prints new text.",
                                              sidecar=str(sidecar), out=str(Path(tmp) / "out.png"))
                    if field == "mark":
                        args.image = "unused.png"
                        args.mark = ["1,1,40,20,It's fixed; seamless"]
                    elif field == "label":
                        args.label = ["It's fixed; seamless"]
                    else:
                        args.purpose = "It's fixed; seamless"
                    with self.subTest(command=command.__name__, field=field), contextlib.redirect_stdout(io.StringIO()) as log, \
                            patch.object(ev, "run_magick") as render, patch.object(ev, "render_text_with_marks") as render_text, \
                            patch.object(ev, "differing_lines", return_value=[0]):
                        self.assertEqual(1, command(args))
                        self.assertIn("semicolon", log.getvalue())
                        render.assert_not_called()
                        render_text.assert_not_called()

    def test_api_annotation_includes_late_changes_and_order_changes(self):
        with tempfile.TemporaryDirectory() as tmp:
            before, after = exchange(), exchange()
            before["response"]["body"] = json.dumps(list(range(60)) + ["old"])
            after["response"]["body"] = json.dumps(list(range(60)) + ["new"])
            paths = [Path(tmp) / name for name in ("before.json", "after.json")]
            for path, data in zip(paths, (before, after)):
                path.write_text(json.dumps(data))
            args = argparse.Namespace(sidecar=str(paths[1]), against=str(paths[0]),
                                      purpose="The service returns the new value.", label=None,
                                      out=str(Path(tmp) / "out.png"))
            def render(lines, marked, labels, purpose, out):
                self.assertTrue(any('"new"' in lines[i] for i in marked))
                self.assertTrue(any("59" in line for line in lines))
                Path(out).write_bytes(b"rendered image")
            with patch.object(ev, "render_text_with_marks", side_effect=render), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(0, ev.cmd_annotate_api(args))
            for left, right in ((["alpha", "beta"], ["beta", "alpha"]),
                                (["beta", "alpha"], ["alpha", "beta"]),
                                (["a", "b", "a"], ["a", "a", "b"])):
                self.assertTrue(ev.differing_lines(left, right))
            self.assertEqual([], ev.differing_lines(["same"], ["same"]))

    def test_annotation_warnings_reach_the_published_comment(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            items = []
            for phase, seed in (("before", 1), ("after", 2)):
                import subprocess
                path = tmp / (phase + ".png")
                subprocess.run(["python3", str(ROOT / "tests/fixtures/pr-evidence/mkpng.py"), str(path), str(seed), "400"], check=True)
                ev.save_annotation_texts(str(path), "The error was caused by a bad value.", ["Text changed"])
            items.append({"id": "cli", "kind": "ui", "purpose": "The tool prints new text.", "labels": [],
                          "before": {"image": "before.png"}, "after": {"image": "after.png"}})
            path = tmp / "items.json"
            path.write_text(json.dumps({"items": items}))
            args = argparse.Namespace(items=str(path), declared="ui", head="a" * 40, provider="github",
                                      repo="o/r", number="1", out=str(tmp / "publish"), banned=None, default_none_reason=None)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(0, ev.cmd_compose(args))
            comment = (tmp / "publish/comment.md").read_text()
            self.assertIn("Plain-English notes (warnings)", comment)
            self.assertIn("passive voice", comment)

    def test_verification_requires_marks_on_every_labelled_image(self):
        import hashlib
        import subprocess
        with tempfile.TemporaryDirectory() as tmp:
            images = {}
            shas = []
            for phase, count in (("before", 400), ("after", 0)):
                path = Path(tmp) / (phase + ".png")
                subprocess.run(["python3", str(ROOT / "tests/fixtures/pr-evidence/mkpng.py"), str(path), "1", str(count)], check=True)
                data = path.read_bytes()
                images[phase] = data
                shas.append(("cli", phase, hashlib.sha256(data).hexdigest()))
            findings = ev.Findings()
            body = "![cli before](https://github.com/user-attachments/assets/" + "a" * 36 + ")\n" + \
                   "![cli after](https://github.com/user-attachments/assets/" + "b" * 36 + ")\n"
            rendered = '<img alt="cli before" src="before"><img alt="cli after" src="after">'
            with patch.object(ev, "fetch", side_effect=lambda url, creds: (200, "image/png", images[url])):
                ev.verify_images(findings, None, {"provider": "github"}, {"html": rendered}, body, shas, 2, "publish again")
            self.assertTrue(any("cli after image has no drawn marks" in what for what, _ in findings.fails))

    def test_effective_declaration_uses_only_pr_author_comments(self):
        def comment(author, kinds):
            return {"author": author, "body": "```fm-pr-evidence-v1\n" + json.dumps({"kind": kinds, "items": []}) + "\n```"}
        self.assertEqual("ui+api", ev.effective_declaration("ui", [comment("worker", "ui+api")], {"worker"}))
        self.assertEqual("ui", ev.effective_declaration("ui", [comment("captain", "ui+api")], {"worker"}))


if __name__ == "__main__":
    unittest.main()
