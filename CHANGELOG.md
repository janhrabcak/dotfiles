# Changelog

All notable changes to this project will be documented in this file.

## [v3.7.0] - 2026-09-10
### Added
- **Multi-Agent Global AI Configuration (`setup_ai`)**: Refactored agent configuration into vendor-neutral single-source-of-truth architecture (`config/ai/`), declarative symlinking across Gemini/Antigravity (`~/.gemini/config/GEMINI.md`, `~/.gemini/config/AGENTS.md`), Claude Code (`~/.claude/CLAUDE.md`), Cursor (`~/.cursorrules`), and Cline/Roo (`~/.clinerules`).
- **Global Developer Guidelines (`config/ai/AGENTS.md`)**: Configured universal developer guidelines enforcing concise communication, Conventional Commits, proactive test verification, code integrity, and zero-secrets security across all AI assistants.
- **Command Whitelist & Security (`settings.json`)**: Consolidated and validated permission settings with regex-based auto-approvals for safe read-only inspection (`rg`, `head`, `tree`, `stat`, `which`), git queries (`git branch`, `show`, `rev-parse`, `remote`, `tag`), runtime tools (`node`, `npm`, `go`, `docker`), and local test runners.
- **Global MCP Tool Configuration (`mcp_config.json`)**: Configured global Model Context Protocol servers for persistent memory graph (`@modelcontextprotocol/server-memory`), GitHub tools (`@modelcontextprotocol/server-github`), and web fetching (`mcp-fetch-server`).
- **Custom Global Skills**: Created on-demand progressive disclosure playbooks for `conventional-release` (SemVer calculation, changelog generation, and tag drafting) and `rigorous-pr-review` (multi-pillar code inspection).
- **Dual-Audience Documentation Requirement**: Enforced that all code modifications must include updates to human-readable project documentation (features, usage, changelogs) as well as agent-facing contextual instructions (architectural invariants, codebase history, edge-case caveats, and negative constraints in `AGENTS.md`).
- **Diagnostic & Test Suite Integration**: Extended `run_doctor` and `tests/run-tests.sh` with automated verification for all AI symlinks (`GEMINI.md`, `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.clinerules`, `settings.json`, `mcp_config.json`, and `skills/`).

## [v3.6.0] - 2026-09-09
### Added
- **Maintenance & Pruning (`--clean` & Backup Rotator)**: Added `--clean` CLI option and `prune_dead_symlinks` function to identify and purge broken dotfiles symlinks without touching external links. Added automated backup rotation (`rotate_backups`) to retain only the 5 most recent timestamped backup directories in `~/.dotfiles.backup/`.
- **Git Pre-Commit Hooks Integration**: Added repository-tracked pre-commit hook in `.githooks/pre-commit` verifying Zsh syntax, Vim config, Tmux config, and ShellCheck. Configured automatic hook activation via `git config core.hooksPath .githooks` during `setup_git`.
- **Automatic `.local` Template Generation**: Added automated initialization of missing local machine overrides. Automatically creates `config/git/.gitconfig.local` pre-populated with existing user identity and generates starter `~/.zshrc.local` template for private shell environments. Added `config/ssh/authorized_keys.local.example` documentation.
- **Automated Dependency Updates (Dependabot)**: Added `.github/dependabot.yml` configured to monitor and generate weekly pull requests for GitHub Actions dependencies.
- **Strict Binary Installation Policy (`--install-deps`)**: Ensured no binary, package, font, or external executable is ever installed without explicit `--install-deps` permission. Gated `brew bundle` behind `--install-deps` on macOS (defaulting to read-only `brew bundle check`), gated Vim post-install binary hooks (`fzf#install()` and `:GoUpdateBinaries`), and gated Oh My Zsh and font downloads.
- **Expanded Test Suite (43/43 Checks Passing)**: Added comprehensive test coverage for `--install-deps` enforcement, gated Vim binary hooks, `--clean` dry-run and live pruning, backup directory rotation, Git hook installation and execution, and `.local` template auto-generators.

