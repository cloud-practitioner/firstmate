## Evidence for review

Kind: `ui+api`. PR head: `791c507bc21d`.

### 1. text-check (ui)

**Purpose.** Use short text to explain the change.

**Before**

![text-check before](/home/node/.no-mistakes/evidence/01M5KTDVCMKC5EZ9HW8F6A74KH/ui-before.png)

**After**

![text-check after](/home/node/.no-mistakes/evidence/01M5KTDVCMKC5EZ9HW8F6A74KH/ui-after.png)

**Marks.**
- Text check changed

---

### 2. server-reply (api)

**Purpose.** Check the server reply before and after the change.

**Before**

![server-reply before](/home/node/.no-mistakes/evidence/01M5KTDVCMKC5EZ9HW8F6A74KH/api-before.png)

**After**

![server-reply after](/home/node/.no-mistakes/evidence/01M5KTDVCMKC5EZ9HW8F6A74KH/api-after.png)

**Marks.**
- The reply changed

<details><summary>Before: full HTTP exchange (text)</summary>

```fm-pr-evidence-sidecar server-reply before
{
  "request": {
    "body": "{\"name\": \"part\", \"password\": \"***masked (21 chars)***\"}",
    "headers": [
      ["Host", "127.0.0.1:42275"],
      ["User-Agent", "curl/8.14.1"],
      ["Accept", "*/*"],
      ["Content-Type", "application/json"],
      ["X-Request", "new"],
      ["Authorization", "***masked (25 chars)***"],
      ["Content-Length", "50"]
    ],
    "method": "POST",
    "url": "https://127.0.0.1:42275/items"
  },
  "response": {
    "body": "{\"result\": \"before\", \"count\": 1}",
    "headers": [
      ["Content-Type", "application/json"],
      ["Link", "</items?page=2>; rel=\"next\""],
      ["X-NoSpace", "yes"],
      ["X-Tab", "value"],
      ["X-Empty", ""],
      ["Set-Cookie", "***masked (18 chars)***"],
      ["Transfer-Encoding", "chunked"],
      ["Trailer", "X-Result"],
      ["Connection", "close"],
      ["X-Result", "complete and checked"]
    ],
    "reason": "Old reply",
    "status": 500
  },
  "v": 1
}
```

</details>

<details><summary>After: full HTTP exchange (text)</summary>

```fm-pr-evidence-sidecar server-reply after
{
  "request": {
    "body": "{\"name\": \"part\", \"password\": \"***masked (21 chars)***\"}",
    "headers": [
      ["Host", "127.0.0.1:42275"],
      ["User-Agent", "curl/8.14.1"],
      ["Accept", "*/*"],
      ["Content-Type", "application/json"],
      ["X-Request", "new"],
      ["Authorization", "***masked (25 chars)***"],
      ["Content-Length", "50"]
    ],
    "method": "POST",
    "url": "https://127.0.0.1:42275/items"
  },
  "response": {
    "body": "{\"result\": \"after\", \"count\": 2}",
    "headers": [
      ["Content-Type", "application/json"],
      ["Link", "</items?page=2>; rel=\"next\""],
      ["X-NoSpace", "yes"],
      ["X-Tab", "value"],
      ["X-Empty", ""],
      ["Set-Cookie", "***masked (18 chars)***"],
      ["Transfer-Encoding", "chunked"],
      ["Trailer", "X-Result"],
      ["Connection", "close"],
      ["X-Result", "complete and checked"]
    ],
    "reason": "New reply",
    "status": 200
  },
  "v": 1
}
```

</details>

---

```fm-pr-evidence-v1
{
  "head": "791c507bc21d52563f59e2e410087668d6ac8783",
  "items": [
    {
      "after": {
        "annotation": {
          "labels": [
            "Text check changed"
          ],
          "purpose": "Use short text to explain the change.",
          "sha256": "ed7341a81ba3d135d657b68ee99e7d2a707cb1622becac2e92f3d60e70771db5"
        },
        "sha256": "ed7341a81ba3d135d657b68ee99e7d2a707cb1622becac2e92f3d60e70771db5"
      },
      "before": {
        "annotation": {
          "labels": [
            "Text check changed"
          ],
          "purpose": "Use short text to explain the change.",
          "sha256": "c10fa59eca842167b9eca90713ab45a4772da9cfe39abf3d4995ab0fd12fe98f"
        },
        "sha256": "c10fa59eca842167b9eca90713ab45a4772da9cfe39abf3d4995ab0fd12fe98f"
      },
      "id": "text-check",
      "kind": "ui",
      "labels": [
        "Text check changed"
      ],
      "purpose": "Use short text to explain the change."
    },
    {
      "after": {
        "annotation": {
          "labels": [
            "The reply changed"
          ],
          "purpose": "Check the server reply before and after the change.",
          "sha256": "6ba10a71bb4f2c730ed85b58245883c4975f72def6c23cee05a67a3636b58779"
        },
        "reason": "New reply",
        "sha256": "6ba10a71bb4f2c730ed85b58245883c4975f72def6c23cee05a67a3636b58779",
        "sidecar_sha256": "78cab624588609b1967bd57c8b5b249d2e089260a5f9e6c184084d052176632c",
        "status": 200
      },
      "before": {
        "annotation": {
          "labels": [
            "The reply changed"
          ],
          "purpose": "Check the server reply before and after the change.",
          "sha256": "b077ec09f93a0874a128a03a543b24d144db7f36261e0d9fe63fb3b0aac406d3"
        },
        "reason": "Old reply",
        "sha256": "b077ec09f93a0874a128a03a543b24d144db7f36261e0d9fe63fb3b0aac406d3",
        "sidecar_sha256": "698778c3227e1c107d334a84d6410f35c109c645889b27d472d0f241bc586cdc",
        "status": 500
      },
      "id": "server-reply",
      "kind": "api",
      "labels": [
        "The reply changed"
      ],
      "purpose": "Check the server reply before and after the change."
    }
  ],
  "kind": "ui+api",
  "none_reason": null,
  "v": 1
}
```
