# Remote-reply live CLI evidence

All records use disposable homes, private staging directories and private process-event claim roots. No fleet, real SSH aliases, credentials, or default session were used.

## Candidate behavior

### target-continuity-ingest

Adapter exit: `3`.

```text
continuity-broken: labmate (disposable-live-check)

```

Paths remaining after adapter exit:
```json
{
  "TMPDIR": [],
  "document_staging": [],
  "lifecycle_locks": []
}
```

Relevant adapter-owned persisted state:
```json
{
  "labmate.status": "blocked [key=remote-reply-continuity-labmate] [at=1791035610]: remote reply continuity broke for labmate (disposable-live-check)\n"
}
```

### target-continuity-handle

Adapter exit: `3`.

```text
continuity-broken: labmate (disposable-live-check)
handled: remote-reply-labmate 1

```

Paths remaining after adapter exit:
```json
{
  "TMPDIR": [],
  "document_staging": [],
  "lifecycle_locks": []
}
```

Lifecycle reuse through `arm labmate`:
```text
registered: remote-reply-labmate (remote-reply)
armed: remote-reply-labmate offset=0
```

Relevant adapter-owned persisted state:
```json
{
  "labmate.status": "blocked [key=remote-reply-continuity-labmate] [at=1791035611]: remote reply continuity broke for labmate (disposable-live-check)\n",
  "procevent-inbox/remote-reply-labmate.1.handled": ""
}
```

### target-digest-ingest

Adapter exit: `1`.

```text

error: result payload bytes do not match its committed digest
```

Paths remaining after adapter exit:
```json
{
  "TMPDIR": [],
  "document_staging": [],
  "lifecycle_locks": []
}
```

Relevant adapter-owned persisted state:
```json
{}
```

### target-digest-handle

Adapter exit: `1`.

```text

error: result payload bytes do not match its committed digest
```

Paths remaining after adapter exit:
```json
{
  "TMPDIR": [],
  "document_staging": [],
  "lifecycle_locks": []
}
```

Lifecycle reuse through `arm labmate`:
```text
registered: remote-reply-labmate (remote-reply)
armed: remote-reply-labmate offset=0
```

Relevant adapter-owned persisted state:
```json
{}
```

### target-success-handle

Adapter exit: `0`.

```text
ingested: labmate appended=1 offset=39
registered: remote-reply-labmate (remote-reply)
armed: remote-reply-labmate offset=39
handled: remote-reply-labmate 1

```

Paths remaining after adapter exit:
```json
{
  "TMPDIR": [],
  "document_staging": [],
  "lifecycle_locks": []
}
```

Lifecycle reuse through `arm labmate`:
```text
registered: remote-reply-labmate (remote-reply)
armed: remote-reply-labmate offset=39
```

Relevant adapter-owned persisted state:
```json
{
  "labmate.status": "working: disposable relay verification\n",
  "procevent-inbox/remote-reply-labmate.1.handled": "",
  "remote-replies/labmate.1.ingested": "result_sha256=0bd37b9a4f97934f32a245b9e35db279ef693d7603795bcd1e07d1d7636764ae\n",
  "remote-replies/labmate.cursor": "schema=fm-remote-reply-cursor.v1\noffset=39\nprefix_sha256=9812e0f85ab58739cf74a8434b248c344cb9340737bdf21c4844559e12641def\n"
}
```

### target-sigterm-fetch-ingest

Adapter exit: `-15`.

The actual OpenSSH client connected to a private stalled loopback peer and identified itself as `SSH-2.0-OpenSSH_10.0p2 Debian-7+deb13u4`.
Interruption: SIGTERM to adapter PID after SSH connected.
Owned staging paths before interruption:
```json
{
  "TMPDIR": [
    "tmp/fm-remote-doc-reason.cHLGIs",
    "tmp/fm-remote-reply-ingest.Y0aEdD"
  ],
  "document_staging": [
    "home/data/remote-secondmates/labmate/data/proof/.remote-doc.Jg4PzF"
  ],
  "lifecycle_locks": []
}
```

Paths remaining after adapter exit:
```json
{
  "TMPDIR": [],
  "document_staging": [],
  "lifecycle_locks": []
}
```

