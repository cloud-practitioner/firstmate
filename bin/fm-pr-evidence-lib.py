#!/usr/bin/env python3
"""Pure helpers for bin/fm-pr-evidence.sh.

fork-only (cloud-practitioner/firstmate); never offered upstream.

bin/fm-pr-evidence.sh owns the rule, the forge calls, and the user-facing
contract. This file holds the parts that are plain data work, so tests can
drive them without a forge: the config parser, the Simplified Technical
English (STE) check, secret masking of captured HTTP exchanges, PNG mark
counting, image rendering with ImageMagick, evidence comment composition,
and the gate verifier. It uses only the Python standard library and calls
`curl` and `magick` as external tools.

Every refusal is a `[FAIL] <what>` line followed by a `FIX: <how>` line, the
way workos/case's PR gate printed them. Warnings are `[WARN] <what>` lines.
Exit status 0 means pass, 1 means refuse, 2 means a usage error.
"""
import argparse
import difflib
import hashlib
import html.parser
import json
import os
import re
import shlex
import struct
import subprocess
import sys
import tempfile
import textwrap
import xml.etree.ElementTree as ET
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
MANIFEST_TAG = "fm-pr-evidence-v1"
SIDECAR_TAG = "fm-pr-evidence-sidecar"
MARK_RGB = (0xFF, 0x2D, 0x95)  # the one exact colour of every drawn mark
MARK_MIN_PIXELS = 200
MASK_RE = re.compile(r"^\*\*\*masked \(\d+ chars\)\*\*\*$")
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,40}$")
KINDS = ("ui", "api")
FONT = "DejaVu-Sans-Mono"
FONT_PT = 14
CHAR_W = 9  # pixels per character of the 14 point monospace font, rounded up
LINE_H = 20
PAD = 12


class Findings:
    """Collects FAIL and WARN entries and prints them in the gate format."""

    def __init__(self):
        self.fails = []
        self.warns = []

    def fail(self, what, fix):
        self.fails.append((what, fix))

    def warn(self, what):
        self.warns.append(what)

    def emit(self, out=None):
        out = out or sys.stdout
        for what, fix in self.fails:
            print("[FAIL] " + what, file=out)
            print("FIX: " + fix, file=out)
        for what in self.warns:
            print("[WARN] " + what, file=out)

    def ok(self):
        return not self.fails


# --------------------------------------------------------------------------
# Simplified Technical English check
# --------------------------------------------------------------------------

BANNED_BUILTIN = (
    "seamless seamlessly robust leverage leverages leveraged leveraging "
    "utilize utilizes utilized utilizing utilise utilises utilised "
    "synergy holistic paradigm revolutionary groundbreaking cutting-edge "
    "state-of-the-art best-in-class world-class game-changer game-changing "
    "blazing blazingly streamline streamlined delve scalable turnkey "
    "bells whistles"
).split()
BANNED_PHRASES = (
    "out of the box", "under the hood", "bells and whistles", "kick off",
    "figure out", "heavy lifting", "up and running", "low-hanging fruit",
    "at the end of the day", "move the needle", "a lot of", "piece of cake",
)
CONTRACTION_RE = re.compile(
    r"\b\w+n['\u2018\u2019]t\b|\b\w+['\u2018\u2019](?:re|ve|ll|d|m)\b|\b(?:it|that|there|here|what|who|let|he|she)['\u2018\u2019]s\b",
    re.I)
ABBREV_RE = re.compile(r"(?<![\w.])(?:e\.g\.|i\.e\.|etc\b\.?|vs\b\.?|cf\.|viz\.|et al\.?|approx\.)", re.I)
BE = r"(?:is|are|was|were|be|been|being|am)"
NOT_PARTICIPLE = {"open", "even", "green", "token", "screen", "then", "when", "often",
                  "kitchen", "golden", "siren", "garden", "listen", "children", "women"}
IRREGULAR = ("done made shown given run set sent seen built written taken known found kept "
             "left lost held put read got shown begun broken chosen driven forgotten hidden "
             "spoken stolen thrown worn won paid said told").split()
PARTICIPLE = r"(?:\w+ed|\w+en|" + "|".join(IRREGULAR) + r")"
PASSIVE_RE = re.compile(r"\b" + BE + r"\s+(?:\w+ly\s+)?(" + PARTICIPLE + r")\b", re.I)
PROGRESSIVE_RE = re.compile(r"\b" + BE + r"\s+(\w+ing)\b", re.I)
PERFECT_RE = re.compile(r"\b(?:has|have|had)\s+(?:\w+ly\s+)?(?:been|" + PARTICIPLE + r")\b", re.I)
MODAL_RE = re.compile(r"\b(?:could|would|should|might|may)\b", re.I)
CONJ_RE = re.compile(r"(?:,\s*which\b|\bwhile\b|\balthough\b|\bbecause\b|\band\b|\bbut\b|\bso\b)", re.I)
QUOTED_RE = re.compile(r"`[^`]*`|\"[^\"]*\"")


def split_sentences(text):
    flat = re.sub(r"\s+", " ", text.strip())
    parts = re.split(r"(?<=[.!?])\s+", flat)
    return [p for p in parts if p]


def words_in(sentence):
    return re.findall(r"[A-Za-z0-9][A-Za-z0-9_./:#'-]*", sentence)


def load_vocab(path):
    vocab = {}
    if not path or not os.path.isfile(path):
        return vocab
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("#") or not line.strip():
                continue
            parts = line.rstrip("\n").split("\t")
            vocab[parts[0]] = parts[1] if len(parts) > 1 else ""
    return vocab


def ste_check(text, kind, vocab=None):
    """Return (fails, warns) for one purpose, label, or reason text.

    kind is purpose (descriptive text), label (a short mark label), or steps
    (procedural text). Fails are the high precision rules. Warns are heuristics.
    """
    fails, warns = [], []
    text = text or ""
    if not text.strip():
        return ["text is empty"], []
    max_words = {"purpose": 25, "steps": 20, "label": 10}[kind]
    max_sentences = {"purpose": 3, "steps": 6, "label": 1}[kind]
    sentences = split_sentences(text)
    total_words = sum(len(words_in(s)) for s in sentences)
    if kind == "purpose" and total_words < 3:
        fails.append("text has fewer than 3 words")
    if len(sentences) > max_sentences:
        fails.append("%d sentences (maximum %d)" % (len(sentences), max_sentences))
    for index, sentence in enumerate(sentences, 1):
        count = len(words_in(sentence))
        if count > max_words:
            fails.append("sentence %d has %d words (maximum %d)" % (index, count, max_words))
    if ";" in text:
        fails.append("semicolon found; write two sentences")
    for match in CONTRACTION_RE.finditer(text):
        fails.append("contraction '%s'; write the full words" % match.group(0))
    for match in ABBREV_RE.finditer(text):
        fails.append("abbreviation '%s'; write the full words" % match.group(0).strip())
    if "\u2014" in text or "\u2013" in text:
        fails.append("long dash found; use a plain dash or a new sentence")
    lowered = text.lower()
    for word in sorted(set(re.findall(r"[a-z][a-z-]*", lowered)) & set(BANNED_BUILTIN)):
        fails.append("banned word '%s'" % word)
    for phrase in BANNED_PHRASES:
        if phrase in lowered:
            fails.append("banned phrase '%s'" % phrase)
    plain = QUOTED_RE.sub(" ", text)
    for match in PASSIVE_RE.finditer(plain):
        if match.group(1).lower() not in NOT_PARTICIPLE:
            warns.append("passive voice '%s'; use active voice" % match.group(0))
    for match in PROGRESSIVE_RE.finditer(plain):
        warns.append("progressive tense '%s'; use the simple tense" % match.group(0))
    for match in PERFECT_RE.finditer(plain):
        warns.append("perfect tense '%s'; use the simple past" % match.group(0))
    for match in MODAL_RE.finditer(plain):
        warns.append("modal verb '%s'; use can, must, or will" % match.group(0))
    for index, sentence in enumerate(sentences, 1):
        conj = len(CONJ_RE.findall(QUOTED_RE.sub(" ", sentence)))
        if conj >= 2 or (conj == 1 and len(words_in(sentence)) > 15):
            warns.append("sentence %d may hold more than one idea; write one idea per sentence" % index)
    if vocab:
        seen = set()
        for sentence in sentences:
            body = QUOTED_RE.sub(" ", sentence)
            for position, word in enumerate(re.findall(r"[A-Za-z][A-Za-z-]*", body)):
                low = word.lower()
                if low in seen or word[0].isupper() and position > 0:
                    continue
                if low in vocab:
                    seen.add(low)
                    alt = vocab[low]
                    warns.append("word '%s' is not approved%s" % (low, "; try " + alt.replace(",", ", ") if alt else ""))
    return fails, warns


