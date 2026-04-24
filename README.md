# 🚀 Dotfiles Bootstrapper (v2.2)

![CI State](https://github.com/janhrabcak/dotfiles/actions/workflows/test.yml/badge.svg)

An **"Infrastructure as Code"** approach to personal computing environments. This repository provides a zero-dependency, idempotent, and verified method to synchronize terminal configurations (Zsh, Vim, Git, SSH) and macOS system defaults across multiple machines.

## ⚡ Quick Start

Deploy your environment with a single command (no `git clone` required):

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
*   **Idempotency & Safety:** Every operation is guarded. The script automatically backs up existing configurations (`.zshrc.bak`) before linking.
*   **Modular Architecture**: Clean separation between core shell logic (`.zshrc`), global shortcuts (`.aliases.zsh`), and machine-specific overrides (`.zshrc.local`).
*   **Protocol Hardening**: Optimized for high-stability iTerm2 + Tmux Control Mode.

---

## 🛠️ Feature Breakdown

### 💻 iTerm2 + Tmux Control Mode (`-CC`)
The centerpiece of this environment is a hardened, visually distinct **Control Mode** integration.

*   **Native Windows**: Run tmux sessions as native iTerm2 windows/tabs.
*   **One-Click Attach**:
    *   `tcc`: Start/Attach to a local Control Mode session.
    *   `ssh-cc <host>`: Start/Attach to a remote Control Mode session.
*   **Visual Awareness System**:
    *   **Tab Coloring**: iTerm2 tabs automatically turn **Amber/Orange** when inside a tmux session.
    *   **Dynamic Badges**: Displays the current Tmux Session Name as a badge in the corner.
    *   **Protocol Stability**: Handshake is protected via silenced TPM output, disabled focus-events, and strict resize-management.

### 🐚 Shell & Terminal (Zsh)
*   **Theme**: Environment-aware `agnoster` theme:
    *   **Local**: Clean, minimal context.
    *   **SSH**: High-visibility **red** hostname segment.
    *   **Google**: Signature **rainbow** hostname band (Blue-Red-Yellow-Blue-Green-Red).
*   **History**: Intelligent search with Arrow Keys, shared history across sessions, and duplicate suppression.
*   **1Password SSH Agent**: Automated handoff to the 1Password SSH agent for seamless, secure key management.

### 🔀 Multiplexer (Tmux)
*   **Hardened Config**: optimized `.tmux.conf` with `vi` syntax, directory-aware splits, and mouse support.
*   **Stability Overrides**: Explicitly manages `aggressive-resize` and `focus-events` to prevent Control Mode detachments.
*   **Plugin Manager**: Automated TPM installation with silenced initialization for protocol safety.

### 📝 Editor (Vim)
*   **Plugin Management**: Automated installation of `vim-plug`.
*   **Curated Plugins**: Includes `vim-go`, `nerdtree`, `vim-fugitive`, and the `molokai` colorscheme.
*   **Cross-Platform Clipboard**: Intelligently switches between macOS and Linux clipboards.

---

## 🧪 Robust CI/CD

To ensure the bootstrap script remains highly reliable, this repository features an extensive GitHub Actions pipeline:
1.  **Strict Linting**: Automated syntax validation using `zsh -n` and headless Vim execution.
2.  **Matrix Testing**: Concurrent testing on `macos-latest` (Workstation) and `ubuntu-latest` (Server).
3.  **Dry-Run Assertions**: Verifies that safe-execution modes don't unintentionally alter the CI environment.

