## Evidence for review

Kind: `ui`. PR head: `0123456789ab`.

### 1. cli (ui)

**Purpose.** The tool printed old text. Now it prints new text.

**Before**

![cli before](https://github.com/user-attachments/assets/05c9cef7-aa4f-db7c-d843-03454d518dd5)

**After**

![cli after](https://github.com/user-attachments/assets/f69584f5-52a9-c0b4-962e-ae823f02a753)

**Marks.**
- Text changed

---

```fm-pr-evidence-v1
{
  "head": "0123456789abcdef0123456789abcdef01234567",
  "items": [
    {
      "after": {
        "annotation": {
          "labels": [
            "Text changed"
          ],
          "purpose": "The tool printed old text. Now it prints new text.",
          "sha256": "f69584f552a9c0b4962eae823f02a75301958258e3f0db17c88ee11bfab6296d"
        },
        "sha256": "f69584f552a9c0b4962eae823f02a75301958258e3f0db17c88ee11bfab6296d"
      },
      "before": {
        "annotation": {
          "labels": [
            "Text changed"
          ],
          "purpose": "The tool printed old text. Now it prints new text.",
          "sha256": "05c9cef7aa4fdb7cd84303454d518dd5936cf97765b07789e2a3b483cc53fab2"
        },
        "sha256": "05c9cef7aa4fdb7cd84303454d518dd5936cf97765b07789e2a3b483cc53fab2"
      },
      "id": "cli",
      "kind": "ui",
      "labels": [
        "Text changed"
      ],
      "purpose": "The tool printed old text. Now it prints new text."
    }
  ],
  "kind": "ui",
  "none_reason": null,
  "v": 1
}
```
