#!/usr/bin/env python3
"""Disposable Bitbucket Cloud REST API 2.0 emulator for live validation.

Backs one repository with a real bare git repo (the task's origin), answers the
endpoints firstmate's PR scripts call, enforces HTTP Basic auth, performs a real
merge (merge commit or squash) into the bare repo on POST .../merge, and logs
every request. Fixture state lives in a JSON file editable through
POST /_control (merged into state).
"""
import base64, json, os, subprocess, sys, tempfile, threading, urllib.parse
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

PORT = int(sys.argv[1]); STATE_FILE = sys.argv[2]; LOG = sys.argv[3]
API = "https://api.bitbucket.org/2.0"
lock = threading.Lock()

def load():
    with open(STATE_FILE) as f: return json.load(f)
def save(s):
    with open(STATE_FILE, "w") as f: json.dump(s, f, indent=1)
def git(repo, *a, **kw):
    return subprocess.run(["git", "-C", repo, *a], capture_output=True, text=True, **kw)

def pr_record(s):
    pr = s["pr"]
    if pr["state"] == "MERGED":
        head = pr["merged_head"]
    else:
        r = git(s["repo"], "rev-parse", "--verify", "refs/heads/" + pr["source"])
        head = r.stdout.strip()
    return {"type": "pullrequest", "id": pr["id"], "state": pr["state"], "draft": pr.get("draft", False),
            "title": "demo", "source": {"branch": {"name": pr["source"]}, "commit": {"hash": head[:12], "type": "commit"}},
            "destination": {"branch": {"name": pr["dest"]}, "commit": {"hash": "0" * 12}},
            "participants": pr.get("participants", []), "close_source_branch": False,
            "links": {"html": {"href": "https://bitbucket.org/%s/pull-requests/%d" % (s["path"], pr["id"])}}}

def paginate(values, path_no_query, query, pagelen_default=1):
    page = int(query.get("page", ["1"])[0]); pagelen = pagelen_default
    chunk = values[(page - 1) * pagelen: page * pagelen]
    body = {"values": chunk, "pagelen": pagelen, "page": page, "size": len(values)}
    if page * pagelen < len(values):
        q = dict((k, v[0]) for k, v in query.items()); q["page"] = str(page + 1)
        body["next"] = API + "/" + path_no_query + "?" + urllib.parse.urlencode(q)
    return body

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def reply(self, code, obj):
        data = (json.dumps(obj) if not isinstance(obj, str) else obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)
    def handle_any(self, method):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length).decode() if length else ""
        with lock:
            s = load()
            u = urllib.parse.urlparse(self.path); q = urllib.parse.parse_qs(u.query)
            auth = self.headers.get("Authorization", "")
            ok = auth == "Basic " + base64.b64encode(s["expect_user"].encode()).decode()
            with open(LOG, "a") as f:
                f.write("%s %s auth=%s%s\n" % (method, self.path, "ok" if ok else "BAD", (" body=" + body) if body else ""))
            if u.path == "/_control" and method == "POST":
                for k, v in json.loads(body).items():
                    if k == "pr": s["pr"].update(v)
                    else: s[k] = v
                save(s); return self.reply(200, {"ok": True})
            if not ok:
                return self.reply(401, {"type": "error", "error": {"message": "Unauthorized"}})
            prefix = "/2.0/repositories/" + s["path"] + "/"
            if not u.path.startswith(prefix):
                return self.reply(404, {"type": "error", "error": {"message": "Repository not found"}})
            rest = u.path[len(prefix):]; parts = rest.split("/")
            pr = s["pr"]
            if parts[0] == "pullrequests" and len(parts) == 2 and method == "GET" and parts[1] == str(pr["id"]):
                rec = pr_record(s)
                if q.get("fields") == ["id,state"]: rec = {"id": rec["id"], "state": rec["state"]}
                return self.reply(200, rec)
            if parts[0] == "pullrequests" and len(parts) == 3 and parts[2] == "tasks":
                return self.reply(200, paginate(s.get("tasks", []), u.path[5:], q))
            if parts[0] == "pullrequests" and len(parts) == 3 and parts[2] == "merge" and method == "POST":
                if pr["state"] != "OPEN":
                    return self.reply(400, {"type": "error", "error": {"message": "You can't merge a pull request that is not open."}})
                if s.get("forge_refuses_merge"):
                    return self.reply(400, {"type": "error", "error": {"message": s["forge_refuses_merge"]}})
                req = json.loads(body or "{}")
                strategy = req.get("merge_strategy", "merge_commit")
                head = git(s["repo"], "rev-parse", "refs/heads/" + pr["source"]).stdout.strip()
                tmp = tempfile.mkdtemp(prefix="bbmerge.")
                subprocess.run(["git", "clone", "-q", s["repo"], tmp], check=True)
                g = lambda *a: subprocess.run(["git", "-C", tmp, "-c", "user.email=bb@example.invalid", "-c", "user.name=Bitbucket", *a], check=True, capture_output=True, text=True)
                g("checkout", "-q", pr["dest"])
                if strategy == "squash":
                    g("merge", "--squash", "origin/" + pr["source"]); g("commit", "-q", "-m", "Merged in %s (pull request #%d)" % (pr["source"], pr["id"]))
                else:
                    g("merge", "--no-ff", "-m", "Merged in %s (pull request #%d)" % (pr["source"], pr["id"]), "origin/" + pr["source"])
                g("push", "-q", "origin", pr["dest"])
                if req.get("close_source_branch"):
                    g("push", "-q", "origin", ":" + pr["source"])
                subprocess.run(["rm", "-rf", tmp])
                pr["state"] = "MERGED"; pr["merged_head"] = head; pr["merge_strategy_used"] = strategy
                save(s); return self.reply(200, pr_record(s))
            if parts[0] == "commit" and len(parts) == 2 and method == "GET":
                r = git(s["repo"], "rev-parse", "--verify", "--quiet", parts[1] + "^{commit}")
                if r.returncode != 0: return self.reply(404, {"type": "error", "error": {"message": "Commit not found"}})
                return self.reply(200, {"hash": r.stdout.strip()})
            if parts[0] == "commit" and len(parts) == 3 and parts[2] == "statuses":
                return self.reply(200, paginate(s.get("statuses", {}).get(parts[1], []), u.path[5:], q))
            if rest == "branch-restrictions":
                return self.reply(200, paginate(s.get("restrictions", []), u.path[5:], q, 100))
            if rest == "effective-branching-model":
                return self.reply(200, s.get("model", {"type": "effective_repo_branching_model"}))
            if rest == "effective-default-reviewers":
                return self.reply(200, paginate(s.get("default_reviewers", []), u.path[5:], q, 100))
            return self.reply(404, {"type": "error", "error": {"message": "no route " + rest}})
    def do_GET(self): self.handle_any("GET")
    def do_POST(self): self.handle_any("POST")

ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
