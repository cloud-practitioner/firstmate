# Herdr Container Detection Fix - Live Validation Report

## Change Summary
This change fixes Herdr backend auto-detection when running in devcontainers. When Herdr launches crewmates or Pi agents in containers, `HERDR_ENV=1` is not injected (containers get fresh environment), causing backend detection to fail and silently fall back to tmux. The fix adds a fallback check for `HERDR_SOCKET_PATH` as a socket file, which is available when forwarded into containers.

### Key Implementation Details
- **File**: `bin/fm-backend.sh`
- **Function**: `fm_backend_detect()`
- **Check Order**: `$TMUX` > `HERDR_ENV` > `HERDR_SOCKET_PATH` (new) > `CMUX_WORKSPACE_ID` > ...
- **Socket Validation**: Uses strict `[ -S "$HERDR_SOCKET_PATH" ]` test (rejects non-sockets)
- **Signal Variable**: Sets `FM_BACKEND_DETECT_SIGNAL=HERDR_SOCKET_PATH` when matched

## Validation Approach
Rather than mock or stub the implementation, I ran comprehensive unit tests against the real `fm_backend_detect()` function with actual Unix domain sockets created via Python3, exercising all detection scenarios with proper test isolation.

## Test Scenarios Exercised

### Scenario 1: Valid Socket Detection (Container Primary Case)
**Intent**: Container-spawned Herdr agents without `HERDR_ENV=1` detect via socket
- **Setup**: Create real Unix domain socket, set `HERDR_SOCKET_PATH` to socket path
- **Unset**: `TMUX`, `HERDR_ENV`, `CMUX_WORKSPACE_ID`
- **Test**: `fm_backend_detect()` returns `herdr` and sets `FM_BACKEND_DETECT_SIGNAL=HERDR_SOCKET_PATH`
- **Result**: ✅ PASS

### Scenario 2: Non-Socket File Rejection (Guard Against False Positives)
**Intent**: Guard against paths that exist but are not sockets
- **Setup**: Create regular file, set `HERDR_SOCKET_PATH` to file path
- **Unset**: `TMUX`, `HERDR_ENV`, `CMUX_WORKSPACE_ID`
- **Test**: `fm_backend_detect()` returns 1 (undetected), does not match
- **Result**: ✅ PASS

### Scenario 3: Missing File Rejection (Guard Against Stale Paths)
**Intent**: Guard against HERDR_SOCKET_PATH pointing to non-existent files
- **Setup**: Set `HERDR_SOCKET_PATH` to `/path/to/nonexistent.sock`
- **Unset**: `TMUX`, `HERDR_ENV`, `CMUX_WORKSPACE_ID`
- **Test**: `fm_backend_detect()` returns 1 (undetected), does not match
- **Result**: ✅ PASS

### Scenario 4: Empty/Unset Value Rejection (Boundary Condition)
**Intent**: Ensure empty or missing `HERDR_SOCKET_PATH` doesn't trigger false detection
- **Setup 4a**: Set `HERDR_SOCKET_PATH=""` (empty string)
  - **Test**: `fm_backend_detect()` returns 1 (undetected)
  - **Result**: ✅ PASS
- **Setup 4b**: Unset `HERDR_SOCKET_PATH`
  - **Test**: `fm_backend_detect()` returns 1 (undetected)
  - **Result**: ✅ PASS

### Scenario 5: HERDR_ENV Takes Precedence (Preserve Normal Behavior)
**Intent**: Existing normal Herdr shells with `HERDR_ENV=1` are unchanged
- **Setup**: Both `HERDR_ENV=1` and valid socket set
- **Unset**: `TMUX`, `CMUX_WORKSPACE_ID`
- **Test**: `fm_backend_detect()` returns `herdr` via `HERDR_ENV`, not socket
  - Signal is `HERDR_ENV`, not `HERDR_SOCKET_PATH`
- **Result**: ✅ PASS

### Scenario 6: TMUX Takes Precedence (Innermost-First Nesting)
**Intent**: Maintain correct nesting resolution (e.g., tmux inside container with Herdr)
- **Setup**: Both `TMUX` and valid socket set
- **Unset**: `HERDR_ENV`, `CMUX_WORKSPACE_ID`
- **Test**: `fm_backend_detect()` returns `tmux`, not `herdr`
  - Signal is `TMUX`, not `HERDR_SOCKET_PATH`
- **Result**: ✅ PASS

### Scenario 7: Existing Behavior Preservation
**Intent**: No regressions in existing detection paths (precedence unchanged)
- **Setup**: Test all documented precedence combinations without `HERDR_SOCKET_PATH`
- **Tests**: 
  - HERDR_ENV=1 alone → herdr ✅
  - TMUX alone → tmux ✅
  - CMUX_WORKSPACE_ID alone → cmux ✅
  - All nesting combinations (TMUX > HERDR_ENV, TMUX > CMUX, HERDR_ENV > CMUX) ✅
- **Result**: ✅ PASS (21 total backend detection tests)

## Test Isolation Verification
Updated all existing backend detection tests to properly unset `HERDR_SOCKET_PATH`, preventing interference from test environment's inherited Herdr socket (necessary because tests run inside Herdr with `HERDR_SOCKET_PATH=/home/node/.config/herdr/herdr.sock`).

## Comments & Documentation Verification
- ✅ Line 99: Comment updated to state "HERDR_ENV=1 or HERDR_SOCKET_PATH (when a socket is available)"
- ✅ Line 137: `FM_BACKEND_DETECT_SIGNAL` list updated to include `HERDR_SOCKET_PATH`

## Live Test Execution
```bash
bash tests/fm-backend.test.sh
```

**Results**: 21 tests pass, including new `test_backend_detect_herdr_socket_fallback()`
- All existing backend detection tests: ✅ PASS
- New HERDR_SOCKET_PATH fallback test: ✅ PASS

## Risk Assessment
- **Code Changes**: Minimal, localized to one function in one file
- **Backward Compatibility**: ✅ Perfect - no breaking changes, pure additive
- **Behavioral Impact**: Only affects environments where both conditions hold:
  1. `HERDR_ENV` is not set (container environment)
  2. `HERDR_SOCKET_PATH` exists and is a valid socket file (volume-mounted or forwarded)
- **Fallback Chain**: Inserted before `CMUX_WORKSPACE_ID`, after `HERDR_ENV`, maintains full precedence

## Evidence Files
- `test-results.txt`: Detailed test execution results
- `implementation-changes.diff`: Code diff showing all changes to `bin/fm-backend.sh`
- `validation-summary.md`: This file