def cmd_ste(args):
    text = args.text if args.text is not None else open(args.file, encoding="utf-8").read()
    vocab = load_vocab(os.path.join(HERE, "fm-pr-evidence-openste.tsv"))
    fails, warns = ste_check(text, args.kind, vocab)
    f = Findings()
    for item in fails:
        f.fail("plain-English check (%s): %s" % (args.kind, item),
               "rewrite the %s in short plain sentences (ASD-STE100)" % args.kind)
    for item in warns:
        f.warn("plain-English note (%s): %s" % (args.kind, item))
    f.emit()
    return 0 if f.ok() else 1


# --------------------------------------------------------------------------
# Secret masking of captured HTTP exchanges
# --------------------------------------------------------------------------

DENY_HEADERS = {h.lower() for h in (
    "Authorization Proxy-Authorization Cookie Set-Cookie X-API-Key Api-Key X-Auth-Token "
    "X-Access-Token X-CSRF-Token X-XSRF-Token X-Amz-Security-Token X-Goog-Api-Key "
    "Ocp-Apim-Subscription-Key MYSAPSSO2").split()}
DENY_NAME_RE = re.compile(r"(?:auth|token|secret|key|session|cookie|passw|signature|credential|code_verifier|(?<![a-z0-9])(?:sig|jwt)(?![a-z0-9]))", re.I)
ALLOW_HEADERS = {h.lower() for h in (
    "Content-Type Content-Length Content-Encoding Accept Accept-Encoding Accept-Language Host "
    "User-Agent Date ETag Location Cache-Control Vary Server Connection X-Request-Id "
    "X-GitHub-Request-Id X-Accepted-OAuth-Scopes X-OAuth-Scopes X-GitHub-Api-Version-Selected "
    "X-GitHub-Media-Type Link Last-Modified Age Expires Content-Location "
    "Strict-Transport-Security X-Frame-Options X-Content-Type-Options X-XSS-Protection "
    "Referrer-Policy Content-Security-Policy Retry-After Transfer-Encoding X-Served-By "
    "X-Timer X-Cache Via Pragma If-None-Match If-Modified-Since X-GitHub-Api-Version "
    "Access-Control-Allow-Origin Access-Control-Expose-Headers").split()}
SECRET_PATTERNS = (
    re.compile(r"eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"),
    re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{8,}"),
    re.compile(r"(?i)\bBasic\s+[A-Za-z0-9+/=]{8,}"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}"),
    re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}"),
    re.compile(r"\bATATT[A-Za-z0-9_=-]{10,}"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(r"\bxox[abp]-[A-Za-z0-9-]{10,}"),
    re.compile(r"\bsk-[A-Za-z0-9]{20,}"),
)
LONG_RUN_RE = re.compile(r"[A-Za-z0-9+/_-]{48,}={0,2}")


def run_is_token(run):
    """A long run is a token unless it is hex, already masked, or a path made of plain words."""
    if re.fullmatch(r"[0-9a-fA-F]+", run) or "masked" in run:
        return False
    parts = [p for p in re.split(r"[/_+-]", run.rstrip("=")) if p]
    words = [p for p in parts if re.fullmatch(r"[a-z]{2,}|[0-9]+|[A-Z][a-z]+", p)]
    return not (len(parts) >= 4 and len(words) * 10 >= len(parts) * 7)


def mask_token(value):
    return "***masked (%d chars)***" % len(value)


def header_is_secret(name):
    low = name.lower()
    if low in DENY_HEADERS:
        return True
    if low in ALLOW_HEADERS or low.startswith("x-ratelimit-") or low.startswith("access-control-"):
        return False
    return bool(DENY_NAME_RE.search(name))


def mask_text(text):
    """Replace sensitive fields and secret-shaped substrings with mask tokens."""
    def fields(value):
        if isinstance(value, dict):
            return {k: (v if isinstance(v, str) and MASK_RE.fullmatch(v) else mask_token(str(v)))
                    if DENY_NAME_RE.search(k) else fields(v) for k, v in value.items()}
        if isinstance(value, list):
            return [fields(v) for v in value]
        if isinstance(value, str):
            return mask_text(value)
        return value

    try:
        data = json.loads(text)
    except ValueError:
        data = None
    if isinstance(data, (dict, list, str)):
        masked = fields(data)
        return json.dumps(masked, ensure_ascii=False) if masked != data else text
    header_names = "(?:" + "|".join(re.escape(name) for name in DENY_HEADERS) + ")"
    headers = re.compile(
        r"(?im)(?P<quote>[\"'])(?P<quoted_header>" + header_names + r"[ \t]*:[ \t]*)"
        r"(?P<quoted_value>(?:\\.|(?!(?P=quote))[\s\S])*)(?P=quote)"
        r"|(?<![\w-])(?P<header>" + header_names + r"[ \t]*:[ \t]*)"
        r"(?P<value>[^\r\n]*(?:\r?\n[ \t]+[^\r\n]*)*)")

    def redact_header(match):
        quote = match["quote"] or ""
        prefix = match["quoted_header"] if quote else match["header"]
        value = match["quoted_value"] if quote else match["value"]
        return quote + prefix + (value if MASK_RE.fullmatch(value.strip()) else mask_token(value)) + quote

    text = headers.sub(redact_header, text)
    for pattern in SECRET_PATTERNS:
        text = pattern.sub(lambda match: mask_token(match.group(0)), text)
    sensitive = r"[\w.-]*(?:" + DENY_NAME_RE.pattern + r")[\w.-]*"
    if re.search(r"<(?:[\w.-]+:)?" + sensitive + r"\b", text, re.I):
        try:
            root = ET.fromstring(text)
        except ET.ParseError:
            text = mask_token(text)
        else:
            changed = False
            for element in root.iter():
                if re.fullmatch(sensitive, element.tag.split("}")[-1], re.I):
                    value = "".join(element.itertext())
                    if len(element) or not MASK_RE.fullmatch(value):
                        element.text = mask_token(value)
                        element[:] = []
                        changed = True
                    for name, value in element.attrib.items():
                        if not MASK_RE.fullmatch(value):
                            element.set(name, mask_token(value))
                            changed = True
            if changed:
                text = ET.tostring(root, encoding="unicode")
    assignment = re.compile(
        r"(?i)(?<![\w-])((?:[\"']?(?:" + sensitive + r"|code(?=\s*=))[\"']?\s*[:=]\s*|--" + sensitive + r"\s+))"
        r"(\*\*\*masked \(\d+ chars\)\*\*\*|\"(?:\\.|[^\"\\])*\"|'[^']*'|[^\s&,;<>]+)")

    def assigned(match):
        value = match.group(2)
        quote = value[0] if value.startswith(('\"', "'")) else ""
        raw = value[1:-1] if quote else value
        return match.group(1) + (value if MASK_RE.fullmatch(raw) else quote + mask_token(raw) + quote)

    text = assignment.sub(assigned, text)
    text = re.sub(r"(?i)(https?://)([^/@\s]+)@", lambda m: m.group(1) + (
        m.group(2) if MASK_RE.fullmatch(m.group(2)) else mask_token(m.group(2))) + "@", text)
    def long_run(match):
        run = match.group(0)
        return mask_token(run) if run_is_token(run) else run
    return LONG_RUN_RE.sub(long_run, text)


