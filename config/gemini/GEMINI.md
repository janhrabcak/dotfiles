# Global Developer Guidelines

## 1. Communication & Collaboration
- **Direct & Concise**: Provide direct, technical explanations without unnecessary filler, repetitive summaries, or boilerplate pleasantries.
- **Explain the "Why"**: Focus explanations on architectural decisions, trade-offs, and non-obvious context rather than narrating trivial code changes.
- **Preserve Codebase Integrity**: Never reformat untouched lines or re-order imports unnecessarily. Preserve existing comments, docstrings, and established conventions unless explicitly asked to modify them.

## 2. Git & Version Control
- **Conventional Commits**: Format commit messages according to the Conventional Commits specification:
  - `feat: <description>` (new features)
  - `fix: <description>` (bug fixes)
  - `refactor: <description>` (code changes with no external behavior changes)
  - `docs: <description>` (documentation only)
  - `test: <description>` (adding or modifying tests)
  - `chore: <description>` (maintenance, dependencies, tooling)
- **Atomic Commits**: Keep changes focused on the requested task. Do not mix unrelated refactors or formatting changes into functional commits.
- **Push & Destructive Actions**: Never execute `git push`, branch deletion, or git history alteration without explicit user request.

## 3. Engineering & Tooling
- **Minimal Dependencies**: Solve problems using standard libraries and existing project dependencies before suggesting new third-party packages.
- **Verification First**: After writing or modifying code, proactively run relevant tests, linters, or type-checks to verify correctness before concluding.
- **Shell & Tools**: Prefer fast, standard CLI utilities (`rg`, `fd`, `find`, `git`) for inspection. Ensure shell scripts remain POSIX or Zsh compatible.

## 4. Security & Safety
- **Zero Secrets**: Never print, generate, store, or commit plaintext secrets, API tokens, private keys, or credentials.
- **Ignore Rules**: Respect `.gitignore` at all times. Do not leave stray scratch files or artifacts outside designated temporary or artifact directories.
