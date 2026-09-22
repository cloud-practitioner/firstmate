# Bitbucket Cloud PR Support - Validation Summary

## Change Overview
This change adds Bitbucket Cloud as a third PR provider alongside GitHub and GitLab to the upstream firstmate repository. The implementation includes:
- URL parsing for Bitbucket Cloud PR links
- REST API v2.0 integration via curl+jq  
- Bearer token authentication via curl config file (security: not exposed on argv)
- Poll and merge support with green-status merge policy
- Async 202 confirm-merged handling
- Comprehensive documentation

## Validation Approach
All scenarios were driven against the real product code through a comprehensive unit test suite (`tests/fm-pr-bitbucket.test.sh`) with mocked HTTP responses. The tests cover:
- URL parsing and validation
- Token resolution (ambient environment + .env fallback)
- PR state reading
- Commit status validation
- Pre-merge conditions
- Synchronous and asynchronous merge handling
- Head consistency verification

## Test Results
**Total: 16/16 scenarios passed**

### URL Parsing (2 scenarios)
✓ Parser correctly tags canonical Bitbucket PR URLs
✓ Parser rejects malformed URLs (uppercase host, zero-padded numbers, missing segments, GitLab-shaped paths)

### Token Resolution (3 scenarios)
✓ Ambient environment variable wins over .env file
✓ .env fallback resolves tokens (supports export prefix and quoting)
✓ Missing token is cleanly refused (never attempts unauthenticated request)

### PR Record Reading (3 scenarios)
✓ Successfully reads open pull request state
✓ Correctly identifies merged state (merged=true only for state=MERGED)
✓ Non-2xx HTTP status results in clean refusal

### Pre-Merge Validation (4 scenarios)
✓ Non-open pull request is refused before calling forge
✓ FAILED commit status is refused
✓ INPROGRESS commit status is refused (not green)
✓ Zero commit statuses reported is refused (not vacuously green)

### Merge Execution (4 scenarios)
✓ Green, open Bitbucket PR merges synchronously with confirmation
✓ --squash flag correctly selects squash merge strategy
✓ Asynchronous (202) merge response leaves poll armed until confirmation
✓ Moving head between verification and merge is refused (race protection)

## Code Quality Verification
- All scripts pass syntax validation (bash -n)
- Implementation follows existing GitHub/GitLab patterns
- Consistent error handling and messaging
- Comprehensive inline documentation
- Proper temp file cleanup (chmod 600, removed immediately)

## Documentation Verification
✓ docs/bitbucket-backend.md created with 79 lines of detailed documentation
✓ Registered in docs/documentation-audiences.json with "operator-current" audience
✓ Referenced from README.md documentation section
✓ Referenced from docs/architecture.md with merge behavior details

## Security Considerations
✓ Bearer token passed via curl config file, not command-line arguments
✓ Config file created with chmod 600 permissions
✓ Config file removed immediately after curl call
✓ Token absent is a clean refusal (no unauthenticated requests)
✓ URL validation prevents GitLab-shaped paths under bitbucket.org
✓ Slug validation prevents invalid workspace/repository identifiers

## Implementation Details Verified

### Token Resolution
- Reads from FM_BITBUCKET_TOKEN environment variable first
- Falls back to FM_BITBUCKET_TOKEN= line in home/.env (supports export and quoting)
- Same pattern as existing Relay pairing token and mail-plane credentials

### API Integration  
- Two authenticated GET endpoints:
  - /repositories/{workspace}/{repo}/pullrequests/{id} (PR state)
  - /repositories/{workspace}/{repo}/commit/{sha}/statuses (commit statuses)
- One authenticated POST endpoint:
  - /repositories/{workspace}/{repo}/pullrequests/{id}/merge (merge)

### Green-Status Policy
- Every present commit status must be SUCCESSFUL
- No FAILED, STOPPED, or INPROGRESS statuses allowed
- At least one status must have reported (not vacuously green)
- Mirrors GitLab's refusal of null pipeline

### Merge Behavior
- Supports merge strategies: merge_commit (default), squash, fast_forward, squash_fast_forward, rebase_fast_forward, rebase_merge
- No head-SHA precondition, so head is re-verified immediately before merge call
- Merge may return 200 (synchronous) or 202 (asynchronous)
- Both treated identically: one re-read confirms state=MERGED before reporting landed
- Unconfirmed results leave poll armed for eventual confirmation

### Poll Implementation
- Standalone watcher uses curl+jq directly (no CLI dependency like gh/glab)
- Resolves FM_HOME from environment or script path
- Same token resolution logic as merge/check scripts
- Silence on every error (not interpreted as "not merged")

## Compatibility
- No breaking changes to existing GitHub or GitLab functionality
- URL parsing matrix expanded to include Bitbucket URLs
- Pre-merge condition validation reuses existing patterns
- Poll and merge paths maintain backward compatibility

## Testing Infrastructure
- Bitbucket-specific unit tests isolated in tests/fm-pr-bitbucket.test.sh
- Integrated into broader URL parsing matrix in tests/fm-pr-check-security.test.sh
- All tests self-contained with mocked curl/jq (no external API calls)
- Repeatable and deterministic
