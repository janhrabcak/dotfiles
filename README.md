# 🚀 Dotfiles Bootstrapper (v2.1)

![CI State](https://github.com/janhrabcak/dotfiles/actions/workflows/test.yml/badge.svg)

An **"Infrastructure as Code"** approach to personal computing environments. This repository provides a zero-dependency, idempotent, and verified method to synchronize terminal configurations (Zsh, Vim, Git, SSH) and macOS system defaults across multiple machines.

## ⚡ Quick Start

Deploy your environment with a single command (no `git clone` required):

```zsh
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/janhrabcak/dotfiles/main/bootstrap.sh)" -- --remote
```

### Script Flags
*   `--remote`: Downloads the latest archive directly from GitHub.
*   `--dry-run`: Preview all execution steps without modifying your system.
*   `--mode [macos|linux-client|linux-server]`: Optimizes the setup based on the target environment (e.g., skips GUI settings on servers, imports Tmux and SSH keys).
*   `--test`: Runs a post-setup verification suite to ensure symlinks and permissions are correct.

### Manual Installation (Git Clone)
If you prefer to clone the repository manually rather than using the curl one-liner:

```zsh
git clone https://github.com/janhrabcak/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./bootstrap.sh
```

---

## 🏗️ Architecture & Design Principles

*   **Zero Initial Dependency:** Uses only `curl` and `tar` for "day zero" setup.
*   **Idempotency & Safety:** Every operation is guarded. The script automatically backs up existing configurations (`.zshrc.bak`) before linking, ensuring you never lose local data.
*   **Local-First Priority:** Uses `Include` directives in SSH and Git so your machine-specific settings always take precedence.
*   **Automated Verification:** A built-in smoke testing suite verifies system state.

---

## 🛠️ Feature Breakdown

### Shell & Terminal
*   **Zsh**: Oh My Zsh with an environment-aware `agnoster` theme:
    *   **Local**: Clean, minimal context.
    *   **SSH**: High-visibility **red** hostname segment.
    *   **Google**: Signature **rainbow** hostname band (Blue-Red-Yellow-Blue-Green-Red).
        *   **Modes**: Supports two styles: `gprompt-font` (default, colored letters) and `gprompt-bg` (colored background blocks).
    *   **Rendered Example (Google BG)**: ⬛️ `user@`🟦`go`🟥`og`🟨`le`🟦`ho`🟩`st`🟥`01` 🟦 `~/path`  
*   **Multiplexer (Tmux)**: Robust configuration (`tmux/.tmux.conf`) with modern `vi` syntax, directory-aware splits, and automated installation of the Tmux Plugin Manager (`tpm`) and session restore plugins on Linux servers.
*   **Modular Aliases**: Cleanly organized shortcuts in `zsh/aliases.zsh` with dynamic cross-platform support (e.g., color `ls` flags).
*   **Native Fonts**: Automatically downloads and installs the **MesloLGS NF** Powerline font directly to `~/Library/Fonts` (macOS only).
*   **Terminal Profile**: Automatically imports and sets the custom **Zsh** terminal theme (`macos-terminal/zsh.terminal`) as the default macOS Terminal profile.

### Editor (Vim)
*   **Plugin Management**: Automated installation of `vim-plug`.
*   **Curated Plugins**: Includes `vim-go`, `nerdtree`, `vim-fugitive`, and the `molokai` colorscheme.
*   **Cross-Platform Clipboard**: Intelligently switches between `unnamed` (macOS) and `unnamedplus` (Linux).

### Development & Networking
*   **Git Automation**: Links a standardized `.gitconfig` while respecting local overrides. Checks for GitHub CLI (`gh`) authentication.
*   **Secure SSH**: Configures modular `Include` support, automated `authorized_keys` deployment (server mode), and enforces strict `700/600` directory permissions.

### Secrets Management
*   **1Password Ready**: Includes built-in configuration hooks to load environment variables and API keys dynamically using the 1Password CLI (`op`), preventing secrets from lingering in plaintext files.
*   **Local Overrides**: Legacy support for Git-ignored `~/.zshrc.local` files.

---

## 🧪 Robust CI/CD

To ensure the bootstrap script remains highly reliable, this repository features an extensive GitHub Actions pipeline:
1.  **Strict Linting**: Automated syntax validation using `zsh -n` and headless Vim execution.
2.  **Matrix Testing**: Concurrent testing on `macos-latest` (Workstation) and `ubuntu-latest` (Server).
3.  **Dry-Run Assertions**: Verifies that safe-execution modes don't unintentionally alter the CI environment.
