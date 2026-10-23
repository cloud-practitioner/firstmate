## Evidence for review

Kind: `ui+api`. PR head: `9512699506a2`.

### 1. terminal (ui)

**Purpose.** The tool refuses text with a semicolon.

**Before**

![terminal before](/home/node/.no-mistakes/evidence/01M5K1MGANF7V1TVEJY6VCTM5Y/before-terminal.png)

**After**

![terminal after](/home/node/.no-mistakes/evidence/01M5K1MGANF7V1TVEJY6VCTM5Y/after-terminal.png)

**Marks.**
- The result changed

---

### 2. save-item (api)

**Purpose.** The service saves the item after the change.

**Before**

![save-item before](/home/node/.no-mistakes/evidence/01M5K1MGANF7V1TVEJY6VCTM5Y/before-http.png)

**After**

![save-item after](/home/node/.no-mistakes/evidence/01M5K1MGANF7V1TVEJY6VCTM5Y/after-http.png)

**Marks.**
- The status and result changed

<details><summary>Before: full HTTP exchange (text)</summary>

```fm-pr-evidence-sidecar save-item before
{
  "request": {
    "body": "{\"name\": \"sample\", \"password\": \"***masked (21 chars)***\"}",
    "headers": [
      ["Host", "127.0.0.1:33829"],
      ["User-Agent", "curl/8.14.1"],
      ["Accept", "application/json"],
      ["Content-Type", "application/json"],
      ["Authorization", "***masked (25 chars)***"],
      ["Content-Length", "55"]
    ],
    "method": "POST",
    "url": "http://127.0.0.1:33829/items"
  },
  "response": {
    "body": "{\"result\": \"rejected\", \"password\": \"***masked (22 chars)***\"}",
    "headers": [
      ["Server", "BaseHTTP/0.6 Python/3.13.5"],
      ["Date", "Fri, 23 Oct 2026 03:32:50 GMT"],
      ["Content-Type", "application/json"],
      ["Set-Cookie", "***masked (22 chars)***"],
      ["Content-Length", "60"]
    ],
    "reason": "Unprocessable Content",
    "status": 422
  },
  "v": 1
}
```

</details>

<details><summary>After: full HTTP exchange (text)</summary>

```fm-pr-evidence-sidecar save-item after
{
  "request": {
    "body": "{\"name\": \"sample\", \"password\": \"***masked (21 chars)***\"}",
    "headers": [
      ["Host", "127.0.0.1:33829"],
      ["User-Agent", "curl/8.14.1"],
      ["Accept", "application/json"],
      ["Content-Type", "application/json"],
      ["Authorization", "***masked (25 chars)***"],
      ["Content-Length", "55"]
    ],
    "method": "POST",
    "url": "http://127.0.0.1:33829/items"
  },
  "response": {
    "body": "{\"result\": \"saved\", \"password\": \"***masked (22 chars)***\"}",
    "headers": [
      ["Server", "BaseHTTP/0.6 Python/3.13.5"],
      ["Date", "Fri, 23 Oct 2026 03:32:52 GMT"],
      ["Content-Type", "application/json"],
      ["Set-Cookie", "***masked (22 chars)***"],
      ["Content-Length", "57"]
    ],
    "reason": "Created",
    "status": 201
  },
  "v": 1
}
```

</details>

---

### Plain-English notes (warnings)

- item save-item purpose: word 'service' is not approved; try servicing
- item save-item before annotation purpose: word 'service' is not approved; try servicing
- item save-item after annotation purpose: word 'service' is not approved; try servicing

```fm-pr-evidence-v1
{
  "head": "9512699506a2e867f9fd2bf9633ea138c3f25320",
  "items": [
    {
      "after": {
        "annotation": {
          "labels": [
            "The result changed"
          ],
          "purpose": "The tool refuses text with a semicolon.",
          "sha256": "3679fb5d5029fc1c79b1f49ec4891688cc65f95b59305e1982626013bf2b71f9"
        },
        "sha256": "3679fb5d5029fc1c79b1f49ec4891688cc65f95b59305e1982626013bf2b71f9"
      },
      "before": {
        "annotation": {
          "labels": [
            "The result changed"
          ],
          "purpose": "The tool refuses text with a semicolon.",
          "sha256": "d899c89d6255691d695995000b9b184a5fede101b40391db019d2e2528e72653"
        },
        "sha256": "d899c89d6255691d695995000b9b184a5fede101b40391db019d2e2528e72653"
      },
      "id": "terminal",
      "kind": "ui",
      "labels": [
        "The result changed"
      ],
      "purpose": "The tool refuses text with a semicolon."
    },
    {
      "after": {
        "annotation": {
          "labels": [
            "The status and result changed"
          ],
          "purpose": "The service saves the item after the change.",
          "sha256": "abc6880ce5901487aa59d151eedef209197cafc1d3cdefa190319c94b527fe74"
        },
        "reason": "Created",
        "sha256": "abc6880ce5901487aa59d151eedef209197cafc1d3cdefa190319c94b527fe74",
        "sidecar_sha256": "7ead5b73cb03d2b8fbf33be1edef1e8880c48aa871b49d657d0150c9f38c1355",
        "status": 201
      },
      "before": {
        "annotation": {
          "labels": [
            "The status and result changed"
          ],
          "purpose": "The service saves the item after the change.",
          "sha256": "e51d1f4be0e3c19a15a1bc7d88b7db9e2d2897ffcfa70b9b4c5935b94e39c171"
        },
        "reason": "Unprocessable Content",
        "sha256": "e51d1f4be0e3c19a15a1bc7d88b7db9e2d2897ffcfa70b9b4c5935b94e39c171",
        "sidecar_sha256": "bfec245869b24b0ce472132d7960d750c67e8d51c8208fdd9c2cef4e16d02264",
        "status": 422
      },
      "id": "save-item",
      "kind": "api",
      "labels": [
        "The status and result changed"
      ],
      "purpose": "The service saves the item after the change."
    }
  ],
  "kind": "ui+api",
  "none_reason": null,
  "v": 1
}
```
