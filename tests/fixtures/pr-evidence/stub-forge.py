#!/usr/bin/env python3
"""Local stub forge for tests/fm-pr-evidence.test.sh.

It serves just enough of the GitHub REST API (under /gh), the Bitbucket Cloud
API (under /bb/2.0), and an image server (under /img) for the evidence gate.
It also copies two real behaviours the gate depends on:
- GitHub renders an image line that directly follows a closing </details> line
  as nothing (fork PRs 35 and 38), so the stub renders no <img> for it.
- A Bitbucket Downloads URL answers a redirect to the stored file.
State lives in memory and is changed through /_admin routes. Usage:
  stub-forge.py <port-file> <image-dir>
"""
import email.parser
import hashlib
import http.server
import json
import os
import re
import sys
import threading

STATE = {"prs": {}, "comments": {}, "next": 100, "bb_auth": 0,
         "github_actor": "worker", "bitbucket_actor": "acct-worker", "writes": []}
LOCK = threading.Lock()
IMG_DIR = sys.argv[2]
PORT = [0]
MD_IMG = re.compile(r"^!\[([^\]]*)\]\(([^)\s]+)\)\s*$")


def base():
    return "http://127.0.0.1:%d" % PORT[0]


def uuid_of(sha):
    return "%s-%s-%s-%s-%s" % (sha[0:8], sha[8:12], sha[12:16], sha[16:20], sha[20:32])