## [v3.5.1] - 2026-09-08
### Added
- **Unified Behavioral Test Suite (`tests/run-tests.sh`)**: Zero-dependency automated test runner executing 31 checks across isolated temporary sandboxes (syntax, headless Vim evaluation, `--dry-run` side-effect absence, `--skip`/`--only` flags, file backup recovery, SSH 600 permissions, Git identity resolution, and doctor diagnostic failure detection).
- **Chaos & Hostile State Resilience Testing**: Extended test suite with Group 10 testing automatic recovery from broken symlinks, cyclic self-referencing symlinks, directory collisions with backups, missing parent hierarchies, and SSH custom configuration preservation.
- **Declarative Symlink Manifest**: Refactored procedural symlinking across `setup_zsh`, `setup_vim`, `setup_tmux`, and `run_doctor` into a single declarative `LINK_MANIFEST` supporting step ownership, platform scoping, and automatic `--skip` integration.
- **CI Static Analysis & Automated Testing**: Added ShellCheck static analysis to GitHub Actions lint job and integrated `tests/run-tests.sh` across all OS runner matrices.
- **Package Management & Brewfile (`config/brew/Brewfile`)**: Declared Homebrew bundle dependencies (`ripgrep`, `fzf`, `tmux`, `gh`, `neovim`, `iterm2`), added automated bundle verification in `dot.sh`, and introduced `--install-deps` flag for automated package installation on Debian/Ubuntu.
- **Neovim & Modern Editor Integration**: Added shared `.vimrc` linking to `~/.config/nvim/init.vim`, Neovim runtimepath sharing, and smart `v` / `vim` aliases.

### Security
- **Secret & Internal Hostname Sanitization**: Removed internal Google corporate hostnames from public `config/zsh/aliases.zsh`.
- **Portable iTerm2 Configuration**: Dynamically adapt hardcoded home paths in `com.googlecode.iterm2.plist` to current user's `$HOME` during install.
- **SSH Hardening**: Removed redundant `ForwardAgent yes` for `github.com`.
- **SSH Config Permissions**: Enforced `chmod 600` on `~/.ssh/config` and used secure temporary files during updates.
- **Eval & Injection Elimination**: Replaced `eval` string concatenation in `safe_append`, `safe_prepend`, and `ONLY_STEP` with native redirection and literal handling.
- **Gatekeeper Protection**: Removed global disable of macOS LaunchServices quarantine (`LSQuarantine`).
- **Authorized Keys**: Added support for local `config/ssh/authorized_keys.local` ignored by Git.

### Changed
- **Fast-Path Shell Startup**: Replaced `whoami` subshell execution with `$USER`, cached prompt hostname lookups, and enabled Zsh completion caching.

### Fixed
- **Vim Persistent Undo Feature**: Corrected Vim feature check from `has('undofile')` to `has('persistent_undo')` so persistent undo is properly enabled.
- **Docker Local CI TTY Handling**: Added TTY check in `tests/dot-local-ci-test.sh` so tests run in headless environments without TTY errors.
- **CI / Diagnostic Exit Codes**: `run_doctor` and `--test` now return non-zero exit codes on failure instead of silently passing.
- **Git Config Local Include**: Updated `config/git/.gitconfig` to correctly include `~/.dotfiles/config/git/.gitconfig.local`.
- **Linux Client SSH Config**: Fixed `SSH_FILENAME` selection so `linux-client` mode selects `linux.config` rather than defaulting to `macos.config`.
- **Vim Undo Directory**: Automatically create `~/.vim/undo` directory in `.vimrc` and `setup_vim` to eliminate `E828` save errors.
- **CLI Argument Preservation**: Preserved `ORIGINAL_ARGS` across `dot.sh` self-update and fail with error on unknown parameters.
- **Tmux Cross-Platform**: Enabled `setup_tmux` across all modes, not only `linux-server`.
- **Zsh Plugin Order**: Moved `zsh-syntax-highlighting` to the end of Oh My Zsh plugins list.
- **SSH Control Mode Alias**: Forward all arguments (`"$@"`) in `ssh-cc`.
- **Bin Directory Link**: Automatically link `bin/` to `~/.bin` in `setup_zsh`.
- **macOS Installer Stability**: Removed `Terminal` from `killall` list to avoid terminating running sessions.
- **Multi-step Skipping**: Converted `SKIP_STEP` to `SKIP_STEPS` array in `dot.sh` to allow multiple `--skip` flags without overwriting.
- **Tmux Escape Time & SSH Socket**: Excluded `SSH_AUTH_SOCK` from `update-environment` and removed redundant `tmux-sensible` to preserve `escape-time 0` and stable agent socket.
- **CI Symlink Checks**: Added verification for `.aliases.zsh`, `.tmux.conf`, and `.bin` in GitHub Actions workflow.
- **iTerm2 Diagnostic Path**: Fixed expected path string in `dot.sh` doctor output (`config/iterm2`).
- **Example Config Paths**: Corrected stale paths in `.gitconfig.local.example`.

## [v3.5.0] - 2026-04-30
### Added
- **Zsh Prompt User Prefix**: Added user prefix to the custom Google-themed hostname prompt in `.zshrc`.

