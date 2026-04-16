# Technical Design Document: Idempotent Environment Bootstrapper (v2.0)

## 1. Executive Summary
This project is an "Infrastructure as Code" approach to personal computing environments. It provides a zero-dependency, idempotent, and verified method to synchronize terminal configurations (Zsh, Vim, SSH) and macOS system defaults across multiple machines.

## 2. Architecture & Design Principles
* **Zero Initial Dependency:** Uses `curl` and `tar` instead of `git` for "day zero" setup.
* **Idempotency:** Every operation is guarded. Running the script N times results in the same state as running it once.
* **Local-First Priority:** Uses `Include` directives in SSH/Git so local settings take precedence.
* **Context Awareness:** Supports `--mode workstation` (macOS) and `--mode server` (Linux).

## 3. Implementation Logic
- **Bootstrap One-Liner:** `/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/janhrabcak/dotfiles/main/bootstrap.sh)" -- --remote`
- **Verification:** Built-in `--test` flag for post-setup smoke testing.
- **CI/CD:** Automated testing via GitHub Actions on `macos-latest` and `ubuntu-latest`.

## 4. Security
- API keys must stay in `~/.zshrc.local` (Git-ignored).
- SSH Config uses `IdentitiesOnly yes` to prevent permission errors.
- Permissions are strictly enforced (700 for folders, 600 for files).