### target-sigterm-fetch-handle

Adapter exit: `-15`.

```text

error: remote transport was unavailable while fetching data/proof/report.md
```

The actual OpenSSH client connected to a private stalled loopback peer and identified itself as `SSH-2.0-OpenSSH_10.0p2 Debian-7+deb13u4`.
Interruption: SIGTERM to adapter PID after SSH connected.
Owned staging paths before interruption:
```json
{
  "TMPDIR": [
    "tmp/fm-remote-doc-reason.CkkxM1",
    "tmp/fm-remote-reply-ingest.SBhVEH"
  ],
  "document_staging": [
    "home/data/remote-secondmates/labmate/data/proof/.remote-doc.f0DyFy"
  ],
  "lifecycle_locks": [
    "home/state/.remote-reply-lifecycle-labmate.lock",
    "home/state/.remote-reply-lifecycle-labmate.lock.owner.OYMYuy"
  ]
}
```

Paths remaining after adapter exit:
```json
{
  "TMPDIR": [],
  "document_staging": [],
  "lifecycle_locks": []
}
```

### target-sigterm-group-fetch-handle

Adapter exit: `-15`.

```text

Terminated
```

The actual OpenSSH client connected to a private stalled loopback peer and identified itself as `SSH-2.0-OpenSSH_10.0p2 Debian-7+deb13u4`.
Interruption: SIGTERM to private process group while peer stayed stalled.
Owned staging paths before interruption:
```json
{
  "TMPDIR": [
    "tmp/fm-remote-doc-reason.gr8jMC",
    "tmp/fm-remote-reply-ingest.9vspKe"
  ],
  "document_staging": [
    "home/data/remote-secondmates/labmate/data/proof/.remote-doc.VReIm4"
  ],
  "lifecycle_locks": [
    "home/state/.remote-reply-lifecycle-labmate.lock",
    "home/state/.remote-reply-lifecycle-labmate.lock.owner.vE5zvI"
  ]
}
```

Paths remaining after adapter exit:
```json
{
  "TMPDIR": [],
  "document_staging": [],
  "lifecycle_locks": []
}
```

## Base-commit differential

| Executed exit path | Base commit | Candidate |
|---|---|---|
| continuity-ingest | TMPDIR: tmp/fm-remote-reply-ingest.iBGfog | No staging or lifecycle residue |
| continuity-handle | TMPDIR: tmp/fm-remote-reply-ingest.YmLZsB; lifecycle_locks: home/state/.remote-reply-lifecycle-labmate.lock, home/state/.remote-reply-lifecycle-labmate.lock.owner.WCEqF1 | No staging or lifecycle residue |
| digest-ingest | No staging or lifecycle residue | No staging or lifecycle residue |
| digest-handle | lifecycle_locks: home/state/.remote-reply-lifecycle-labmate.lock, home/state/.remote-reply-lifecycle-labmate.lock.owner.1eXQTs | No staging or lifecycle residue |
| sigterm-fetch-ingest | TMPDIR: tmp/fm-remote-doc-reason.E003Cy, tmp/fm-remote-reply-ingest.OXUKFf | No staging or lifecycle residue |
| sigterm-fetch-handle | lifecycle_locks: home/state/.remote-reply-lifecycle-labmate.lock, home/state/.remote-reply-lifecycle-labmate.lock.owner.URSdcG | No staging or lifecycle residue |
| sigterm-group-fetch-handle | TMPDIR: tmp/fm-remote-doc-reason.gAQv4A, tmp/fm-remote-reply-ingest.Vc8qzi; lifecycle_locks: home/state/.remote-reply-lifecycle-labmate.lock, home/state/.remote-reply-lifecycle-labmate.lock.owner.2AUdBm | No staging or lifecycle residue |

The baseline direct digest rejection already cleaned its staging directory; the locked digest handler left its lifecycle lock behind. Broken continuity and interrupted direct/process-group fetches reproduced staging leaks on the base commit.

See `live-remote-reply-results.json` for complete argv, stdout/stderr, capture state, and before/after path inventories.