def mask_sidecar(data):
    for side in ("request", "response"):
        part = data.get(side) or {}
        headers = []
        for name, value in part.get("headers") or []:
            headers.append([name, mask_token(value) if header_is_secret(name) and not MASK_RE.match(value) else mask_text(value)])
        part["headers"] = headers
        if "url" in part:
            part["url"] = mask_text(part["url"])
        if "body" in part:
            part["body"] = mask_text(part["body"] or "")
    return data


def sidecar_problems(data):
    """Return a list of problems with a sidecar: missing parts and unmasked secrets."""
    problems = []
    req, resp = data.get("request"), data.get("response")
    if not isinstance(req, dict) or not isinstance(resp, dict):
        return ["the request or response part is missing"]
    if not req.get("method") or not req.get("url"):
        problems.append("request method or URL is missing")
    if not req.get("headers"):
        problems.append("request headers are missing")
    if "body" not in req:
        problems.append("request body is missing")
    if not resp.get("headers"):
        problems.append("response headers are missing")
    if "body" not in resp:
        problems.append("response body is missing")
    status = resp.get("status")
    if not isinstance(status, int) or not 100 <= status <= 599:
        problems.append("response status code is missing")
    if not isinstance(resp.get("reason"), str) or not resp.get("reason"):
        problems.append("response status message is missing")
    for side, part in (("request", req), ("response", resp)):
        for name, value in part.get("headers") or []:
            if header_is_secret(name) and not MASK_RE.match(str(value)):
                problems.append("%s header %s holds a secret value" % (side, name))
    strings = []

    def walk(value):
        if isinstance(value, str):
            strings.append(value)
        elif isinstance(value, dict):
            for item in value.values():
                walk(item)
        elif isinstance(value, list):
            for item in value:
                walk(item)
    walk(data)
    for text in strings:
        if mask_text(text) != text:
            problems.append("a sensitive field or secret-shaped value is visible")
        for pattern in SECRET_PATTERNS:
            for match in pattern.finditer(text):
                if "masked" not in match.group(0):
                    problems.append("a secret-shaped value is visible (%s...)" % match.group(0)[:6])
                    break
        for match in LONG_RUN_RE.finditer(text):
            run = match.group(0)
            if run_is_token(run):
                problems.append("a long token-shaped value is visible (%s...)" % run[:6])
    seen, unique = set(), []
    for item in problems:
        if item not in seen:
            seen.add(item)
            unique.append(item)
    return unique


def status_reason(code):
    import http
    try:
        return http.HTTPStatus(code).phrase
    except ValueError:
        return "Unknown"


def cmd_sidecar_build(args):
    """Build a masked sidecar from the files one curl call wrote."""
    def read(path):
        with open(path, "rb") as fh:
            return fh.read().decode("utf-8", "replace")
    req_headers = []
    for line in read(args.verbose).splitlines():
        if line.startswith("> ") and ": " in line:
            name, value = line[2:].split(": ", 1)
            req_headers.append([name.strip(), value.strip()])
    blocks = [b for b in re.split(r"\r?\n\r?\n", read(args.resp_headers).strip()) if b.strip()]
    last = blocks[-1].splitlines() if blocks else []
    status, reason = 0, ""
    if last:
        match = re.match(r"HTTP/\S+\s+(\d{3})\s*(.*)$", last[0].strip())
        if match:
            status = int(match.group(1))
            reason = match.group(2).strip() or status_reason(status)
    resp_headers = []
    for line in last[1:]:
        if ": " in line:
            name, value = line.split(": ", 1)
            resp_headers.append([name.strip(), value.strip()])
    data = {
        "v": 1,
        "request": {"method": args.method, "url": args.url, "headers": req_headers,
                    "body": read(args.req_body) if args.req_body else ""},
        "response": {"status": status, "reason": reason, "headers": resp_headers,
                     "body": read(args.resp_body)},
    }
    mask_sidecar(data)
    write_json(args.out, data)
    return 0


def cmd_mask_file(args):
    text = sys.stdin.read() if args.stdin else open(args.file, encoding="utf-8", errors="replace").read()
    sys.stdout.write(mask_text(text))
    return 0


