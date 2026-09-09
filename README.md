# 🚀 Dotfiles Bootstrapper (v3.6)

![CI State](https://github.com/janhrabcak/dotfiles/actions/workflows/test.yml/badge.svg)

An **"Infrastructure as Code"** approach to personal computing environments. This repository provides a zero-dependency, idempotent, and verified method to synchronize terminal configurations (Zsh, Vim, Git, SSH) and macOS system defaults across multiple machines.

## ⚡ Quick Start

| Goal | Command |
| :--- | :--- |
| **Remote Install** (No clone) | `/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/janhrabcak/dotfiles/main/dot.sh)" -- --remote` |
| **Local Install** (Clone first) | `git clone https://github.com/janhrabcak/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && ./dot.sh` |
| **Self-Update** | `./dot.sh --update` |
| **Check Health** | `./dot.sh --doctor` |
| **Prune & Rotate Backups** | `./dot.sh --clean` |
| **Run Full Test Suite** | `tests/run-tests.sh` |
| **Run Local CI Docker Test** | `tests/dot-local-ci-test.sh` |
| **Run Specific Step** | `./dot.sh --only setup_vim` |

### Script Flags
*   `--clean`: Prunes dead dotfiles symlinks in `$HOME` and rotates backups (retains 5 most recent).
*   `--remote`: Downloads the latest archive directly from GitHub.
*   `--doctor`: Runs a deep diagnostic of the system health, git hooks, and symlinks.
*   `--only <step>`: Runs a specific setup function only (e.g., `setup_vim`).
*   `--skip <step>`: Skips a specific setup function (can be specified multiple times, e.g., `--skip setup_vim --skip setup_tmux`).
*   `--dry-run`: Preview execution steps without modifying the system.
*   `--test`: Runs a post-setup verification suite (Symlinks, Permissions, SSH).
*   `--install-deps`: Explicitly permits installing missing system packages (`apt-get`/`brew`), Homebrew bundle formulas/casks, Oh My Zsh, fonts, and Vim binary tooling (`fzf`, `vim-go`). Without this flag, the script will never install any binary or external executable.

---

## 🛠️ Feature Breakdown

### 🐚 Shell Environment (Zsh)
*   **Fast-Path Startup**: Lightweight user identity detection, cached hostname lookups, and Zsh completion caching.
*   **Unified Theme**: **Solarized Dark** across Zsh, Vim, and iTerm2 for a seamless, high-performance aesthetic.
*   **Identity**: Integrated **1Password SSH Agent** (macOS) and stable symlinks (Linux) via platform-specific SSH configurations (`macos.config`/`linux.config`).
*   **Shortcuts**:
    *   **Git**: `gs` (status), `ga` (add), `gc` (commit), `gp` (push), `gl` (graph log).
    *   **Tmux**: `tcc` (Control Mode), `tn` (new), `ta` (attach).
    *   **Editor**: `v` / `vim` auto-detecting Neovim when installed.

### 📝 Editor (Vim & Neovim - Power Pack)
*   **Unified Config**: Shared `.vimrc` seamlessly linked to both `~/.vimrc` and `~/.config/nvim/init.vim`.
*   **Visuals**: **Lightline** for a premium, themed status bar.
*   **Productivity**: **FZF** integration for ultra-fast file finding (`Ctrl + p`).
*   **UX**: Persistent undo history, relative line numbers, and smart-case search.
*   **Go Development**: Pre-configured `vim-go` with leader shortcuts.

### 📦 Package Management (Homebrew & Linux)
*   **Homebrew Bundle**: Declares essential CLI tools (`ripgrep`, `fzf`, `tmux`, `gh`, `neovim`) and casks in `config/brew/Brewfile`. Automatically verified during bootstrap.

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
    *   **Git**: Auto-generates local identity template (`.gitconfig.local`), links global configuration via `include.path`, and configures tracked pre-commit hooks (`.githooks`).
    *   **SSH**: Injects a platform-aware `Include` directive into `~/.ssh/config` and manages authorized keys for server environments.
    *   **macOS Defaults**: Applies system-level performance tweaks (key repeat, dock speed) and installs required fonts.
4.  **Verification**: The `--doctor` flag performs deep physical path resolution to ensure all symlinks are pointing to the correct files in the repository.

### Idempotent Helpers
The script uses specialized shell functions to ensure consistency:
*   `safe_link`: Creates symlinks while backing up existing files and repairing broken links.
*   `safe_append/prepend`: Ensures specific configuration lines (like SSH `Include`) exist in files without creating duplicates.
*   `prune_dead_symlinks`: Identifies and removes broken symlinks in `$HOME` pointing into `$DOTFILES_DIR`.
*   `rotate_backups`: Automatically retains only the 5 most recent timestamped backup directories in `~/.dotfiles.backup/`.

---

## 🧠 Technical Appendix (Project Memory)

### 1. The Bootstrap Engine (`dot.sh`)
*   **Doctor Logic**: The `--doctor` flag performs deep physical path resolution (`:A`) to verify integrity even across symlinked directories.
*   **Maintenance & Pruning**: Running `./dot.sh --clean` safely purges broken dotfiles symlinks and rotates snapshot backups.
*   **Local Overrides**: Machine-specific identity is decoupled from version control via auto-generated `.local` files (`config/git/.gitconfig.local` and `~/.zshrc.local`).
*   **Git Pre-commit Hooks**: Tracked in `.githooks/` and active through `core.hooksPath = .githooks`, automatically enforcing shell, vim, and tmux syntax checks before commit.
*   **Dependabot**: Configured in `.github/dependabot.yml` for automated weekly updates of GitHub Actions dependencies.

### 2. SSH Agent Strategy
*   **Linux/Remote**: Uses a **Stable Symlink** at `~/.ssh/ssh_auth_sock`. The `.zshrc` updates this symlink on every fresh login and forces all sub-shells (including those inside tmux) to reference it. This prevents "Dead Agent" syndrome when re-attaching to old sessions.

### 3. iTerm2 Control Mode Hardening
*   **Protocol Protection**: All background output (like TPM initialization) is redirected to `/dev/null` to prevent corrupting the `-CC` handshake.

