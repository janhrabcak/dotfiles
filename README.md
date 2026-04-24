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
*   `--dry-run`: Preview execution steps without modifying the system.
*   `--test`: Runs a post-setup verification suite (Symlinks, Permissions, SSH).

---

## 🏗️ Architecture & Design Principles

*   **Zero Initial Dependency:** Uses only `curl` and `tar` for "day zero" setup.
*   **Fail-Fast Reliability**: Critical operations halt execution on failure to prevent broken states.
*   **Centralized Backups**: Displaced files are moved to a timestamped `~/.dotfiles.backup/` folder.
*   **Protocol Hardening**: Optimized for high-stability iTerm2 + Tmux Control Mode.

---

## 🛠️ Feature Breakdown

### 💻 iTerm2 + Tmux Control Mode (`-CC`)
*   **Native Windows**: Run tmux sessions as native iTerm2 windows/tabs.
*   **Visual Awareness**:
    *   **Tab Coloring**: iTerm2 tabs automatically turn **Amber/Orange** when inside tmux.
    *   **Dynamic Badges**: Displays the session name as a badge in the corner.
*   **Stability**: Silenced TPM output and strict resize-management for handshake safety.

### 🐚 Shell & Terminal (Zsh)
*   **Theme**: Environment-aware `agnoster` theme.
    *   **Google Rainbow**: Automatic banding for Google hosts. Switch styles via `gprompt-font` or `gprompt-bg`.
*   **Identity**: Integrated **1Password SSH Agent** for seamless, secure key management.
*   **Shortcuts**:
    *   **Git**: `gs` (status), `ga` (add), `gc` (commit), `gp` (push), `gl` (graph log).
    *   **Tmux**: `tcc` (Control Mode), `tn` (new), `ta` (attach), `ssh-cc` (remote control mode).

### 📝 Editor (Vim)
*   **Plugin Management**: Automated installation of `vim-plug`.
*   **Go Development**: Pre-configured `vim-go` with leader shortcuts:
    *   `,r` (Run), `,b` (Build), `,t` (Test), `,c` (Coverage).
*   **UI**: `molokai` colorscheme, `nerdtree`, and `vim-fugitive`.
*   **Toggles**: `F12` to show/hide hidden characters.

### 🍎 macOS System Optimizations
The script applies professional defaults for high-performance workflows:
*   **Input**: Ultra-fast key repeat rates (Delay: 15, Repeat: 1).
*   **Trackpad**: Enables tap-to-click by default.
*   **Finder**: Shows all file extensions; disables extension change warnings.
*   **Dock**: Auto-hide enabled with zero delay and optimized icon sizes.
*   **Security**: Disables quarantine for downloaded applications.

### 🔐 Secure SSH & Git
*   **Priority Configuration**: Prepends `Include` directives to ensure dotfiles take precedence.
*   **Permissions**: Automatically enforces strict `700/600` permissions on all SSH components.

---

## 🧪 Robust CI/CD

To ensure reliability, this repository features an extensive GitHub Actions pipeline:
1.  **Strict Linting**: Automated syntax validation for `dot.sh` and `zsh` components.
2.  **Matrix Testing**: Concurrent testing on `macos-latest` and `ubuntu-latest`.
3.  **Dry-Run Assertions**: Verifies that safe-execution modes function correctly.
