# 🚀 Dotfiles Bootstrapper (v3.7)

![CI State](https://github.com/janhrabcak/dotfiles/actions/workflows/test.yml/badge.svg)

An **"Infrastructure as Code"** approach to personal computing environments. This repository provides a zero-dependency, idempotent, and verified method to synchronize terminal configurations (Zsh, Vim, Git, SSH) and macOS system defaults across multiple machines.

## ⚡ Quick Start

| Goal | Command |
| :--- | :--- |
| **Remote Install** (No clone) | `/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/janhrabcak/dotfiles/main/dot.sh)" -- --remote` |
| **Local Install** (Clone first) | `git clone https://github.com/janhrabcak/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && ./dot.sh` |
| **Check Health** | `./dot.sh --doctor` |
| **Prune & Rotate Backups** | `./dot.sh --clean` |
| **Run Full Test Suite** | `tests/run-tests.sh` |
| **Run Specific Step** | `./dot.sh --only setup_vim` |

### Script Flags
*   `--clean`: Prunes dead dotfiles symlinks in `$HOME` and rotates backups (retains 5 most recent).
*   `--remote`: Downloads the latest archive directly from GitHub.
*   `--doctor`: Runs a deep diagnostic of the system health, git hooks, and symlinks.
*   `--only <step>`: Runs a specific setup function only (e.g., `setup_vim`).
*   `--mode <mode>`: Overrides OS mode detection (`macos`, `linux-server`, `linux-client`).
*   `--dry-run` (`-d`): Preview execution steps without modifying the system.
*   `--install-deps`: Explicitly permits installing missing system packages (`apt-get`/`brew`), Homebrew bundle formulas/casks, Oh My Zsh, fonts, and Vim binary tooling (`fzf`, `vim-go`). Without this flag, the script will never install any binary or external executable.

---

## 🎨 Visual Showcase

### 🖥️ 1. Agnoster Powerline Zsh Terminal
High-performance prompt driven by native Zsh `vcs_info` (zero child `git` process forks per prompt):
```text
╭─  Google Identity  ~/.../dotfiles   main ✚ ± 
╰─ gs
On branch main
Your branch is up to date with 'origin/main'.
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
	modified:   config/git/.gitconfig
```

### 📝 2. Vim & Neovim Power Pack
Unified `.vimrc` with Solarized Dark aesthetics, Lightline statusline, and FZF:
```text
  1 package main
  2 
  3 import "fmt"
  4 
  5 func main() {
  6     fmt.Println("Dotfiles verified & operational!")
  7 }
~                                                           
[NORMAL]  main.go  utf-8 [unix]  go  100%  6:1 
```

### 🪟 3. Tmux Native Control Mode (`-CC`)
Runs tmux sessions natively inside macOS iTerm2 tabs or standard terminal multiplexer windows:
```text
[0] 0:zsh* 1:vim- 2:server                                              "dev-box" 21:15 17-Oct-26
```

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

### 🔧 Git & Global Excludes
*   **Global Gitignore**: Pre-configured `config/git/.gitignore_global` linked to `~/.gitignore_global` and active via `core.excludesfile`, filtering out OS clutter (`.DS_Store`, `Thumbs.db`), editor swap files (`*.swp`), and IDE folders (`.idea/`, `.vscode/*`).
*   **Identity Management**: Local identity template (`config/git/.gitconfig.local.example`) kept out of version control.
*   **Tracked Hooks**: Enforces pre-commit checks automatically through `core.hooksPath = .githooks`.

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

### 🤖 AI Agent Environments (Gemini & Claude)
*   **Universal Guidelines (`AGENTS.md`)**: Single source of truth in `config/ai/AGENTS.md` automatically symlinked to Gemini/Antigravity (`~/.gemini/config/GEMINI.md`, `~/.gemini/config/AGENTS.md`) and Claude Code (`~/.claude/CLAUDE.md`). Enforces concise technical explanations, Conventional Commits, proactive test verification, code integrity, and zero-secrets security.
*   **Security & Command Whitelist**: Pre-approved non-destructive inspection commands (`rg`, `find`, `git status/diff/log/branch/show`, runtime version lookups, and test runners) in `settings.json` for seamless agent pair programming without confirmation popups.
*   **Global MCP Servers**: Model Context Protocol integration (`mcp_config.json`) pre-configured for persistent memory graph (`@modelcontextprotocol/server-memory`), GitHub API integration (`@modelcontextprotocol/server-github`), and Markdown web scraping (`mcp-fetch-server`).
*   **Custom Global Skills**: Progressive-disclosure playbooks for `conventional-release` (automated SemVer bumps, changelog updates, and release tagging) and Sentry `code-review` (Sentry engineering practices, runtime/ORM optimization, and empathy guidelines).
*   **Dual-Audience Documentation**: Mandates that code modifications update both human-facing documentation (README, guides, changelogs) and agent-facing contextual memory (invariants, caveats, and architectural constraints in `AGENTS.md`).

### 🐳 Isolated Dev Container & Codespaces
Test and experiment with the dotfiles in a sandboxed Docker container without modifying your local system:
*   **VS Code / Cursor**: Run **Remote-Containers: Reopen in Container** (`.devcontainer/devcontainer.json`).
*   **GitHub Codespaces**: Create a Codespace on this repository to automatically provision a full Zsh, Vim, and Tmux environment.
*   **Automated Bootstrap**: Automatically provisions `linux-client` mode and links the workspace on container startup.

---

## 🏗️ How it Works (`dot.sh`)

The `dot.sh` script is a robust, idempotent bootstrapper designed to configure a fresh machine or update an existing one in seconds.

### Core Principles
*   **Idempotency**: Every operation is designed to be run multiple times without changing the result beyond the initial application. It checks if a link exists or a config line is present before acting.
*   **Safety First**: Before overwriting any existing configuration file, the script moves it to a timestamped backup directory (`~/.dotfiles.backup/`).
*   **Dry Run Support**: Use `--dry-run` to see exactly what the script would do without making any changes to your system.

### Execution Lifecycle
1.  **Dependency Check**: Ensures `git`, `curl`, `vim`, and `zsh` are installed. On macOS, it also checks for iTerm2.
2.  **Asset Synchronization**: Verifies `~/.dotfiles` exists locally or, in `--remote` mode, downloads and extracts the latest archive directly from GitHub.
3.  **Modular Setup Phases**:
    *   **Zsh**: Installs Oh My Zsh, custom plugins (autosuggestions, syntax highlighting), and links `.zshrc` and `aliases.zsh`.
    *   **Vim**: Bootstraps `vim-plug`, links `.vimrc` and Neovim `init.vim`, and triggers plugin installation.
    *   **Git**: Links global configuration via `include.path` and configures tracked pre-commit hooks (`.githooks`).
    *   **SSH**: Injects a platform-aware `Include` directive into `~/.ssh/config` and manages authorized keys for server environments.
    *   **macOS Defaults**: Applies system-level performance tweaks (key repeat, dock speed), iTerm2 dynamic profiles, and required fonts.
    *   **AI Agents (`setup_ai`)**: Links universal AI developer guidelines, command whitelist permissions, MCP servers, and custom skills across Gemini and Claude Code.
4.  **Verification**: The `--doctor` flag performs deep physical path resolution to ensure all symlinks are pointing to the correct files in the repository.

### Idempotent Helpers
The script uses specialized shell functions to ensure consistency:
*   `safe_link`: Creates symlinks while backing up existing files and repairing broken links.
*   `safe_append/prepend`: Ensures specific configuration lines (like SSH `Include`) exist in files without creating duplicates.
*   `prune_dead_symlinks`: Uses native Zsh `(-@N)` broken-symlink globbing to identify and remove dead symlinks in `$HOME` pointing into `$DOTFILES_DIR`.
*   `rotate_backups`: Automatically retains only the 5 most recent timestamped backup directories in `~/.dotfiles.backup/`.

---

## 🧠 Technical Appendix (Project Memory)

### 1. The Bootstrap Engine (`dot.sh`)
*   **Doctor Logic**: The `--doctor` flag performs deep physical path resolution (`:A`) to verify integrity even across symlinked directories.
*   **Maintenance & Pruning**: Running `./dot.sh --clean` safely purges broken dotfiles symlinks and rotates snapshot backups.
*   **Local Overrides**: Machine-specific identity and private shell settings are decoupled from version control via optional `.local` files (`config/git/.gitconfig.local`, `~/.zshrc.local`, and `config/ssh/authorized_keys.local`).
*   **Git Pre-commit Hooks**: Tracked in `.githooks/` and active through `core.hooksPath = .githooks`, automatically enforcing shell, headless Vim, and isolated-socket (`-L`) Tmux syntax checks before commit without disturbing active user sessions.
*   **Dependabot**: Configured in `.github/dependabot.yml` for automated weekly updates of GitHub Actions dependencies.

### 2. SSH Agent Strategy
*   **Linux/Remote**: Uses a **Stable Symlink** at `~/.ssh/ssh_auth_sock`. The `.zshrc` updates this symlink on every fresh login and forces all sub-shells (including those inside tmux) to reference it. This prevents "Dead Agent" syndrome when re-attaching to old sessions.

### 3. iTerm2 Control Mode Hardening
*   **Protocol Protection**: All background output (like TPM initialization) is redirected to `/dev/null` to prevent corrupting the `-CC` handshake.