def cmd_scan_sidecar(args):
    try:
        data = json.load(open(args.file, encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print("[FAIL] sidecar %s cannot be read: %s" % (args.file, exc))
        print("FIX: capture the HTTP exchange again with fm-pr-evidence.sh capture-api")
        return 1
    problems = sidecar_problems(data)
    f = Findings()
    for item in problems:
        f.fail("HTTP exchange file: " + item, "capture the HTTP exchange again with fm-pr-evidence.sh capture-api")
    f.emit()
    return 0 if f.ok() else 1


# --------------------------------------------------------------------------
# PNG decoding (mark counting) and ImageMagick rendering
# --------------------------------------------------------------------------

class PngUnsupported(Exception):
    pass


def png_mark_count(data, stop_at=None):
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise PngUnsupported("not a PNG file")
    pos, idat, header = 8, [], None
    while pos + 8 <= len(data):
        length, ctype = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif ctype == b"IDAT":
            idat.append(body)
        elif ctype == b"IEND":
            break
    if header is None:
        raise PngUnsupported("no PNG header")
    width, height, depth, color, _, _, interlace = header
    if depth != 8 or interlace != 0 or color not in (0, 2, 4, 6):
        raise PngUnsupported("only non-interlaced 8-bit gray, RGB, and RGBA PNG files can be checked")
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[color]
    if color in (0, 4):
        return 0  # gray images cannot hold the mark colour
    raw = zlib.decompress(b"".join(idat))
    stride = width * channels
    prev = bytearray(stride)
    count, offset = 0, 0
    red, green, blue = MARK_RGB
    for _ in range(height):
        ftype = raw[offset]
        row = bytearray(raw[offset + 1:offset + 1 + stride])
        offset += 1 + stride
        if ftype == 1:
            for i in range(channels, stride):
                row[i] = (row[i] + row[i - channels]) & 255
        elif ftype == 2:
            for i in range(stride):
                row[i] = (row[i] + prev[i]) & 255
        elif ftype == 3:
            for i in range(stride):
                left = row[i - channels] if i >= channels else 0
                row[i] = (row[i] + ((left + prev[i]) >> 1)) & 255
        elif ftype == 4:
            for i in range(stride):
                a = row[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                row[i] = (row[i] + pred) & 255
        elif ftype != 0:
            raise PngUnsupported("bad PNG filter")
        r, g, b = row[0::channels], row[1::channels], row[2::channels]
        count += sum(1 for x, y, z in zip(r, g, b) if x == red and y == green and z == blue)
        if stop_at is not None and count >= stop_at:
            return count
        prev = row
    return count


def cmd_marks(args):
    with open(args.png, "rb") as fh:
        data = fh.read()
    try:
        count = png_mark_count(data, args.min)
    except (PngUnsupported, zlib.error, struct.error) as exc:
        print("[FAIL] image %s cannot be checked for marks: %s" % (args.png, exc))
        print("FIX: make the image with fm-pr-evidence.sh annotate-ui or annotate-api, or save it as a PNG")
        return 1
    print(count)
    return 0 if count >= args.min else 1


def run_magick(argv):
    try:
        subprocess.run(["magick"] + argv, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    except FileNotFoundError:
        print("[FAIL] ImageMagick (magick) is not installed")
        print("FIX: install ImageMagick 7, or make the annotated PNG another way and keep the mark colour #FF2D95")
        sys.exit(1)
    except subprocess.CalledProcessError as exc:
        print("[FAIL] ImageMagick failed: " + exc.stderr.decode("utf-8", "replace").strip()[:300])
        print("FIX: check the input image or text and run the command again")
        sys.exit(1)


def im_text(text):
    """Escape one line of text for ImageMagick -annotate."""
    text = text.replace("\\", "\\\\").replace("%", "%%")
    if text.startswith("@"):
        text = " " + text  # a leading @ would make ImageMagick read a file
    return text or " "


def wrap_lines(text, width_chars, hard=False):
    out = []
    for line in text.splitlines() or [""]:
        line = line.expandtabs(4)
        if len(line) <= width_chars:
            out.append(line)
        else:
            out.extend(textwrap.wrap(line, width_chars, replace_whitespace=False, drop_whitespace=False,
                                     break_long_words=True) or [""])
    return out


def draw_banner_args(purpose, width):
    chars = max(20, (width - 2 * PAD) // CHAR_W)
    lines = wrap_lines("PURPOSE: " + purpose, chars)
    height = PAD * 2 + LINE_H * len(lines)
    args = ["-size", "%dx%d" % (width, height), "xc:#1f2a44", "-font", FONT, "-pointsize", str(FONT_PT),
            "-fill", "#ffffff", "-gravity", "NorthWest"]
    for i, line in enumerate(lines):
        args += ["-annotate", "+%d+%d" % (PAD, PAD + i * LINE_H), im_text(line)]
    return args, height


def mark_args(boxes):
    """ImageMagick arguments that draw boxes and labels in the one exact mark colour."""
    args = ["-fill", "none", "-stroke", "#%02X%02X%02X" % MARK_RGB, "-strokewidth", "3", "+antialias"]
    for x, y, w, h, _ in boxes:
        args += ["-draw", "rectangle %d,%d %d,%d" % (x, y, x + w, y + h)]
    args += ["-stroke", "none", "-fill", "#%02X%02X%02X" % MARK_RGB, "-gravity", "NorthWest", "-font", FONT,
             "-pointsize", str(FONT_PT), "-antialias"]
    for x, y, w, h, label in boxes:
        if label:
            args += ["-annotate", "+%d+%d" % (max(0, x), max(0, y + h + 4)), im_text(label)]
    return args


def label_strip(labels, width):
    chars = max(20, (width - 2 * PAD) // CHAR_W)
    lines = []
    for label in labels:
        lines.extend(wrap_lines("MARK: " + label, chars))
    return lines


def render_text_with_marks(lines, marked, labels, purpose, out):
    longest = max([len(l) for l in lines] + [40])
    width = max(640, min(1800, longest * CHAR_W + 2 * PAD))
    banner, _ = draw_banner_args(purpose, width)
    strip = label_strip(labels, width)
    body_h = PAD * 2 + LINE_H * len(lines)
    body = ["-size", "%dx%d" % (width, body_h), "xc:#0d1117", "-font", FONT, "-pointsize", str(FONT_PT),
            "-fill", "#c9d1d9", "-stroke", "none", "-gravity", "NorthWest"]
    for i, line in enumerate(lines):
        body += ["-annotate", "+%d+%d" % (PAD, PAD + i * LINE_H), im_text(line)]
    body += mark_args([(4, PAD + i * LINE_H - 2, width - 8, LINE_H, "") for i in marked])
    strip_h = PAD * 2 + LINE_H * max(1, len(strip))
    strip_args = ["-size", "%dx%d" % (width, strip_h), "xc:#1f2a44", "-font", FONT, "-pointsize", str(FONT_PT),
                  "-fill", "#%02X%02X%02X" % MARK_RGB, "-stroke", "none", "-gravity", "NorthWest"]
    for i, line in enumerate(strip or [""]):
        strip_args += ["-annotate", "+%d+%d" % (PAD, PAD + i * LINE_H), im_text(line)]
    with tempfile.TemporaryDirectory() as tmp:
        parts = []
        for name, arguments in (("banner", banner), ("body", body), ("strip", strip_args)):
            path = os.path.join(tmp, name + ".png")
            run_magick(arguments + ["PNG32:" + path])
            parts.append(path)
        run_magick(parts + ["-append", "+repage", "-depth", "8", "PNG32:" + out])


def differing_lines(lines, other):
    marked = set()
    for tag, start, end, _, _ in difflib.SequenceMatcher(None, lines, other, autojunk=False).get_opcodes():
        if tag == "equal":
            continue
        if start == end and lines:
            marked.add(min(start, len(lines) - 1))
        else:
            marked.update(range(start, end))
    return sorted(marked)


def annotation_texts(args, labels):
    f = Findings()
    check_texts(f, "annotation", {"purpose": args.purpose, "labels": labels},
                load_vocab(os.path.join(HERE, "fm-pr-evidence-openste.tsv")))
    f.emit()
    return f.ok()


def save_annotation_texts(path, purpose, labels):
    write_json(path + ".annotation.json", {"sha256": sha256_file(path), "purpose": purpose, "labels": labels})


def cmd_annotate_ui(args):
    labels = args.label or []
    if not args.image and not annotation_texts(args, labels or ["Marked lines changed"]):
        return 1
    if args.image:
        boxes = []
        for spec in args.mark or []:
            parts = spec.split(",", 4)
            if len(parts) < 4 or not all(p.strip().lstrip("-").isdigit() for p in parts[:4]):
                print("[FAIL] mark '%s' is not x,y,w,h[,label]" % spec)
                print("FIX: write each mark as x,y,width,height with an optional label")
                return 1
            boxes.append((int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3]),
                          parts[4] if len(parts) > 4 else ""))
        if not boxes:
            print("[FAIL] no marks were given for the image")
            print("FIX: add at least one --mark x,y,w,h,label around the part that changed")
            return 1
        if not annotation_texts(args, labels + [b[4] for b in boxes if b[4]]):
            return 1
        try:
            ident = subprocess.run(["magick", "identify", "-format", "%w", args.image],
                                   capture_output=True, text=True)
        except FileNotFoundError:
            print("[FAIL] ImageMagick (magick) is not installed")
            print("FIX: install ImageMagick 7 and run the command again")
            return 1
        try:
            width = int(ident.stdout.strip())
        except ValueError:
            print("[FAIL] image %s cannot be read" % args.image)
            print("FIX: give a PNG or JPEG file")
            return 1
        width = max(width, 640)
        banner, _ = draw_banner_args(args.purpose + "".join("\nMARK: " + label for label in labels), width)
        with tempfile.TemporaryDirectory() as tmp:
            banner_png = os.path.join(tmp, "banner.png")
            shot = os.path.join(tmp, "shot.png")
            run_magick(banner + ["PNG32:" + banner_png])
            run_magick([args.image, "-depth", "8", "PNG32:" + shot])
            run_magick([shot] + mark_args(boxes) + ["-depth", "8", "PNG32:" + shot + ".m.png"])
            run_magick([banner_png, shot + ".m.png", "-background", "#0d1117", "-append", "+repage", "-depth", "8",
                        "PNG32:" + args.out])
        save_annotation_texts(args.out, args.purpose, labels + [b[4] for b in boxes if b[4]])
        return 0
    text = open(args.text, encoding="utf-8", errors="replace").read()
    text = mask_text(text)
    chars = 160
    lines = wrap_lines(text.rstrip("\n"), chars)
    if args.against:
        other = wrap_lines(mask_text(open(args.against, encoding="utf-8", errors="replace").read().rstrip("\n")), chars)
        marked = differing_lines(lines, other)
    else:
        marked = [int(n) for n in (args.mark_line or [])]
    if not marked:
        print("[FAIL] no differing lines to mark")
        print("FIX: the before and after text must differ, or pass --mark-line N for lines to mark")
        return 1
    if not labels:
        labels = ["Marked lines changed"]
    render_text_with_marks(lines, marked, labels, args.purpose, args.out)
    save_annotation_texts(args.out, args.purpose, labels)
    return 0


def pretty_body(text):
    try:
        return json.dumps(json.loads(text), indent=2, ensure_ascii=False).splitlines()
    except ValueError:
        return text.splitlines() or ["(empty)"]


def sidecar_lines(data):
    req, resp = data["request"], data["response"]
    out = ["REQUEST", "  %s %s" % (req["method"], req["url"]), "REQUEST HEADERS"]
    out += ["  %s: %s" % (n, v) for n, v in req["headers"]]
    out += ["REQUEST BODY"]
    out += ["  " + l for l in (pretty_body(req["body"]) if req.get("body") else ["(empty)"])]
    out += ["RESPONSE", "  STATUS CODE: %d" % resp["status"], "  STATUS MESSAGE: %s" % resp["reason"],
            "RESPONSE HEADERS"]
    out += ["  %s: %s" % (n, v) for n, v in resp["headers"]]
    out += ["RESPONSE BODY"]
    body = pretty_body(resp["body"]) if resp.get("body") else ["(empty)"]
    out += ["  " + l for l in body]
    return out


def cmd_annotate_api(args):
    labels = args.label or ["Marked lines differ from the other exchange"]
    if not annotation_texts(args, labels):
        return 1
    data = json.load(open(args.sidecar, encoding="utf-8"))
    problems = sidecar_problems(data)
    if problems:
        for item in problems:
            print("[FAIL] HTTP exchange file: " + item)
            print("FIX: capture the HTTP exchange again with fm-pr-evidence.sh capture-api")
        return 1
    chars = 160
    lines = wrap_lines("\n".join(sidecar_lines(data)), chars)
    if args.against:
        other = wrap_lines("\n".join(sidecar_lines(json.load(open(args.against, encoding="utf-8")))), chars)
        marked = differing_lines(lines, other)
    else:
        marked = []
    if not marked:
        print("[FAIL] the two HTTP exchanges show no difference to mark")
        print("FIX: capture an exchange that differs, or mark lines by hand with annotate-ui")
        return 1
    render_text_with_marks(lines, marked, labels, args.purpose, args.out)
    save_annotation_texts(args.out, args.purpose, labels)
    return 0


def cmd_capture_ui_text(args):
    """Wrap one command's captured output into a masked terminal transcript."""
    text = open(args.raw, encoding="utf-8", errors="replace").read()
    with open(args.out, "w", encoding="utf-8") as fh:
        command = mask_text(" ".join(shlex.quote(mask_text(arg)) for arg in args.command))
        fh.write("$ %s\n%s" % (command, mask_text(text)))
        if not text.endswith("\n"):
            fh.write("\n")
        fh.write("(exit status %s)\n" % args.rc)
    return 0


# --------------------------------------------------------------------------
# Config
# --------------------------------------------------------------------------

def cmd_config(args):
    """Parse config/pr-evidence for one project and print JSON."""
    out = {"enabled": False, "require": False, "globs": {"ui": [], "api": []},
           "bitbucket": False, "errors": []}
    try:
        with open(args.file, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except (OSError, UnicodeError) as exc:
        if not isinstance(exc, FileNotFoundError) or os.path.lexists(args.file):
            out["errors"].append("configuration cannot be read: %s" % exc)
        print(json.dumps(out))
        return 0
    for number, raw in enumerate(lines, 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split()
        head = parts[0]
        if head == "bitbucket" and len(parts) == 2 and parts[1] in ("on", "off"):
            out["bitbucket"] = parts[1] == "on"
        elif len(parts) >= 2 and (head == "*" or head == args.project):
            word = parts[1]
            if word == "enforce" and len(parts) == 2:
                out["enabled"] = True
            elif word == "require" and len(parts) == 2:
                out["require"] = True
            elif word in KINDS and len(parts) > 2:
                out["globs"][word] += parts[2:]
            else:
                out["errors"].append("line %d is not valid: %s" % (number, line))
        elif len(parts) >= 2 and parts[1] in ("enforce", "require") + KINDS:
            pass  # a line for another project
        else:
            out["errors"].append("line %d is not valid: %s" % (number, line))
    print(json.dumps(out))
    return 0


# --------------------------------------------------------------------------
# Manifest, comment composition, and the gate verifier
# --------------------------------------------------------------------------

def write_json(path, data):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, sort_keys=True, ensure_ascii=False)
        fh.write("\n")


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


PAIR_RE = re.compile(r'\[\n\s+("(?:[^"\\]|\\.)*"),\n\s+("(?:[^"\\]|\\.)*")\n\s+\]')


def sidecar_text(data):
    """Stable JSON text of a sidecar, with each header on one line."""
    text = json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False)
    return PAIR_RE.sub(lambda m: "[%s, %s]" % (m.group(1), m.group(2)), text)


def hex64(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def kinds_of(spec):
    spec = (spec or "").strip()
    if spec.startswith("none"):
        return []
    return [k for k in spec.split("+") if k]


def declaration(kinds):
    return "+".join(k for k in KINDS if k in kinds) or "none"


def effective_declaration(declared, comments, authors):
    kinds = set(kinds_of(declared))
    for comment in comments:
        if comment.get("author") not in authors:
            continue
        for info, text in FENCE_RE.findall(comment.get("body") or ""):
            if info.strip() != MANIFEST_TAG:
                continue
            try:
                manifest = json.loads(text)
                kinds.update(k for k in kinds_of(manifest.get("kind")) if k in KINDS)
                kinds.update(i.get("kind") for i in manifest.get("items", []) if i.get("kind") in KINDS)
            except (ValueError, TypeError, AttributeError):
                continue
    return declaration(kinds)


def cmd_effective(args):
    print(effective_declaration(args.declared, json.load(open(args.comments, encoding="utf-8")),
                                json.loads(args.authors)))
    return 0


def check_texts(f, item_id, item, vocab):
    fails, warns = ste_check(item.get("purpose", ""), "purpose", vocab)
    for entry in fails:
        f.fail("item %s purpose: %s" % (item_id, entry), "rewrite the purpose in short plain sentences (ASD-STE100)")
    for entry in warns:
        f.warn("item %s purpose: %s" % (item_id, entry))
    for label in item.get("labels") or []:
        fails, warns = ste_check(label, "label", vocab)
        for entry in fails:
            f.fail("item %s mark label '%s': %s" % (item_id, label, entry),
                   "rewrite the label in one short plain sentence")
        for entry in warns:
            f.warn("item %s mark label '%s': %s" % (item_id, label, entry))


def cmd_compose(args):
    """Validate worker input and write the evidence comment text."""
    f = Findings()
    spec = json.load(open(args.items, encoding="utf-8"))
    base = os.path.dirname(os.path.abspath(args.items))
    vocab = load_vocab(os.path.join(HERE, "fm-pr-evidence-openste.tsv"))
    required = set(kinds_of(args.declared))
    items = spec.get("items") or []
    none_reason = (spec.get("none_reason") or args.default_none_reason or "").strip()
    manifest_items, attachments, sections, seen_ids = [], [], [], set()
    if not items and not required:
        if not none_reason:
            f.fail("the change kind is none, but no reason is given", "set none_reason in the items file")
        else:
            fails, warns = ste_check(none_reason, "purpose", vocab)
            for entry in fails:
                f.fail("none_reason: " + entry, "rewrite the reason in short plain sentences (ASD-STE100)")
            for entry in warns:
                f.warn("none_reason: " + entry)
    if not items and required:
        f.fail("no evidence items are given for the kinds: " + ", ".join(sorted(required)),
               "add one item for each required kind to the items file")
    present = set()
    for number, item in enumerate(items, 1):
        item_id = item.get("id", "")
        if not ID_RE.match(item_id) or item_id in seen_ids:
            f.fail("item %d has a bad or repeated id '%s'" % (number, item_id),
                   "use a short unique id of lower-case letters, digits, and dashes")
            continue
        seen_ids.add(item_id)
        kind = item.get("kind")
        if kind not in KINDS:
            f.fail("item %s has kind '%s'" % (item_id, kind), "use ui or api")
            continue
        present.add(kind)
        check_texts(f, item_id, item, vocab)
        entry = {"id": item_id, "kind": kind, "purpose": item.get("purpose", "").strip(),
                 "labels": item.get("labels") or []}
        side_md = []
        shas = []
        for phase in ("before", "after"):
            part = item.get(phase) or {}
            image = part.get("image", "")
            image = image if os.path.isabs(image) else os.path.join(base, image)
            if not os.path.isfile(image):
                f.fail("item %s %s image is missing: %s" % (item_id, phase, part.get("image")),
                       "capture the %s image and name it in the items file" % phase)
                continue
            sha = sha256_file(image)
            shas.append(sha)
            try:
                with open(image, "rb") as fh:
                    marks = png_mark_count(fh.read(), MARK_MIN_PIXELS)
            except (PngUnsupported, zlib.error, struct.error) as exc:
                f.fail("item %s %s image cannot be checked for marks: %s" % (item_id, phase, exc),
                       "make the image with annotate-ui or annotate-api and save it as a PNG")
                marks = None
            if marks is not None and marks < MARK_MIN_PIXELS:
                f.fail("item %s %s image has no drawn marks (colour #FF2D95)" % (item_id, phase),
                       "annotate the difference with fm-pr-evidence.sh annotate-ui or annotate-api")
            part_entry = {"sha256": sha}
            if os.path.isfile(image + ".annotation.json"):
                with open(image + ".annotation.json", encoding="utf-8") as fh:
                    annotation = json.load(fh)
                if annotation.get("sha256") != sha:
                    f.fail("item %s %s annotation does not match its image" % (item_id, phase),
                           "annotate the image again")
                check_texts(f, "%s %s annotation" % (item_id, phase), annotation, vocab)
                part_entry["annotation"] = annotation
            if kind == "api":
                sidecar_path = part.get("sidecar", "")
                sidecar_path = sidecar_path if os.path.isabs(sidecar_path) else os.path.join(base, sidecar_path)
                try:
                    data = json.load(open(sidecar_path, encoding="utf-8"))
                except (OSError, ValueError):
                    f.fail("item %s %s HTTP exchange file is missing or not JSON" % (item_id, phase),
                           "capture it with fm-pr-evidence.sh capture-api and name it as sidecar")
                    data = None
                if data is not None:
                    for problem in sidecar_problems(data):
                        f.fail("item %s %s HTTP exchange: %s" % (item_id, phase, problem),
                               "capture the exchange again with fm-pr-evidence.sh capture-api")
                    text = sidecar_text(data)
                    part_entry["sidecar_sha256"] = hashlib.sha256(text.encode("utf-8")).hexdigest()
                    part_entry["status"] = data["response"].get("status")
                    part_entry["reason"] = data["response"].get("reason")
                    side_md.append((phase, text))
            alt = "%s %s" % (item_id, phase)
            if args.provider == "bitbucket":
                name = "fm-evidence-%s-%s-%s-%s.png" % (args.number, args.head[:12], item_id, phase)
                ref = "https://bitbucket.org/%s/downloads/%s" % (args.repo, name)
            else:
                ref = image
            attachments.append({"path": image, "alt": alt, "name": "fm-evidence-%s-%s-%s-%s.png" % (
                args.number, args.head[:12], item_id, phase)})
            entry[phase] = part_entry
            part_entry["_md"] = "![%s](%s)" % (alt, ref)
        if len(shas) == 2 and shas[0] == shas[1]:
            f.fail("item %s before and after images are the same file" % item_id,
                   "take the before image before the change and the after image after it")
        manifest_items.append(entry)
        sections.append((number, entry, side_md))
    missing = required - present
    if missing:
        f.fail("no evidence item for the required kinds: " + ", ".join(sorted(missing)),
               "add an item for each missing kind to the items file")
    if not f.ok():
        f.emit()
        return 1
    effective = declaration(required | present)
    lines = ["## Evidence for review", "",
             "Kind: `%s`. PR head: `%s`." % (effective, args.head[:12]), ""]
    if not items:
        lines += ["No UI or API surface changed. Reason: %s" % none_reason, ""]
    for number, entry, side_md in sections:
        lines += ["### %d. %s (%s)" % (number, entry["id"], entry["kind"]), "",
                  "**Purpose.** " + entry["purpose"], ""]
        for phase in ("before", "after"):
            lines += ["**%s**" % phase.capitalize(), "", entry[phase]["_md"], ""]
        if entry["labels"]:
            lines += ["**Marks.**"] + ["- " + l for l in entry["labels"]] + [""]
        for phase, text in side_md:
            fence = "```%s %s %s" % (SIDECAR_TAG, entry["id"], phase)
            if args.provider == "github":
                lines += ["<details><summary>%s: full HTTP exchange (text)</summary>" % phase.capitalize(), "",
                          fence, text, "```", "", "</details>", ""]
            else:
                lines += ["%s: full HTTP exchange (text)" % phase.capitalize(), "", fence, text, "```", ""]
        lines += ["---", ""]
    if f.warns:
        lines += ["### Plain-English notes (warnings)", ""] + ["- " + w for w in f.warns] + [""]
    for entry in manifest_items:
        for phase in ("before", "after"):
            entry[phase].pop("_md", None)
    manifest = {"v": 1, "head": args.head, "kind": effective, "items": manifest_items,
                "none_reason": none_reason or None}
    lines += ["```" + MANIFEST_TAG, json.dumps(manifest, indent=2, sort_keys=True, ensure_ascii=False), "```", ""]
    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "comment.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    with open(os.path.join(args.out, "attach.tsv"), "w", encoding="utf-8") as fh:
        for a in attachments:
            fh.write("%s\t%s\t%s\n" % (a["path"], a["alt"], a["name"]))
    f.emit()
    return 0


class ImgParser(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.images = []

    def handle_starttag(self, tag, attrs):
        if tag == "img":
            attrs = dict(attrs)
            if attrs.get("src"):
                self.images.append((attrs.get("alt", ""), attrs["src"]))


MD_IMG_RE = re.compile(r"!\[[^\]]*\]\(\s*<?([^)\s>]+)>?[^)]*\)")
FENCE_RE = re.compile(r"^```([^\n`]*)\n(.*?)\n```[ \t]*$", re.M | re.S)
GH_ATTACH_RE = re.compile(r"^https://github\.com/user-attachments/assets/[0-9a-fA-F-]{36}$")


def fetch(url, creds=None):
    """Fetch one URL with curl. Return (status, content_type, bytes)."""
    with tempfile.NamedTemporaryFile(delete=False) as tmp:
        path = tmp.name
    try:
        cmd = ["curl", "-sS", "-L", "--max-time", "30", "--max-filesize", str(20 * 1024 * 1024),
               "-o", path, "-w", "%{http_code} %{content_type}"]
        stdin = None
        if creds and re.match(r"^https://(?:api\.)?bitbucket\.org/", url):
            cmd += ["-K", "-"]
            stdin = 'user = "%s"\n' % creds.replace("\\", "\\\\").replace('"', '\\"')
        proc = subprocess.run(cmd + [url], input=stdin, capture_output=True, text=True)
        if proc.returncode != 0:
            return 0, "", b""
        code, _, ctype = proc.stdout.partition(" ")
        with open(path, "rb") as fh:
            return int(code or 0), ctype.strip(), fh.read()
    finally:
        os.unlink(path)


def cmd_verify(args):
    f = Findings()
    work = args.work
    pr = json.load(open(os.path.join(work, "pr.json"), encoding="utf-8"))
    comments = json.load(open(os.path.join(work, "comments.json"), encoding="utf-8"))
    rules = json.load(open(os.path.join(work, "rules.json"), encoding="utf-8"))
    vocab = load_vocab(os.path.join(HERE, "fm-pr-evidence-openste.tsv"))
    rules["declared"] = effective_declaration(rules["declared"], comments, set(pr.get("authors", [])))
    declared = kinds_of(rules["declared"])
    require = rules.get("require", False)
    base_fix = "run fm-pr-evidence.sh publish for this PR"
    # Declaration against the project rules and the changed files.
    if not declared and rules["declared"].startswith("none") and require:
        f.fail("this project always needs evidence, but the change kind is none",
               "firstmate must declare ui, api, or ui+api in the task brief")
    for kind, patterns in (rules.get("globs") or {}).items():
        hits = [p for p in pr.get("files", []) if any(glob_match(p, g) for g in patterns)]
        if hits and kind not in declared:
            f.fail("changed files match the %s patterns but the declared kind is %s: %s" % (
                kind, rules["declared"], ", ".join(hits[:8])),
                "firstmate fixes the declared kind for this task, or the captain waives the gate in words")
    eligible = [comment for comment in comments if comment.get("author") in pr.get("authors", [])
                and ("```" + MANIFEST_TAG) in (comment.get("body") or "")]
    if not eligible:
        f.fail("no evidence comment by %s was found on the PR" % "/".join(pr.get("authors", [])) ,
               base_fix + " (one comment with before and after evidence)")
        f.emit()
        return 1
    if len(eligible) != 1:
        f.fail("the PR holds %d evidence comments by its author (it needs exactly 1)" % len(eligible),
               "remove the older evidence comments, then run the check again")
        f.emit()
        return 1
    comment = eligible[0]
    body = (comment.get("body") or "").replace("\r\n", "\n")
    fences = FENCE_RE.findall(body)
    manifests = [text for info, text in fences if info.strip() == MANIFEST_TAG]
    if len(manifests) != 1:
        f.fail("the evidence comment holds %d manifest blocks (it needs exactly 1)" % len(manifests), base_fix)
        f.emit()
        return 1
    try:
        manifest = json.loads(manifests[0])
    except ValueError:
        f.fail("the evidence manifest is not valid JSON", base_fix)
        f.emit()
        return 1
    if manifest.get("v") != 1 or not isinstance(manifest.get("items"), list):
        f.fail("the evidence manifest has the wrong schema", base_fix)
        f.emit()
        return 1
    if manifest.get("head") != pr.get("head"):
        f.fail("the evidence is for head %s but the PR head is %s" % (
            str(manifest.get("head"))[:12], str(pr.get("head"))[:12]),
            "the PR changed after the evidence; run fm-pr-evidence.sh publish again for the current head")
    items = manifest["items"]
    if not declared:
        reason = (manifest.get("none_reason") or "").strip()
        if not reason:
            f.fail("the change kind is none, but the evidence comment gives no reason", base_fix)
        else:
            fails, warns = ste_check(reason, "purpose", vocab)
            for entry in fails:
                f.fail("none reason: " + entry, "rewrite the reason in short plain sentences (ASD-STE100)")
            for entry in warns:
                f.warn("none reason: " + entry)
    kinds_seen = {}
    shas = []
    visible = FENCE_RE.sub("", body)
    side_blocks = {}
    for info, text in fences:
        parts = info.split()
        if parts and parts[0] == SIDECAR_TAG and len(parts) == 3:
            side_blocks[(parts[1], parts[2])] = text
    for item in items:
        item_id = item.get("id", "?")
        kind = item.get("kind")
        if kind not in KINDS:
            f.fail("item %s has kind '%s'" % (item_id, kind), base_fix)
            continue
        kinds_seen.setdefault(kind, []).append(item_id)
        check_texts(f, item_id, item, vocab)
        purpose = (item.get("purpose") or "").strip()
        if purpose and purpose not in visible:
            f.fail("item %s purpose is not in the visible comment text" % item_id, base_fix)
        pair = []
        for phase in ("before", "after"):
            part = item.get(phase) or {}
            if not hex64(part.get("sha256")):
                f.fail("item %s %s has no image hash" % (item_id, phase), base_fix)
                continue
            pair.append(part["sha256"])
            shas.append((item_id, phase, part["sha256"]))
            if "annotation" in part:
                check_texts(f, "%s %s annotation" % (item_id, phase), part["annotation"], vocab)
            if kind == "api":
                block = side_blocks.get((item_id, phase))
                if block is None:
                    f.fail("item %s %s has no HTTP exchange text in the comment" % (item_id, phase), base_fix)
                    continue
                if hashlib.sha256(block.encode("utf-8")).hexdigest() != part.get("sidecar_sha256"):
                    f.fail("item %s %s HTTP exchange text does not match its hash" % (item_id, phase), base_fix)
                try:
                    data = json.loads(block)
                except ValueError:
                    f.fail("item %s %s HTTP exchange text is not JSON" % (item_id, phase), base_fix)
                    continue
                for problem in sidecar_problems(data):
                    f.fail("item %s %s HTTP exchange: %s" % (item_id, phase, problem),
                           "capture the exchange again with fm-pr-evidence.sh capture-api, then publish again")
        if len(pair) == 2 and pair[0] == pair[1]:
            f.fail("item %s before and after images are the same file" % item_id,
                   "take the before image before the change and the after image after it")
    for kind in declared:
        if kind not in kinds_seen:
            f.fail("no evidence item of kind %s" % kind, "add one item of kind %s and publish again" % kind)
    needed = 2 * len(items)
    if needed:
        verify_images(f, pr, comment, body, shas, needed, base_fix)
    f.emit()
    if f.ok():
        print("[PASS] evidence gate: %d item(s), head %s, comment %s" % (
            len(items), str(pr.get("head"))[:12], comment.get("id")))
        return 0
    return 1


def glob_match(path, pattern):
    import fnmatch
    return fnmatch.fnmatchcase(path, pattern)


def verify_images(f, pr, comment, body, shas, needed, base_fix):
    raw_urls = MD_IMG_RE.findall(FENCE_RE.sub("", body))
    repo = pr.get("repo", "")
    if pr.get("provider") == "bitbucket":
        ok_re = re.compile(r"^https://bitbucket\.org/%s/downloads/[^/\s]+$" % re.escape(repo))
        where = "the repository Downloads area"
    else:
        ok_re = GH_ATTACH_RE
        where = "GitHub attachments (https://github.com/user-attachments/assets/...)"
    bad = [u for u in raw_urls if not ok_re.match(u)]
    if bad:
        f.fail("an image in the comment is not hosted in %s: %s" % (where, bad[0][:80]),
               "upload the images with fm-pr-evidence.sh publish")
    if len(raw_urls) < needed:
        f.fail("the comment text holds %d images but the manifest lists %d" % (len(raw_urls), needed), base_fix)
    parser = ImgParser()
    parser.feed(comment.get("html") or "")
    shown = parser.images
    if len(shown) < needed:
        f.fail("the comment text holds %d image(s) but only %d show on the PR page" % (len(raw_urls), len(shown)),
               "an image line right after a closing </details> line does not show; put a blank line and text "
               "between them, or run fm-pr-evidence.sh publish, which writes a layout that shows")
        return
    creds = None
    if os.environ.get("NO_MISTAKES_BITBUCKET_EMAIL") and os.environ.get("NO_MISTAKES_BITBUCKET_API_TOKEN"):
        creds = "%s:%s" % (os.environ["NO_MISTAKES_BITBUCKET_EMAIL"], os.environ["NO_MISTAKES_BITBUCKET_API_TOKEN"])
    for item_id, phase, sha in shas:
        label = "%s %s" % (item_id, phase)
        refs = [src for alt, src in shown if alt == label]
        if len(refs) != 1:
            f.fail("item %s image must show exactly once with its phase label" % label, base_fix)
            continue
        code, ctype, data = fetch(refs[0], creds)
        if code != 200 or not ctype.lower().startswith("image/") or not (
                data.startswith(b"\x89PNG\r\n\x1a\n") or data.startswith(b"\xff\xd8\xff")):
            f.fail("a shown image did not load as an image (HTTP %s, %s)" % (code, ctype or "no type"),
                   "publish the evidence again with fm-pr-evidence.sh publish")
            continue
        if hashlib.sha256(data).hexdigest() != sha:
            f.fail("item %s %s image shown on the page does not match its hash" % (item_id, phase), base_fix)
            continue
        try:
            marks = png_mark_count(data, MARK_MIN_PIXELS)
        except (PngUnsupported, zlib.error, struct.error) as exc:
            f.fail("item %s %s image cannot be checked for marks: %s" % (item_id, phase, exc),
                   "make the image with annotate-ui or annotate-api, then publish again")
            continue
        if marks < MARK_MIN_PIXELS:
            f.fail("item %s %s image has no drawn marks (colour #FF2D95)" % (item_id, phase),
                   "annotate the difference with annotate-ui or annotate-api, then publish again")


def main(argv):
    parser = argparse.ArgumentParser(prog="fm-pr-evidence-lib.py")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("ste")
    p.add_argument("--kind", default="purpose", choices=("purpose", "label", "steps"))
    p.add_argument("--text")
    p.add_argument("--file")

    p.set_defaults(fn=cmd_ste)

    p = sub.add_parser("sidecar-build")
    for name in ("verbose", "resp-headers", "resp-body", "method", "url", "out"):
        p.add_argument("--" + name, required=True)
    p.add_argument("--req-body")
    p.set_defaults(fn=cmd_sidecar_build)

    p = sub.add_parser("mask")
    p.add_argument("--file")
    p.add_argument("--stdin", action="store_true")
    p.set_defaults(fn=cmd_mask_file)

    p = sub.add_parser("scan-sidecar")
    p.add_argument("file")
    p.set_defaults(fn=cmd_scan_sidecar)

    p = sub.add_parser("marks")
    p.add_argument("png")
    p.add_argument("--min", type=int, default=MARK_MIN_PIXELS)
    p.set_defaults(fn=cmd_marks)

    p = sub.add_parser("annotate-ui")
    p.add_argument("--image")
    p.add_argument("--text")
    p.add_argument("--against")
    p.add_argument("--mark", action="append")
    p.add_argument("--mark-line", action="append")
    p.add_argument("--label", action="append")
    p.add_argument("--purpose", required=True)
    p.add_argument("--out", required=True)
    p.set_defaults(fn=cmd_annotate_ui)

    p = sub.add_parser("annotate-api")
    p.add_argument("--sidecar", required=True)
    p.add_argument("--against")
    p.add_argument("--label", action="append")
    p.add_argument("--purpose", required=True)
    p.add_argument("--out", required=True)
    p.set_defaults(fn=cmd_annotate_api)

    p = sub.add_parser("capture-text")
    p.add_argument("--raw", required=True)
    p.add_argument("--command", nargs=argparse.REMAINDER, required=True)
    p.add_argument("--rc", required=True)
    p.add_argument("--out", required=True)
    p.set_defaults(fn=cmd_capture_ui_text)

    p = sub.add_parser("config")
    p.add_argument("file")
    p.add_argument("project")
    p.set_defaults(fn=cmd_config)

    p = sub.add_parser("compose")
    for name in ("items", "head", "declared", "provider", "repo", "number", "out"):
        p.add_argument("--" + name, required=True)
    p.add_argument("--default-none-reason")
    p.set_defaults(fn=cmd_compose)

    p = sub.add_parser("effective")
    p.add_argument("--declared", required=True)
    p.add_argument("--comments", required=True)
    p.add_argument("--authors", required=True)
    p.set_defaults(fn=cmd_effective)

    p = sub.add_parser("verify")
    p.add_argument("--work", required=True)
    p.set_defaults(fn=cmd_verify)

    args = parser.parse_args(argv)
    if args.cmd == "ste" and args.text is None and not args.file:
        parser.error("ste needs --text or --file")
    if args.cmd == "annotate-ui" and not args.image and not args.text:
        parser.error("annotate-ui needs --image or --text")
    if args.cmd == "mask" and not args.stdin and not args.file:
        parser.error("mask needs --file or --stdin")
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
