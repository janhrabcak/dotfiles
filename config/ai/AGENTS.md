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

## 5. Dual-Audience Documentation Requirement
Every code change must be accompanied by updates to at least two distinct types of documentation (proportional to the scope of the change):
- **Human-Readable Project Documentation (`README.md`, `CHANGELOG.md`, `docs/`)**:
  - Explains the project, features, user guides, API changes, and release notes.
  - Focuses on conceptual clarity, intent, and usability for human developers and users.
- **Agent-Facing Instructions & Context (`GEMINI.md`, `AGENTS.md`, or Project Technical Memory)**:
  - Records actionable instructions, architectural invariants, codebase history, edge-case caveats, hidden assumptions, and negative decisions ("why we avoided approach X").
  - Ensures future AI sessions and subagents thoroughly understand the codebase, avoid known traps, and never regress past fixes.
  - Keeps content dense, structured, and operational without repeating redundant prose.

## 6. Architecture & Platform Invariants
- **Platform-Scoped Plugins**: Shell plugins designed for specific operating systems (e.g. Oh My Zsh's `macos` plugin) must be guarded conditionally (`[[ "$OSTYPE" == darwin* ]]`) in `config/zsh/.zshrc` to avoid spawning redundant subprocesses, errors, or latency on Linux.
- **Prompt Performance & `vcs_info`**:
  - Prompt git segments must use Zsh's built-in `vcs_info` module (`add-zsh-hook precmd vcs_info`) rather than Oh My Zsh's default `prompt_git`, which forks 10–15 child `git` processes per prompt.
  - When configuring hooks with `add-zsh-hook`, never pass anonymous function syntax (`add-zsh-hook precmd () { ... }`); in Zsh this defines a function named `add-zsh-hook` and clobbers the utility itself. Always register named helper functions.
- **Tmux Socket Isolation in Tests & Hooks**: Never run `tmux ... start-server \; kill-server` without an isolated socket flag (`-L "dotfiles-test-$$"`). Running `kill-server` without `-L` targets the user's default socket (`/tmp/tmux-$UID/default`), ignoring `-f` if a server is already running and terminating all active user `tmux` sessions.
- **AI Command Whitelist Invariant (`settings.json`)**: Auto-approved command regex patterns must always be strictly anchored (`^...$`) and bound to safe argument characters (`[a-zA-Z0-9_./@~:= -]`). Never allow shell control operators (`;`, `&&`, `||`, `|`, `$()`, backticks) or arbitrary command execution wrappers (`docker exec`, `find -exec`, `curl`).
- **MCP Version Pinning Invariant (`mcp_config.json`)**: All MCP servers invoked via `npx` must specify pinned semantic versions (`package@x.y.z`) to prevent unpinned execution and protect token secrets.

