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

## 🎨 iTerm2 Native Visuals (Setup Guide)

To keep the shell configs lean and high-performance, visual context (tab colors) is managed natively by iTerm2 using **Automatic Profile Switching (APS)**.

### 1. Create Your Profiles
1.  Open iTerm2 Preferences (`Cmd + ,`) > **Profiles**.
2.  Duplicate your default profile twice:
    *   Name one **"Tmux"**.
    *   Name one **"Google"**.
3.  Set the **Tab Color** for each:
    *   "Tmux" Profile: Set Tab Color to **Orange**.
    *   "Google" Profile: Set Tab Color to **Blue**.

### 2. Configure Automatic Rules
In each profile, go to the **Advanced** tab and look for **Automatic Profile Switching**:
*   **Google Rules**: Add `*google.com*` (switches by hostname).
*   **Tmux Rules**: Add `tmux` (switches by running job).

---

## 🛠️ Feature Breakdown

### 💻 iTerm2 + Tmux Control Mode (`-CC`)
*   **Native Windows**: Run tmux sessions as native iTerm2 windows/tabs.
*   **Stability**: Silenced TPM output and strict resize-management for handshake safety.

### 🐚 Shell & Terminal (Zsh)
*   **Unified Theme**: **Solarized Dark** across Zsh, Vim, and iTerm2 for a seamless, high-performance aesthetic.
*   **Identity**: Integrated **1Password SSH Agent** (macOS) and stable symlinks (Linux) for seamless key management.
*   **Shortcuts**:
    *   **Git**: `gs` (status), `ga` (add), `gc` (commit), `gp` (push), `gl` (graph log).
    *   **Tmux**: `tcc` (Control Mode), `tn` (new), `ta` (attach).

### 📝 Editor (Vim - Power Pack)
*   **Visuals**: **Lightline** for a premium, themed status bar.
*   **Productivity**: **FZF** integration for ultra-fast file finding (`Ctrl + p`).
*   **UX**: Persistent undo history, relative line numbers, and smart-case search.
*   **Go Development**: Pre-configured `vim-go` with leader shortcuts:
    *   `,r` (Run), `,b` (Build), `,t` (Test), `,c` (Coverage).

### 🍎 macOS System Optimizations
The script applies professional defaults for high-performance workflows:
*   **Input**: Ultra-fast key repeat rates (Delay: 15, Repeat: 1).
*   **Trackpad**: Enables tap-to-click by default.
*   **Dock**: Auto-hide enabled with zero delay.

---

## 🧠 Technical Appendix (Project Memory)

### 1. The Bootstrap Engine (`dot.sh`)
*   **Modular Tool Phases**: Each tool (Zsh, Vim, Tmux) has a dedicated `setup_` function.
*   **Doctor Logic**: The `--doctor` flag performs deep physical path resolution (`:A`) to verify integrity even across symlinked directories.

### 2. SSH Agent Strategy
*   **Linux/Remote**: Uses a **Stable Symlink** at `~/.ssh/ssh_auth_sock`. The `.zshrc` updates this symlink on every fresh login and forces all sub-shells (including those inside tmux) to reference it. This prevents "Dead Agent" syndrome when re-attaching to old sessions.

### 3. iTerm2 Control Mode Hardening
*   **Protocol Protection**: All background output (like TPM initialization) is redirected to `/dev/null` to prevent corrupting the `-CC` handshake.
