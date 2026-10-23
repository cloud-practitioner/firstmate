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
                         'password=correct-horse&token=short-secret',
                         '<password>correct-horse</password>',
                         '<root><token>short-secret</token><name>public</name></root>',
                         '<s:Envelope xmlns:s="urn:test"><s:password>correct-horse</s:password></s:Envelope>',
                         '<credentials><password>correct-horse</password><token>short-secret</token></credentials>',
                         '<password><![CDATA[correct-horse]]></password>',
                         '<password><password>correct-horse</password>short-secret</password>',
                         '<password>correct-horse',
                         '<login password="correct-horse" token="short-secret"/>',
                         '<token value="short-secret"/>',
                         '<password value="correct-horse">***masked (1 chars)***</password>',
                         '<s:token xmlns:s="urn:test" value="short-secret"/>',
                         '<token value="short-secret" hint="correct-horse">text</token>'):
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
                   'Proxy-Authorization: Basic Y29ycmVjdC1ob3JzZQ==',
                   '<password>correct-horse</password> token=short-secret',
                   '<token value="short-secret" password="correct-horse"/>')
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

    def test_complete_secret_headers_are_masked_in_free_text(self):
        credential = '0123456789abcdef0123456789abcdef01234567'
        headers = ('Authorization: Token ' + credential,
                   'Proxy-Authorization: Custom first-part ' + credential,
                   'Authorization: Token\r\n\t' + credential,
                   'Cookie: theme=light; sid=' + credential,
                   'Set-Cookie: theme=light; sid=' + credential + '; HttpOnly',
                   'X-API-Key: first-part ' + credential,
                   'Authorization: ***masked (5 chars)*** ' + credential,
                   'Cookie: ***masked (11 chars)***; sid=' + credential)
        for header in headers:
            variants = (header, '> ' + header + '\r\nAccept: application/json\r\n',
                        'curl -H "' + header + '" https://example.test',
                        json.dumps({'body': header, 'message': 'public text'}), json.dumps(header))
            for value in variants:
                with self.subTest(value=value):
                    masked = ev.mask_text(value)
                    self.assertNotIn(credential, masked)
                    self.assertEqual(masked, ev.mask_text(masked))
                    if value.startswith(('{', '"')):
                        json.loads(masked)
                    for side in ('request', 'response'):
                        data = exchange()
                        data[side]['body'] = value
                        self.assertTrue(ev.sidecar_problems(data))
                        masked_data = ev.mask_sidecar(copy.deepcopy(data))
                        self.assertNotIn(credential, json.dumps(masked_data))
                        self.assertFalse(ev.sidecar_problems(masked_data))
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            raw, out = tmp / 'raw', tmp / 'captured'
            raw.write_text('\n'.join(headers) + '\npublic text\n')
            ev.cmd_capture_ui_text(argparse.Namespace(raw=str(raw), out=str(out), command='curl -H "' + headers[0] + '"', rc=0))
            self.assertNotIn(credential, out.read_text())
            self.assertIn('public text', out.read_text())
            def render(lines, marked, labels, purpose, path):
                self.assertNotIn(credential, '\n'.join(lines))
                Path(path).write_bytes(b'masked image')
            args = argparse.Namespace(image=None, text=str(raw), against=None, mark_line=[0], label=None,
                                      purpose='The tool hides the header values.', out=str(tmp / 'out.png'))
            with patch.object(ev, 'render_text_with_marks', side_effect=render), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(0, ev.cmd_annotate_ui(args))

    def test_standalone_english_checker_uses_only_the_shipped_vocabulary(self):
        import subprocess
        command = ['python3', str(ROOT / 'bin/fm-pr-evidence-lib.py'), 'ste', '--text', 'The system will abandon the task.']
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("word 'abandon' is not approved; try stop", result.stdout)
        with tempfile.TemporaryDirectory() as tmp:
            vocab = Path(tmp) / 'custom.tsv'
            vocab.write_text('system\ttool\n')
            result = subprocess.run(command + ['--vocab', str(vocab)], capture_output=True, text=True)
            self.assertEqual(2, result.returncode)
            self.assertIn('--vocab', result.stderr)

    def test_authorization_codes_are_masked_in_every_exchange_field(self):
        code = 'a1b2c3d4e5f6a1b2c3d4'
        url = 'https://app.example/callback?code=' + code
        form = 'grant_type=authorization_code&code=' + code
        for side in ('request', 'response'):
            for field in ('headers', 'body', 'url'):
                if field == 'url' and side != 'request':
                    continue
                with self.subTest(side=side, field=field):
                    data = exchange()
                    data[side][field] = [['Location', url]] if field == 'headers' else form if field == 'body' else url
                    self.assertTrue(ev.sidecar_problems(data))
                    masked = ev.mask_sidecar(copy.deepcopy(data))
                    self.assertNotIn(code, json.dumps(masked))
                    self.assertFalse(ev.sidecar_problems(masked))
                    self.assertEqual(masked, ev.mask_sidecar(copy.deepcopy(masked)))
        for text in ('code=' + code, 'curl --data "' + form + '"', url):
            self.assertNotIn(code, ev.mask_text(text))
        for text in ('{"code": 302}', 'STATUS CODE: 302', 'postcode=12345'):
            self.assertEqual(text, ev.mask_text(text))

    def test_pkce_verifiers_are_masked_in_all_text_representations(self):
        verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'
        forms = ('code_verifier=' + verifier,
                 'https://app.example/token?code_verifier=' + verifier,
                 json.dumps({'code_verifier': verifier}),
                 json.dumps({'items': [{'code_verifier': verifier}]}))
        for side in ('request', 'response'):
            for body in forms:
                with self.subTest(side=side, body=body):
                    data = exchange()
                    data[side]['body'] = body
                    self.assertTrue(ev.sidecar_problems(data))
                    masked = ev.mask_sidecar(copy.deepcopy(data))
                    self.assertNotIn(verifier, json.dumps(masked))
                    self.assertFalse(ev.sidecar_problems(masked))
                    self.assertEqual(masked, ev.mask_sidecar(copy.deepcopy(masked)))
        data = exchange()
        data['request']['url'] = forms[1]
        data['response']['headers'].append(['Location', forms[1]])
        self.assertTrue(ev.sidecar_problems(data))
        self.assertNotIn(verifier, json.dumps(ev.mask_sidecar(data)))
        with tempfile.TemporaryDirectory() as tmp:
            raw, out = Path(tmp) / 'raw', Path(tmp) / 'out'
            raw.write_text(forms[0])
            ev.cmd_capture_ui_text(argparse.Namespace(raw=str(raw), out=str(out), command='tool ' + forms[0], rc=0))
            self.assertNotIn(verifier, out.read_text())
        self.assertEqual('code_challenge=' + verifier, ev.mask_text('code_challenge=' + verifier))

    def test_sensitive_xml_attributes_preserve_public_siblings(self):
        from xml.etree import ElementTree as ET
        body = '<root><token value="short-secret" hint="correct-horse"/><name value="public"/></root>'
        masked = ev.mask_text(body)
        root = ET.fromstring(masked)
        self.assertEqual({"value", "hint"}, set(root.find("token").attrib))
        self.assertTrue(all(ev.MASK_RE.fullmatch(value) for value in root.find("token").attrib.values()))
        self.assertEqual("public", root.find("name").get("value"))
        self.assertEqual(masked, ev.mask_text(masked))

    def test_typographic_contractions_are_strictly_refused(self):
        texts = ("The tool isn't ready.", "We're ready for work.", "We've changed the text.",
                 "It'll change the text.", "I'd change the text.", "I'm ready for work.", "It's ready for work.")
        for apostrophe in ("'", "\u2018", "\u2019"):
            for kind in ("purpose", "label", "steps"):
                for text in texts:
                    for quote in ("", '"', '`'):
                        candidate = quote + text.replace("'", apostrophe) + quote
                        with self.subTest(apostrophe=apostrophe, kind=kind, text=candidate):
                            failures, _ = ev.ste_check(candidate, kind)
                            self.assertTrue(any("contraction" in failure for failure in failures), failures)
                self.assertFalse(ev.ste_check("The user's name is shown.".replace("'", apostrophe), kind)[0])

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
                ev.verify_images(findings, {"provider": "github"}, {"html": rendered}, body, shas, 2, "publish again")
            self.assertTrue(any("cli after image has no drawn marks" in what for what, _ in findings.fails))

    def test_quoted_text_has_no_strict_english_exemption(self):
        for quote in ('"', '`'):
            for kind in ('purpose', 'label', 'steps'):
                for fragment, problem in (("seamless", "banned word"), ("it's", "contraction"),
                                          ("e.g.", "abbreviation"), ("under the hood", "banned phrase"),
                                          ("new; old", "semicolon"), ("new — old", "long dash"),
                                          (" ".join(["word"] * 30), "maximum")):
                    text = 'The text is ' + quote + fragment + quote
                    with self.subTest(quote=quote, kind=kind, fragment=fragment):
                        fails, _ = ev.ste_check(text, kind)
                        self.assertTrue(any(problem in failure for failure in fails), fails)
                self.assertFalse(ev.ste_check('The text is ' + quote + 'plain' + quote, kind)[0])

    def test_unreadable_configuration_is_not_disabled(self):
        for error in (PermissionError("permission denied"), UnicodeError("invalid text"), IsADirectoryError("not a file")):
            with self.subTest(error=error), patch("builtins.open", side_effect=error), contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(0, ev.cmd_config(argparse.Namespace(file="config/pr-evidence", project="proj")))
                self.assertTrue(json.loads(output.getvalue())["errors"])
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(0, ev.cmd_config(argparse.Namespace(file=str(Path(tmp) / "absent"), project="proj")))
            self.assertEqual([], json.loads(output.getvalue())["errors"])

    def test_insertions_and_deletions_can_annotate_both_phases(self):
        pairs = (("alpha", "alpha\nbeta"), ("omega", "beta\nomega"),
                 ("alpha\nomega", "alpha\nbeta\nomega"), ("", "beta"),
                 ("alpha\nomega", "alpha\n\nomega"))
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            def render(lines, marked, labels, purpose, out):
                self.assertTrue(marked)
                self.assertTrue(all(0 <= index < len(lines) for index in marked))
                Path(out).write_bytes(b"rendered image")
            for before, after in pairs:
                for left, right in ((before, after), (after, before)):
                    for command in (ev.cmd_annotate_ui, ev.cmd_annotate_api):
                        path, other = tmp / "left", tmp / "right"
                        if command == ev.cmd_annotate_api:
                            data, against = exchange(), exchange()
                            data["response"]["body"], against["response"]["body"] = left, right
                            path.write_text(json.dumps(data))
                            other.write_text(json.dumps(against))
                        else:
                            path.write_text(left)
                            other.write_text(right)
                        args = argparse.Namespace(image=None, text=str(path), sidecar=str(path), against=str(other),
                                                  label=None, purpose="The tool shows the added line.", out=str(tmp / "out.png"))
                        with self.subTest(command=command.__name__, left=left, right=right), \
                                patch.object(ev, "render_text_with_marks", side_effect=render), contextlib.redirect_stdout(io.StringIO()):
                            self.assertEqual(0, command(args))

    def test_xml_secrets_cannot_reach_annotation_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            body = '<password value="correct-horse"/>'
            path = tmp / "text"
            path.write_text(body)
            def render(lines, marked, labels, purpose, out):
                self.assertNotIn("correct-horse", "\n".join(lines))
                Path(out).write_bytes(b"masked image")
            args = argparse.Namespace(image=None, text=str(path), mark_line=[0], against=None, label=None,
                                      purpose="The tool shows the masked value.", out=str(tmp / "out.png"))
            with patch.object(ev, "render_text_with_marks", side_effect=render), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(0, ev.cmd_annotate_ui(args))
            for side in ("request", "response"):
                data = exchange()
                data[side]["body"] = body
                sidecar = tmp / "sidecar.json"
                sidecar.write_text(json.dumps(data))
                args.sidecar = str(sidecar)
                with patch.object(ev, "render_text_with_marks") as render, contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(1, ev.cmd_annotate_api(args))
                    render.assert_not_called()

    def test_effective_declaration_uses_only_pr_author_comments(self):
        def comment(author, kinds):
            return {"author": author, "body": "```fm-pr-evidence-v1\n" + json.dumps({"kind": kinds, "items": []}) + "\n```"}
        self.assertEqual("ui+api", ev.effective_declaration("ui", [comment("worker", "ui+api")], {"worker"}))
        self.assertEqual("ui", ev.effective_declaration("ui", [comment("captain", "ui+api")], {"worker"}))


if __name__ == "__main__":
    unittest.main()