def render(body, img_url):
    """Return (html, rewritten) the way the forge renders a comment body."""
    out, prev, fenced = [], "", False
    for line in body.split("\n"):
        stripped = line.strip()
        if stripped.startswith("```"):
            fenced = not fenced
            out.append("<pre>" if fenced else "</pre>")
            prev = stripped
            continue
        match = MD_IMG.match(stripped)
        if fenced:
            out.append(stripped.replace("<", "&lt;"))
        elif match and prev != "</details>":
            out.append('<p><img src="%s" alt="%s"></p>' % (img_url(match.group(2)), match.group(1)))
        elif match:
            out.append("<p>%s</p>" % stripped.replace("<", "&lt;"))  # shown as text, no image
        else:
            out.append("<p>%s</p>" % stripped if stripped else "")
        if stripped:
            prev = stripped
    return "\n".join(out)


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def log_message(self, *args):
        pass

    def send(self, code, payload=b"", ctype="application/json", headers=None):
        if not isinstance(payload, bytes):
            payload = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(payload)))
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(payload)

    def read_body(self):
        length = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(length) if length else b""

    def key(self, owner, repo, number):
        return "%s/%s/%s" % (owner, repo, number)

    def do_GET(self):
        path = self.path.split("?")[0]
        with LOCK:
            if path.startswith("/img/"):
                name = path[len("/img/"):]
                file = os.path.join(IMG_DIR, os.path.basename(name))
                if os.path.isfile(file):
                    with open(file, "rb") as fh:
                        return self.send(200, fh.read(), "image/png")
                return self.send(404, b"missing", "text/plain")
            m = re.match(r"^/gh/repos/([^/]+)/([^/]+)/pulls/(\d+)$", path)
            if m:
                pr = STATE["prs"].get(self.key(*m.groups()))
                if not pr:
                    return self.send(404, {"message": "Not Found"})
                return self.send(200, {"head": {"sha": pr["head"]}, "user": {"login": pr["author"]}, "state": "open"})
            m = re.match(r"^/gh/repos/([^/]+)/([^/]+)/pulls/(\d+)/files$", path)
            if m:
                pr = STATE["prs"].get(self.key(*m.groups()), {"files": []})
                return self.send(200, [f if isinstance(f, dict) else {"filename": f} for f in pr["files"]])
            m = re.match(r"^/gh/repos/([^/]+)/([^/]+)/issues/(\d+)/comments$", path)
            if m:
                return self.send(200, [dict(c, body_html=c["html"], updated_at=c["updated"])
                                       for c in STATE["comments"].get(self.key(*m.groups()), [])])
            if path == "/gh/user":
                return self.send(200, {"login": STATE["github_actor"]})
            if path == "/oauth":
                return self.send(302, b"return to the application", "text/plain", {
                    "Location": "https://app.example/callback?code=a1b2c3d4e5f6a1b2c3d4"})
            m = re.match(r"^/bb/2\.0/repositories/([^/]+)/([^/]+)/pullrequests/(\d+)(/diffstat|/comments)?$", path)
            if m:
                if not self.headers.get("Authorization", "").startswith("Basic "):
                    return self.send(401, {"error": "auth"})
                STATE["bb_auth"] += 1
                key = self.key(m.group(1), m.group(2), m.group(3))
                pr = STATE["prs"].get(key)
                if not pr:
                    return self.send(404, {})
                if m.group(4) == "/diffstat":
                    return self.send(200, {"values": [f if isinstance(f, dict) else {"new": {"path": f}} for f in pr["files"]]})
                if m.group(4) == "/comments":
                    return self.send(200, {"values": [
                        {"id": c["id"], "user": {"account_id": c["user"]["login"]},
                         "content": {"raw": c["body"], "html": c["html"]}, "updated_on": c["updated"]}
                        for c in STATE["comments"].get(key, [])]})
                return self.send(200, {"id": int(m.group(3)), "state": "OPEN", "author": {"account_id": pr["author"]},
                                       "source": {"commit": {"hash": pr["head"][:12]}}})
            m = re.match(r"^/bb/2\.0/repositories/([^/]+)/([^/]+)/commit/([0-9a-f]+)$", path)
            if m:
                for pr in STATE["prs"].values():
                    if pr["head"].startswith(m.group(3)):
                        return self.send(200, {"hash": pr["head"]})
                return self.send(404, {})
            if path == "/bb/2.0/user":
                return self.send(200, {"account_id": STATE["bitbucket_actor"]})
            m = re.match(r"^/bb/dl/([^/]+)/([^/]+)/(.+)$", path)
            if m:
                return self.send(302, b"", "text/plain", {"Location": base() + "/img/" + m.group(3)})
        return self.send(404, {"message": "no route", "path": path})

    def do_DELETE(self):
        path = self.path.split("?")[0]
        with LOCK:
            STATE["writes"].append(["DELETE", path])
            if STATE.get("delete_fail"):
                return self.send(503, {"error": "delete unavailable"})
            m = re.match(r"^/gh/repos/([^/]+)/([^/]+)/issues/comments/(\d+)$", path)
            if m:
                for key, items in STATE["comments"].items():
                    if key.startswith("%s/%s/" % (m.group(1), m.group(2))):
                        STATE["comments"][key] = [c for c in items if c["id"] != m.group(3)]
                return self.send(204)
            m = re.match(r"^/bb/2\.0/repositories/([^/]+)/([^/]+)/pullrequests/(\d+)/comments/(\d+)$", path)
            if m:
                key = self.key(*m.groups()[:3])
                STATE["comments"][key] = [c for c in STATE["comments"].get(key, []) if c["id"] != m.group(4)]
                return self.send(204)
        return self.send(404, {})

    def do_POST(self):
        path = self.path.split("?")[0]
        raw = self.read_body()
        with LOCK:
            if path == "/_admin/actor":
                data = json.loads(raw)
                STATE["github_actor"] = data.get("github", "worker")
                STATE["bitbucket_actor"] = data.get("bitbucket", "acct-worker")
                return self.send(200, {})
            if path.startswith(("/gh/", "/bb/")):
                STATE["writes"].append(["POST", path])
            if path == "/_admin/delete-failure":
                STATE["delete_fail"] = json.loads(raw)["enabled"]
                return self.send(200, {})
            if path == "/_admin/pr":
                data = json.loads(raw)
                STATE["prs"][data["key"]] = {"head": data["head"], "author": data.get("author", "worker"),
                                             "files": data.get("files", [])}
                STATE["comments"].setdefault(data["key"], [])
                return self.send(200, {})
            if path == "/_admin/comment":
                data = json.loads(raw)
                STATE["next"] += 1
                STATE["comments"].setdefault(data["key"], []).append({
                    "id": str(STATE["next"]), "user": {"login": data.get("author", "worker")},
                    "body": data["body"], "html": data["html"], "updated": data.get("updated", "2026-10-22T00:00:00Z")})
                return self.send(200, {"id": STATE["next"]})
            if path == "/_admin/replace":
                data = json.loads(raw)
                for c in STATE["comments"].get(data["key"], []):
                    if c["id"] == data["id"]:
                        c["body"], c["html"] = data["body"], data["html"]
                return self.send(200, {})
            if path == "/_admin/touch":
                data = json.loads(raw)
                for c in STATE["comments"].get(data["key"], []):
                    c["updated"] = data["updated"]
                return self.send(200, {})
            if path == "/_admin/state":
                return self.send(200, {"comments": STATE["comments"], "bb_auth": STATE["bb_auth"], "writes": STATE["writes"]})
            m = re.match(r"^/gh/repos/([^/]+)/([^/]+)/issues/(\d+)/comments$", path)
            if m:
                key = self.key(*m.groups())
                data = json.loads(raw)
                body = data["body"]
                for att in data.get("attachments", []):
                    with open(att["path"], "rb") as fh:
                        sha = hashlib.sha256(fh.read()).hexdigest()
                    with open(att["path"], "rb") as fh, open(os.path.join(IMG_DIR, sha + ".png"), "wb") as out:
                        out.write(fh.read())
                    url = "https://github.com/user-attachments/assets/" + uuid_of(sha)
                    body = body.replace("](%s)" % att["path"], "](%s)" % url)
                    STATE.setdefault("assets", {})[uuid_of(sha)] = sha
                assets = STATE.get("assets", {})

                def img_url(ref):
                    uid = ref.rsplit("/", 1)[-1]
                    return base() + "/img/" + assets.get(uid, "missing") + ".png"
                STATE["next"] += 1
                STATE["comments"].setdefault(key, []).append({
                    "id": str(STATE["next"]), "user": {"login": STATE["github_actor"]}, "body": body,
                    "html": render(body, img_url), "updated": "2026-10-22T01:00:00Z"})
                return self.send(201, {"id": STATE["next"], "html_url": "https://github.com/%s/pull/%s#issuecomment-%d" % (
                    "/".join(m.groups()[:2]), m.group(3), STATE["next"])})
            m = re.match(r"^/bb/2\.0/repositories/([^/]+)/([^/]+)/downloads$", path)
            if m:
                if not self.headers.get("Authorization", "").startswith("Basic "):
                    return self.send(401, {})
                msg = email.parser.BytesParser().parsebytes(
                    b"Content-Type: " + self.headers["Content-Type"].encode() + b"\r\n\r\n" + raw)
                for part in msg.get_payload():
                    name = part.get_filename()
                    if name:
                        with open(os.path.join(IMG_DIR, os.path.basename(name)), "wb") as out:
                            out.write(part.get_payload(decode=True))
                return self.send(201, {})
            m = re.match(r"^/bb/2\.0/repositories/([^/]+)/([^/]+)/pullrequests/(\d+)/comments$", path)
            if m:
                if not self.headers.get("Authorization", "").startswith("Basic "):
                    return self.send(401, {})
                key = self.key(*m.groups())
                body = json.loads(raw)["content"]["raw"]

                def bb_img(ref):
                    mm = re.match(r"^https://bitbucket\.org/([^/]+)/([^/]+)/downloads/(.+)$", ref)
                    return base() + "/bb/dl/%s/%s/%s" % mm.groups() if mm else ref
                STATE["next"] += 1
                STATE["comments"].setdefault(key, []).append({
                    "id": str(STATE["next"]), "user": {"login": STATE["bitbucket_actor"]}, "body": body,
                    "html": render(body, bb_img), "updated": "2026-10-22T01:00:00Z"})
                return self.send(201, {"id": STATE["next"]})
        return self.send(404, {})


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    PORT[0] = server.server_address[1]
    with open(sys.argv[1], "w") as fh:
        fh.write(str(PORT[0]))
    server.serve_forever()


main()
