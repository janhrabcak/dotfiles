# 🚀 Dotfiles Bootstrapper (v3.4)

![CI State](https://github.com/janhrabcak/dotfiles/actions/workflows/test.yml/badge.svg)

An **"Infrastructure as Code"** approach to personal computing environments. This repository provides a zero-dependency, idempotent, and verified method to synchronize terminal configurations (Zsh, Vim, Git, SSH) and macOS system defaults across multiple machines.

## ⚡ Quick Start

| Goal | Command |
| :--- | :--- |
| **Remote Install** (No clone) | `/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/janhrabcak/dotfiles/main/dot.sh)" -- --remote` |
| **Local Install** (Clone first) | `git clone https://github.com/janhrabcak/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && ./dot.sh` |
| **Self-Update** | `./dot.sh --update` |
| **Check Health** | `./dot.sh --doctor` |
| **Run Local CI Test** | `tests/dot-local-ci-test.sh` |
| **Run Specific Step** | `./dot.sh --only setup_vim` |

### Script Flags
*   `--remote`: Downloads the latest archive directly from GitHub.
*   `--doctor`: Runs a deep diagnostic of the system health and symlinks.
*   `--only <step>`: Runs a specific setup function only (e.g., `setup_vim`).
*   `--skip <step>`: Skips a specific setup function (e.g., `--skip setup_vim`).
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
In each profile, go to the **Advanced** tab. At the very bottom, look for the **Automatic Profile Switching** section:
*   **Google Rules**: Click the `+` button and add `*google*` (This matches your Google hostnames).
*   **Tmux Rules**: Click the `+` button and add `tmux` (This matches the running job name).

### 3. Remote Host Integration
Automatic Profile Switching relies on iTerm2 Shell Integration to report the current hostname and job. 
*   **Seamless Integration**: The bootstrap script automatically installs this integration on all environments (macOS, Linux servers, Linux clients).
*   **Tmux Control Mode**: This ensures your "Google" profile will automatically activate even when you are attached to a remote machine via Tmux Control Mode (`-CC`).

---

## 🛠️ Feature Breakdown

### 🐚 Shell Environment (Zsh)
*   **Unified Theme**: **Solarized Dark** across Zsh, Vim, and iTerm2 for a seamless, high-performance aesthetic.
*   **Identity**: Integrated **1Password SSH Agent** (macOS) and stable symlinks (Linux) for seamless key management.
*   **Shortcuts**:
    *   **Git**: `gs` (status), `ga` (add), `gc` (commit), `gp` (push), `gl` (graph log).
    *   **Tmux**: `tcc` (Control Mode), `tn` (new), `ta` (attach).

### 📝 Editor (Vim - Power Pack)
*   **Visuals**: **Lightline** for a premium, themed status bar.
*   **Productivity**: **FZF** integration for ultra-fast file finding (`Ctrl + p`).
*   **UX**: Persistent undo history, relative line numbers, and smart-case search.
*   **Go Development**: Pre-configured `vim-go` with leader shortcuts.

### 💻 Terminal (iTerm2 & Tmux)
*   **Native Windows**: Run tmux sessions as native iTerm2 windows/tabs via Control Mode (`-CC`).
*   **Stability**: Strict resize-management and background redirection for handshake safety.

### 🍎 macOS System Tweaks
The script applies professional defaults for high-performance workflows:
*   **Input**: Ultra-fast key repeat rates (Delay: 15, Repeat: 1).
*   **Trackpad**: Enables tap-to-click by default.
*   **Dock**: Auto-hide enabled with zero delay.

---

## 🏗️ How it Works (`dot.sh`)

The `dot.sh` script is a robust, idempotent bootstrapper designed to configure a fresh machine or update an existing one in seconds.

### Core Principles
*   **Idempotency**: Every operation is designed to be run multiple times without changing the result beyond the initial application. It checks if a link exists or a config line is present before acting.
*   **Safety First**: Before overwriting any existing configuration file, the script moves it to a timestamped backup directory (`~/.dotfiles.backup/`).
*   **Dry Run Support**: Use `--dry-run` to see exactly what the script would do without making any changes to your system.

### Execution Lifecycle
1.  **Dependency Check**: Ensures `git`, `curl`, `vim`, and `zsh` are installed. On macOS, it also checks for iTerm2.
2.  **Asset Synchronization**: Clones the repository to `~/.dotfiles` or pulls the latest changes. In `--remote` mode, it downloads a tarball directly from GitHub.
3.  **Modular Setup Phases**:
    *   **Zsh**: Installs Oh My Zsh, custom plugins (autosuggestions, syntax highlighting), and links `.zshrc`.
    *   **Vim**: Bootstraps `vim-plug`, links `.vimrc`, and triggers plugin installation.
    *   **Git**: Links global configurations via the `include.path` directive to keep local config separate.
    *   **SSH**: Injects an `Include` directive into `~/.ssh/config` and manages authorized keys for server environments.
    *   **macOS Defaults**: Applies system-level performance tweaks (key repeat, dock speed) and installs required fonts.
4.  **Verification**: The `--doctor` flag performs deep physical path resolution to ensure all symlinks are pointing to the correct files in the repository.

### Idempotent Helpers
The script uses specialized shell functions to ensure consistency:
*   `safe_link`: Creates symlinks while backing up existing files and repairing broken links.
*   `safe_append/prepend`: Ensures specific configuration lines (like SSH `Include`) exist in files without creating duplicates.

---

## 🧠 Technical Appendix (Project Memory)

### 1. The Bootstrap Engine (`dot.sh`)
*   **Doctor Logic**: The `--doctor` flag performs deep physical path resolution (`:A`) to verify integrity even across symlinked directories.

### 2. SSH Agent Strategy
*   **Linux/Remote**: Uses a **Stable Symlink** at `~/.ssh/ssh_auth_sock`. The `.zshrc` updates this symlink on every fresh login and forces all sub-shells (including those inside tmux) to reference it. This prevents "Dead Agent" syndrome when re-attaching to old sessions.

### 3. iTerm2 Control Mode Hardening
*   **Protocol Protection**: All background output (like TPM initialization) is redirected to `/dev/null` to prevent corrupting the `-CC` handshake.