### Changed
- **SSH Config Split**: Refactored SSH configuration into platform-specific files (`macos.config` and `linux.config`) to improve maintainability and environment detection.
- **Improved SSH Agent Detection**: Refined detection logic for 1Password (macOS) and stable symlinks (Linux) in `dot.sh`.
- **FQDN Prompt Hostname**: Updated Zsh prompt to use the fully qualified domain name (FQDN) instead of the short hostname.
- **Dynamic Hostname Colors**: Implemented a scaling color mapping logic for the Zsh prompt hostname that applies across the entire string length.
- **Internal SSH Network**: Updated SSH host configuration to use a wildcard subnet for the internal network.

### Fixed
- **GitHub Agent Stability**: Fixed issues with GitHub SSH agent detection and connectivity.

### Removed
- **`gh` Dependency**: Removed the hard dependency check for GitHub CLI from the bootstrapper's validation logic.

## [v3.4.0] - 2026-04-27
### Changed
- **Unified Configuration Directory**: Migrated all tool-specific configuration directories (`git`, `iterm2`, `macos-terminal`, `ssh`, `tmux`, `vim`, `zsh`) into a central `config/` directory to further declutter the repository root.
- **Bootstrapper Update**: Refactored `dot.sh` and CI workflows to support the new `config/` based directory structure.

## [v3.3.0] - 2026-04-27
### Changed
- **Directory Structure Reorganization**: Moved internal test scripts (`dot-local-ci-test.sh` and `test-vim.sh`) into a dedicated `tests/` directory to declutter the root.
- **Bin Topic Creation**: Established a `bin/` directory to support a bin topic for executable scripts that should be globally available.
- **Gitignore Cleanup**: Removed dynamically generated `.viminfo` from git tracking and added it to `.gitignore` to prevent repository noise.

## [v3.2.0] - 2026-04-27
### Added
- **`--skip <step>` flag**: New `dot.sh` flag to skip a named setup step (e.g. `./dot.sh --skip setup_vim`) without needing to run only a single step.
- **Git identity template**: Added `git/.gitconfig.local.example` as a template for personal `[user]` identity. Copy to `git/.gitconfig.local` and fill in your details after bootstrapping.
- **CI job timeout**: Set `timeout-minutes: 10` on all GitHub Actions jobs to prevent indefinite runner hangs.

### Changed
- **CI `apt-get` consolidation**: Merged three separate `sudo apt-get update` calls in the lint job into a single `Install Dependencies` step, reducing network I/O and job time.
- **CI matrix strategy**: Replaced confusing `exclude`-based matrix (2×3 minus 4) with an explicit `include` list for clarity.
- **actions/checkout bumped to v6**: Eliminates Node.js 20 deprecation warnings on GitHub Actions runners.
- **`vim-go` CI guard**: `GoUpdateBinaries` post-install hook is now skipped when `$GITHUB_ACTIONS == true`, removing the need for `pkill` cleanup and preventing orphaned Go processes from hanging the runner.
- **`ssh-cc` alias → function**: Converted the broken `alias ssh-cc="ssh -t \"$1\" ..."` (where `$1` was always empty) to a proper Zsh function.
- **`ls` alias family normalized**: `ll`, `la`, and `lh` now all use a shared `$_ls_flags` variable so macOS colour flags apply consistently across all variants.
- **`GOOGLE_PROMPT` simplified**: Collapsed the unused `gprompt-font` / `gprompt-bg` aliases into a single `gprompt` alias (`GOOGLE_PROMPT=1`), matching the actual prompt logic.
- **`tmux.conf` SSH_AUTH_SOCK path**: Changed `~` to `$HOME` in `set-environment` so tmux expands the path correctly.
- **Docker startup timeout**: `dot-local-ci-test.sh` now times out with a clear error if Docker Desktop doesn't respond within 60 seconds.

### Fixed
- **`((errors++))` crash with `set -e`**: Replaced all `((errors++))` expressions with `errors=$((errors + 1))` in the doctor/test logic to prevent `set -e` from treating a zero-value increment as a fatal error.
- **`gh` hard dependency removed**: Removed `gh` from the `check_dependencies` list since its absence is already handled gracefully in `setup_git` with a warning.
- **Duplicate `.zshrc` section heading**: Removed a stray empty `--- 4. Custom Agnoster Prompt Segments ---` block that appeared twice.

### Security
- **Personal identity removed from public repo**: `[user]` block (name/email) removed from the committed `git/.gitconfig` to prevent email scraping. Identity now lives in the gitignored `git/.gitconfig.local`.

