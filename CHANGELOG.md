# Changelog

All notable changes to this project will be documented in this file.

## [v3.0.0] - 2026-04-26
### Added
- **Dotfiles Doctor**: Added deep diagnostic suite (`./dot.sh --doctor`) using Absolute Physical Resolution (`:A`) to verify symlinks.
- **iTerm2 Native Visuals**: Transitioned to native tab coloring using iTerm2 Automatic Profile Switching, moving away from Zsh-driven terminal escape sequences for performance and stability.
- **Vim Power Pack**: Upgraded Vim setup with `fzf`, `lightline`, `solarized` dark theme, persistent undo (`undofile`), and relative line numbers.
- **Total Silence Strategy**: Hardened environment against random terminal bells (disabled in Zsh, Vim, and iTerm2).
- **Self-Update**: Added `--update` flag to `dot.sh` to allow the script to easily pull the latest remote changes when managing the repository locally.

### Changed
- **SSH Agent Persistence**: Hardened stable symlink creation in `~/.ssh/ssh_auth_sock` for Linux to fix "Dead Agent" syndrome in old tmux sessions. macOS now strictly relies on the 1Password IdentityAgent socket.
- **Prompt Logic**: Unified Google Rainbow and standard Red SSH prompts into a single cleaner `prompt_context` segment with the official Google logo color palette (Blue, Red, Yellow, Blue, Green, Red).
- **TPM Initialization**: Removed silent error suppression from `tmux.conf` TPM initialization; now redirects to `~/.tmux/tpm.log`.

### Removed
- Removed legacy `prompt_bzr` and `prompt_hg` from the Zsh agnoster prompt sequence to improve prompt render speed.
- Removed arbitrary `nowritebackup` command from `.vimrc`.
