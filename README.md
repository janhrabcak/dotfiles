# 🚀 Dotfiles Bootstrapper (v2.1)

![CI State](https://github.com/janhrabcak/dotfiles/actions/workflows/test.yml/badge.svg)

An **"Infrastructure as Code"** approach to personal computing environments. This repository provides a zero-dependency, idempotent, and verified method to synchronize terminal configurations (Zsh, Vim, SSH) and macOS system defaults across multiple machines.

## ⚡ Quick Start

Deploy your environment with a single command:

```zsh
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/janhrabcak/dotfiles/main/bootstrap.sh)" -- --remote
```

## 🏗️ Architecture & Design Principles

*   **Zero Initial Dependency:** Uses `curl` and `tar` instead of `git` for "day zero" setup.
*   **Idempotency:** Every operation is guarded. Running the script multiple times results in the same stable state.
*   **Local-First Priority:** Uses `Include` directives in SSH and Zsh so your machine-specific settings always take precedence.
*   **Context Awareness:** Automatically detects environment to support `--mode workstation` (macOS) and `--mode server` (Linux).
*   **Automated Verification:** Built-in `--test` flag for post-setup smoke testing of symlinks and permissions.

## 🛠️ Implementation Details

### 1. Components
- **Zsh:** Modernized `.zshrc` with Oh My Zsh, auto-suggestions, and syntax highlighting.
- **Vim:** Curated `.vimrc` with `vim-plug` automation and Go development support.
- **SSH:** Secure configuration with `Include` support and automated `authorized_keys` management.
- **macOS:** System-level optimizations (Dock, Finder, Trackpad, Key Repeat).

### 2. Security
- **Strict Permissions:** Enforces `700` for directories and `600` for sensitive files.
- **Isolation:** API keys and local secrets stay in `~/.zshrc.local` (Git-ignored).
- **Secure SSH:** Uses `IdentitiesOnly yes` to prevent accidental key exposure.

## 🧪 CI/CD
Automated testing is performed via GitHub Actions on `macos-latest` and `ubuntu-latest` to ensure the bootstrap remains robust across platforms.
