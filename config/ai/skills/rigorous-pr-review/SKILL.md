---
name: rigorous-pr-review
description: Use when conducting a comprehensive code review on a pull request, branch diff, or staged changes before merging or submitting code.
---

# Rigorous Code Review Playbook

This skill outlines the standard checklist and evaluation procedure for reviewing pull requests, branch differences, or staged git changes.

---

## Step 1: Inspect Scope and Diff

1. Determine the target base branch (default: `main` or `master`):
   ```bash
   git diff origin/main...HEAD --stat
   ```
2. For uncommitted working-tree changes:
   ```bash
   git diff HEAD --stat
   ```
3. Read the full diff for all modified and newly created files.

---

## Step 2: Review Pillars Checklist

Evaluate changes against each of the following dimensions:

### 1. Security & Secrets (Zero Tolerance)
- [ ] No hardcoded credentials, API keys, private keys, session tokens, or personal identifiers.
- [ ] No internal corporate hostnames or private network addresses in public-facing configs.
- [ ] Input validation: sanitize user-provided or external inputs (SQL injection, command injection, path traversal).
- [ ] File permissions: ensure sensitive files (e.g. `.ssh/config`, private keys) are restricted (e.g., `chmod 600`).

### 2. Correctness, Robustness & Edge Cases
- [ ] Null/undefined/empty string handling.
- [ ] Boundary condition checks (empty lists, negative numbers, overflow).
- [ ] Resource cleanup: files, streams, network connections, and database handles are closed reliably.
- [ ] Error propagation: errors are handled or returned explicitly without silent suppression.
- [ ] Idempotency: scripts or state-changing operations can safely be run repeatedly without duplicating state or corrupting files.

### 3. Codebase Integrity & Architectural Fit
- [ ] Preserves existing codebase conventions, idioms, and code style.
- [ ] Untouched lines are not reformatted, and imports are not re-ordered unnecessarily.
- [ ] Comments and docstrings on unaffected functions/classes remain intact.
- [ ] Minimal dependencies: standard library used where practical rather than introducing heavy new third-party packages.

### 4. Testing & Verification
- [ ] Are existing automated tests passing?
- [ ] Do new functional changes have corresponding test coverage?
- [ ] Are tests deterministic and fast (avoiding hardcoded `sleep` calls or timing dependencies)?

---

## Step 3: Deliver Structured Review Report

Format the feedback into clear, actionable sections:

```markdown
### 📋 Review Summary
<High-level assessment of the intent, architecture, and overall quality>

### 🛡️ Security & Safety Assessment
<Status: Pass or Concerns identified>

### 🔍 Key Findings & Recommendations
- **[CRITICAL]** `<file:line>`: <Issue that must be addressed before merge>
- **[WARNING]** `<file:line>`: <Potential edge case, reliability concern, or performance issue>
- **[SUGGESTION]** `<file:line>`: <Style, readability, or optimization improvement>

### 🧪 Verification
<Commands run or recommended to verify correctness>
```
