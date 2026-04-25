# 🚀 Dotfiles Bootstrapper (v3.0)

![CI State](https://github.com/janhrabcak/dotfiles/actions/workflows/test.yml/badge.svg)

An **"Infrastructure as Code"** approach to personal computing environments. This repository provides a zero-dependency, idempotent, and verified method to synchronize terminal configurations (Zsh, Vim, Git, SSH) and macOS system defaults across multiple machines.

## ⚡ Quick Start

Deploy your environment with a single command:

```zsh
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/janhrabcak/dotfiles/main/dot.sh)" -- --remote
```

### Script Flags
*   `--remote`: Downloads the latest archive directly from GitHub.
*   `--doctor`: Runs a deep diagnostic of the system health and symlinks.
*   `--only <step>`: Runs a specific setup function only (e.g., `setup_vim`).
*   `--dry-run`: Preview execution steps without modifying the system.
*   `--test`: Runs a post-setup verification suite (Symlinks, Permissions, SSH).

---

## 🏗️ Architecture & Design Principles

*   **Zero Initial Dependency:** Uses only `curl` and `tar` for "day zero" setup.
*   **Fail-Fast Reliability**: Critical operations halt execution on failure to prevent broken states.
*   **Diagnostic-First**: Built-in `--doctor` mode for proactive environment health checks.
*   **Protocol Hardening**: Optimized for high-stability iTerm2 + Tmux Control Mode.

---

## 🛠️ Feature Breakdown

### 💻 iTerm2 + Tmux Control Mode (`-CC`)
*   **Native Windows**: Run tmux sessions as native iTerm2 windows/tabs.
*   **Visual Awareness**:
    *   **Contextual Tab Coloring**: Tabs turn **Google Blue** on corporate hosts and **Tmux Orange** elsewhere.
    *   **Power Context Badge**: Displays `user@host (session)` in the corner for 100% situational awareness.
*   **Stability**: Silenced TPM output and "Silent Terminators" (`\e\\`) for bell-free handshake safety.

### 🐚 Shell & Terminal (Zsh)
*   **Theme**: Environment-aware `agnoster` theme.
    *   **Google Rainbow**: Automatic banding for Google hosts.
*   **Identity**: Integrated **1Password SSH Agent** (macOS) and stable symlinks (Linux) for seamless key management.
*   **Shortcuts**:
    *   **Git**: `gs` (status), `ga` (add), `gc` (commit), `gp` (push), `gl` (graph log).
    *   **Tmux**: `tcc` (Control Mode), `tn` (new), `ta` (attach).

### 📝 Editor (Vim)
*   **Plugin Management**: Automated installation of `vim-plug`.
*   **Go Development**: Pre-configured `vim-go` with leader shortcuts:
    *   `,r` (Run), `,b` (Build), `,t` (Test), `,c` (Coverage).

### 🍎 macOS System Optimizations
The script applies professional defaults for high-performance workflows:
*   **Input**: Ultra-fast key repeat rates (Delay: 15, Repeat: 1).
*   **Trackpad**: Enables tap-to-click by default.
*   **Dock**: Auto-hide enabled with zero delay.

---

## 🧪 Robust CI/CD

To ensure reliability, this repository features an extensive GitHub Actions pipeline:
1.  **Strict Linting**: Automated syntax validation for `dot.sh` and `zsh` components.
2.  **Matrix Testing**: Concurrent testing on `macos-latest` and `ubuntu-latest`.
3.  **Dry-Run Assertions**: Verifies that safe-execution modes function correctly.

---

## 🧠 Technical Appendix (Project Memory)

This section documents deep engineering decisions and established patterns for maintainers and AI agents.

### 1. The Bootstrap Engine (`dot.sh`)
*   **Execute Wrapper**: Uses `execute "cmd" true` for critical steps. Halts on failure.
*   **Modular Tool Phases**: Each tool (Zsh, Vim, Tmux) has a dedicated `setup_` function that handles its own dependencies, linking, and post-installation tasks.
*   **Doctor Logic**: The `--doctor` flag performs non-destructive health checks (Symlink integrity, SSH socket reachability, iTerm2 preference sync status).

### 2. SSH Agent Strategy
*   **macOS**: Uses 1Password SSH agent directly.
*   **Linux**: Uses a **Stable Symlink** at `~/.ssh/ssh_auth_sock`. This ensures remote tmux sessions stay connected to forwarded agents after re-attachment.

### 3. iTerm2 Control Mode Hardening
*   **Handshake Protection**: Protects the protocol by silencing TPM and using **String Terminators (`\e\\`)** instead of **Bells (`\a`)** for visual hooks.
*   **Window Management**: Suppresses the Tmux Dashboard and opens all windows as native tabs (`OpenTmuxWindowsAs -int 0`).

### 4. Known Gotchas
*   **iTerm2 Plist**: Preference sync ONLY works if `com.googlecode.iterm2.plist` exists in `iterm2/`. JSON is not supported for direct loading.
*   **Tmux Environment**: `SSH_AUTH_SOCK` must be in the `update-environment` list in `tmux.conf`.
