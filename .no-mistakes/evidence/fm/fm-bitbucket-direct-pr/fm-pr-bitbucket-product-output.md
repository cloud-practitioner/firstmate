## context-open-detached
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: this work tree is on a detached HEAD; check out the branch

```

## context-open-no-origin
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: this work tree has no origin remote

```

## context-open-non-bitbucket
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: the origin remote is not a Bitbucket Cloud repository

```

## context-ready-detached
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: this work tree is on a detached HEAD; check out the branch

```

## context-ready-no-origin
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: this work tree has no origin remote

```

## context-ready-non-bitbucket
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: the origin remote is not a Bitbucket Cloud repository

```

## context-ready-other-repository
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: the pull request URL does not name this work tree's origin repository

```

## context-verify-detached
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: this work tree is on a detached HEAD; check out the branch

```

## context-verify-no-origin
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: this work tree has no origin remote

```

## context-verify-non-bitbucket
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: the origin remote is not a Bitbucket Cloud repository

```

## context-verify-other-repository
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: the pull request URL does not name this work tree's origin repository

```

## create-id-missing
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```
https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### stderr
```
reusing the open pull request from fm/task-x1
state: open
draft: no
source: fm/task-x1
destination: main
head: ac426d70f943da4de8f7e197173fcf6a1e4e90a1
url: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### bb/create-body.json
```
{"title":"initial","description":"","draft":false,"source":{"branch":{"name":"fm/task-x1"}}}
```

## cred-missing
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: talking to Bitbucket requires the NO_MISTAKES_BITBUCKET_EMAIL environment variable, the NO_MISTAKES_BITBUCKET_API_TOKEN environment variable

```

## cred-rejected
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: listing the open pull requests for fm/task-x1 failed: Bitbucket answered HTTP 401 (Unauthorized)

```

## discovery-fork
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```
https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/8

```

### stderr
```
reusing the open pull request from fm/task-x1
state: open
draft: no
source: fm/task-x1
destination: main
head: 843d51d8c4689ebd893751dc8be052f4f5d65dd9
url: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/8

```

## discovery-fork-only
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```
https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### stderr
```
state: open
draft: no
source: fm/task-x1
destination: main
head: 843d51d8c4689ebd893751dc8be052f4f5d65dd9
url: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### bb/create-body.json
```
{"title":"initial","description":"","draft":false,"source":{"branch":{"name":"fm/task-x1"}}}
```

## draft
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```
state: open
draft: no
source: fm/task-x1
destination: main
head: 3f5300c45295946a55ab2e8ce233bcf415e02e35
url: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### stderr
```

```

### bb/ready-body.json
```
{"draft":false}
```

## draft-created
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
state: open
draft: yes
source: fm/task-x1
destination: main
head: a707a54834b333aa95b8caba3140c9f8551e4ace
url: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7
fm-pr-open: read-back of https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7 failed: the pull request is a draft, so it cannot be merged; run fm-pr-open.sh ready https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### bb/create-body.json
```
{"title":"initial","description":"","draft":false,"source":{"branch":{"name":"fm/task-x1"}}}
```

## identity-open-create-fork
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7 does not come from this work tree's origin repository

```

### bb/create-body.json
```
{"title":"initial","description":"","draft":false,"source":{"branch":{"name":"fm/task-x1"}}}
```

## identity-open-create-missing-repository
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7 does not come from this work tree's origin repository

```

### bb/create-body.json
```
{"title":"initial","description":"","draft":false,"source":{"branch":{"name":"fm/task-x1"}}}
```

## identity-open-create-other-branch
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7 has source branch other-branch, not fm/task-x1

```

### bb/create-body.json
```
{"title":"initial","description":"","draft":false,"source":{"branch":{"name":"fm/task-x1"}}}
```

## identity-open-reuse-fork
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7 does not come from this work tree's origin repository

```

## identity-open-reuse-missing-repository
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7 does not come from this work tree's origin repository

```

## identity-open-reuse-other-branch
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7 has source branch other-branch, not fm/task-x1

```

## identity-ready-fork
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7 does not come from this work tree's origin repository

```

## identity-ready-missing-repository
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7 does not come from this work tree's origin repository

```

## identity-ready-other-branch
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7 has source branch other-branch, not fm/task-x1

```

## identity-verify-fork
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7 does not come from this work tree's origin repository

```

## identity-verify-missing-repository
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7 does not come from this work tree's origin repository

```

## identity-verify-other-branch
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7 has source branch other-branch, not fm/task-x1

```

## open-create
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```
https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### stderr
```
state: open
draft: no
source: fm/task-x1
destination: main
head: d644160fb0740b0e6b0499921f22a10ad1fcc461
url: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### bb/create-body.json
```
{"title":"Add the \"thing\"","description":"Body with an apostrophe: it's ready.\nSecond line.","draft":false,"source":{"branch":{"name":"fm/task-x1"}}}
```

## open-reuse
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```
https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### stderr
```
reusing the open pull request from fm/task-x1
state: open
draft: no
source: fm/task-x1
destination: main
head: 3f5300c45295946a55ab2e8ce233bcf415e02e35
url: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

## origin-supported-1
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```
https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### stderr
```
state: open
draft: no
source: fm/task-x1
destination: main
head: bba0764d9dbce5c3707ccda27be3f8d36fbd8ed8
url: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### bb/create-body.json
```
{"title":"initial","description":"","draft":false,"source":{"branch":{"name":"fm/task-x1"}}}
```

## origin-supported-2
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```
https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### stderr
```
state: open
draft: no
source: fm/task-x1
destination: main
head: bba0764d9dbce5c3707ccda27be3f8d36fbd8ed8
url: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### bb/create-body.json
```
{"title":"initial","description":"","draft":false,"source":{"branch":{"name":"fm/task-x1"}}}
```

## origin-supported-3
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```
https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### stderr
```
state: open
draft: no
source: fm/task-x1
destination: main
head: bba0764d9dbce5c3707ccda27be3f8d36fbd8ed8
url: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### bb/create-body.json
```
{"title":"initial","description":"","draft":false,"source":{"branch":{"name":"fm/task-x1"}}}
```

## origin-supported-4
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```
https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### stderr
```
state: open
draft: no
source: fm/task-x1
destination: main
head: bba0764d9dbce5c3707ccda27be3f8d36fbd8ed8
url: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### bb/create-body.json
```
{"title":"initial","description":"","draft":false,"source":{"branch":{"name":"fm/task-x1"}}}
```

## origin-supported-5
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```
https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### stderr
```
state: open
draft: no
source: fm/task-x1
destination: main
head: 3b038a8d0a9f58ab734371e44cb0659136454123
url: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7

```

### bb/create-body.json
```
{"title":"initial","description":"","draft":false,"source":{"branch":{"name":"fm/task-x1"}}}
```

## pr-host
API responses here are stubbed; this is NOT live Bitbucket evidence.

## url-required
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: ready requires the pull request URL
usage: fm-pr-open.sh open | verify <pr-url> | ready <pr-url> (see --help)

```

## verify
API responses here are stubbed; this is NOT live Bitbucket evidence.

### stdout
```

```

### stderr
```
fm-pr-open: https://bitbucket.org/iqxbusiness/supplier_online_orchestration_api/pull-requests/7 has source branch other-branch, not fm/task-x1

```
