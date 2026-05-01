# Changelog

All notable changes to this project will be documented in this file.

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
