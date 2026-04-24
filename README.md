# 🚀 Dotfiles Bootstrapper (v2.3)

![CI State](https://github.com/janhrabcak/dotfiles/actions/workflows/test.yml/badge.svg)

An **"Infrastructure as Code"** approach to personal computing environments. This repository provides a zero-dependency, idempotent, and verified method to synchronize terminal configurations (Zsh, Vim, Git, SSH) and macOS system defaults across multiple machines.

## ⚡ Quick Start

Deploy your environment with a single command:

```zsh
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/janhrabcak/dotfiles/main/dot.sh)" -- --remote
```

### Script Flags
*   `--remote`: Downloads the latest archive directly from GitHub.
*   `--dry-run`: Preview all execution steps without modifying your system.
*   `--test`: Runs a post-setup verification suite (Symlinks, Permissions, SSH).

---

## 🏗️ Architecture & Design Principles

*   **Zero Initial Dependency:** Uses only `curl` and `tar` for "day zero" setup.
*   **Enforced Step 0:** Strictly verifies all dependencies (CLI tools and iTerm2 on macOS) before proceeding.
*   **Fail-Fast Reliability**: Critical operations (downloads, symlinking) are guarded; the script halts immediately on fatal errors to prevent half-configured states.
*   **Centralized Backups**: Displaced configurations are moved to a timestamped `~/.dotfiles.backup/` folder, keeping your `$HOME` directory clean.
*   **Protocol Hardening**: Optimized for high-stability iTerm2 + Tmux Control Mode.

---

## 🛠️ Feature Breakdown

### 💻 iTerm2 + Tmux Control Mode (`-CC`)
A hardened, visually distinct **Control Mode** integration.

*   **Native Windows**: Run tmux sessions as native iTerm2 windows/tabs.
*   **One-Click Attach**: `tcc` (local) or `ssh-cc <host>` (remote).
*   **Visual Awareness System**:
    *   **Tab Coloring**: iTerm2 tabs automatically turn **Amber/Orange** when inside tmux.
    *   **Dynamic Badges**: Displays the session name as a badge in the corner.
*   **Stability**: Handshake protected via silenced TPM output, disabled focus-events, and strict resize-management.

### 🐚 Shell & Terminal (Zsh)
*   **Theme**: Environment-aware `agnoster` theme with clean local context, red SSH warnings, and signature **Google rainbow** bands.
*   **History**: Shared history across sessions with intelligent search and duplicate suppression.
*   **1Password SSH Agent**: Automated handoff to the 1Password SSH agent for secure key management.

### 🔀 Multiplexer (Tmux)
*   **Hardened Config**: Optimized `.tmux.conf` with `vi` syntax, directory-aware splits, and mouse support.
*   **Plugin Manager**: Automated TPM installation with silenced initialization for protocol safety.

### 📝 Editor (Vim)
*   **Plugin Management**: Automated installation of `vim-plug`.
*   **Curated Plugins**: Includes `vim-go`, `nerdtree`, `vim-fugitive`, and `molokai`.

### 🔐 Secure SSH & Git
*   **Priority Configuration**: Prepends `Include` directives to ensure dotfiles settings take precedence over local host matches.
*   **Permissions**: Automatically enforces strict `700/600` permissions on all SSH components.

---

## 🧪 Robust CI/CD

To ensure the bootstrap script remains highly reliable, this repository features an extensive GitHub Actions pipeline:
1.  **Strict Linting**: Automated syntax validation using `zsh -n` and headless Vim execution.
2.  **Matrix Testing**: Concurrent testing on `macos-latest` (Workstation) and `ubuntu-latest` (Server).
3.  **Dry-Run Assertions**: Verifies that safe-execution modes don't unintentionally alter the CI environment.