## [v3.1.0] - 2026-04-26
### Added
- **Local CI Sandbox**: Created `dot-local-ci-test.sh` to allow developers to simulate the GitHub Actions pipeline locally using Docker.
- **CI Robustness**: Upgraded the GitHub Actions pipeline with Tmux configuration syntax checking, double-run idempotency validation, and runtime Zsh environment checks.
- **Self-Update**: Added `--update` flag to `dot.sh` to allow the script to easily pull the latest remote changes when managing the repository locally.
- **Local Clone Installation**: Added local clone installation method and directory existence validation in `dot.sh`.
- **Google Theming**: Added subtle Google-themed background images for iTerm2 and documented native profile switching.

### Changed
- **Prompt Logic**: Simplified prompt context logic by unifying Google Rainbow and standard Red SSH prompts into a single cleaner `prompt_context` segment with the official Google logo color palette (Blue, Red, Yellow, Blue, Green, Red).
- **Zsh Hooks**: Autoload zsh hooks and execute visual refresh on shell startup.
- **iTerm2 Config**: Updated iTerm2 configuration settings and badge logic.

## [v3.0.0]
### Added
- **Dotfiles Doctor**: Added deep diagnostic suite (`./dot.sh --doctor`) using Absolute Physical Resolution (`:A`) to verify symlinks.
- **Vim Power Pack**: Upgraded Vim setup with `fzf`, `lightline`, `solarized` dark theme, persistent undo (`undofile`), and relative line numbers.
- **iTerm2 Native Visuals**: Transitioned to native tab coloring using iTerm2 Automatic Profile Switching based on hostname or environment.
- **Lifecycle Functions**: Modularized dotfile installation logic into tool-specific lifecycle functions in `dot.sh`.
- **iTerm2 Plist**: Added iTerm2 configuration settings via plist file.

### Changed
- **SSH Agent Persistence**: Hardened stable symlink creation in `~/.ssh/ssh_auth_sock` for Linux to fix "Dead Agent" syndrome in old tmux sessions. macOS now strictly relies on the 1Password IdentityAgent socket.
- **Smoke Tests**: Unified smoke tests and doctor into a single verification workflow and improved SSH config check reporting.
- **TPM Initialization**: Removed silent error suppression from `tmux.conf` TPM initialization; now redirects to `~/.tmux/tpm.log`.
- **ZshRC Path**: Updated `.zshrc` path to use subdirectory in dotfile symlink mapping.
- **Vim Theme**: Migrated vim colorscheme to Solarized Dark.

### Removed
- Removed legacy `prompt_bzr` and `prompt_hg` from the Zsh agnoster prompt sequence to improve prompt render speed.
- Removed arbitrary `nowritebackup` command from `.vimrc`.
- Removed legacy iTerm2 config and cleaned up terminal configuration settings.

## [v2.3.0]
### Added
- **Tmux Control Mode**: Optimized dotfiles for iTerm2 Tmux Control Mode (`-CC`) and added control mode integration with automatic visual styling and aliases.
- **Google Branding**: Implemented environment-aware Zsh prompt with Google-specific rainbow branding (font and background styles) and toggle aliases.
- **Dynamic Terminal Title**: Enhanced SSH detection and implemented dynamic terminal title management using `precmd`/`preexec` hooks.
- **Linux Server Mode**: Added tmux configuration and plugin manager support for linux-server mode.
- **1Password Integration**: Added safe symlink function, automatic Nerd Font installation, and 1Password integration hooks.
- **Git Config**: Added git configuration file and integrated git/gh setup into bootstrap script.
- **Aliases Module**: Moved shell aliases to a dedicated `aliases.zsh` file and sourced it in `.zshrc`.
- **CI/CD**: Expanded CI with linting, multi-mode matrix testing, and post-install state validation.

### Changed
- **Vim Modernization**: Modernized vim config with vim-plug, optimized zsh path management, and enhanced bootstrap script with logging and automated dependency checks.
- **Zsh Default Shell**: Automated Zsh default shell configuration in bootstrap script.
- **iTerm2 Stability**: Disabled aggressive-resize in tmux for iTerm2 compatibility and prevented iTerm2 shell integration crashes in tmux.
- **macOS Tweaks**: Included Terminal in macOS process restart list.

### Removed
- Deprecated macOS Terminal profile settings in favor of iTerm2.
- Removed redundant iTerm2 environment checks in zshrc tmux integration.
- Removed `DESIGN.md` and consolidated architecture information into `README.md`.
