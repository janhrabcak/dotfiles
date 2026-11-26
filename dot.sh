#!/usr/bin/env zsh

# ==============================================================================
# DOTFILES BOOTSTRAPPER
# ==============================================================================

set -eo pipefail

# --- Configuration ---
GITHUB_USER="janhrabcak"
REPO_NAME="dotfiles"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
BACKUP_DIR="$HOME/.dotfiles.backup/$(date +%Y%m%d_%H%M%S)"
DRY_RUN=false
REMOTE_MODE=false
AUTO_INSTALL_DEPS=false
CLEAN_MODE=false
RUN_DOCTOR=false
RUN_BENCHMARK=false
ONLY_STEP=""

if [[ "$OSTYPE" == "darwin"* ]]; then
    WORK_MODE="macos"
else
    WORK_MODE="linux-server"
fi

# --- Logging Helpers ---
log_info()    { printf "\033[0;34m[INFO]\033[0m  %s\n" "$1"; }
log_warn()    { printf "\033[0;33m[WARN]\033[0m  %s\n" "$1"; }
log_error()   { printf "\033[0;31m[ERROR]\033[0m %s\n" "$1"; }
log_success() { printf "\033[0;32m[OK]\033[0m    %s\n" "$1"; }

# --- CLI Argument Parsing ---
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --dry-run|-d)   DRY_RUN=true; log_warn "DRY RUN MODE ENABLED."; shift ;;
        --remote)       REMOTE_MODE=true; shift ;;
        --mode)
            [[ -z "${2:-}" || "${2:-}" == -* ]] && { log_error "Option --mode requires a value."; exit 1; }
            WORK_MODE="$2"; shift 2 ;;
        --only)
            [[ -z "${2:-}" || "${2:-}" == -* ]] && { log_error "Option --only requires a value."; exit 1; }
            ONLY_STEP="$2"; shift 2 ;;
        --doctor)       RUN_DOCTOR=true; shift ;;
        --benchmark)    RUN_BENCHMARK=true; shift ;;
        --clean)        CLEAN_MODE=true; shift ;;
        --install-deps) AUTO_INSTALL_DEPS=true; export DOTFILES_INSTALL_DEPS=true; shift ;;
        *)              log_error "Unknown parameter: $1"; exit 1 ;;
    esac
done

# --- Execution Wrapper ---
run_cmd() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "   [DRY-RUN] Would execute: $*"
    else
        "$@"
    fi
}

# --- Safety & Idempotency Helpers ---
rotate_backups() {
    local keep="${1:-5}"
    local backup_root="$HOME/.dotfiles.backup"
    [[ -d "$backup_root" ]] || return 0

    local all=("$backup_root"/*(/Non))
    local total=${#all[@]}
    if (( total > keep )); then
        local to_remove=$(( total - keep ))
        log_info "Rotating backups: keeping $keep newest, pruning $to_remove older backup(s)..."
        for dir in "${(@)all[1,to_remove]}"; do
            run_cmd rm -rf "$dir"
            log_success "Pruned old backup: ${dir:t}"
        done
    fi
}

init_backup_dir() {
    [[ "${BACKUP_INITIALIZED:-false}" == "true" ]] && return 0
    BACKUP_INITIALIZED=true
    if [[ ! -d "$BACKUP_DIR" ]]; then
        run_cmd mkdir -p "$BACKUP_DIR"
        rotate_backups 5
    fi
}

safe_append() {
    local line="$1"
    local file="$2"
    if [[ ! -f "$file" ]]; then
        [[ -d "${file:h}" ]] || run_cmd mkdir -p "${file:h}"
        run_cmd touch "$file"
    fi
    if [[ -f "$file" ]] && grep -qxF "$line" "$file"; then
        log_success "Entry already exists in ${file:t}"
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "   [DRY-RUN] Would append to $file: $line"
        else
            printf '%s\n' "$line" >> "$file"
        fi
        log_success "Updated ${file:t} (appended)"
    fi
}

safe_prepend() {
    local line="$1"
    local file="$2"
    if [[ ! -f "$file" ]]; then
        [[ -d "${file:h}" ]] || run_cmd mkdir -p "${file:h}"
        run_cmd touch "$file"
    fi
    if [[ -f "$file" ]] && grep -qxF "$line" "$file"; then
        log_success "Entry already exists in ${file:t}"
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "   [DRY-RUN] Would prepend to $file: $line"
        else
            local tmp_file
            tmp_file="$(mktemp "${file}.tmp.XXXXXX")"
            [[ "$file" == *"/ssh/"* ]] && chmod 600 "$tmp_file"
            printf '%s\n' "$line" > "$tmp_file"
            [[ -f "$file" ]] && cat "$file" >> "$tmp_file"
            mv -f "$tmp_file" "$file"
        fi
        log_success "Updated ${file:t} (prepended)"
    fi
}

safe_link() {
    local src="$1"
    local dest="$2"
    [[ -e "$src" ]] || return 0

    local needs_link=false
    [[ -d "${dest:h}" ]] || run_cmd mkdir -p "${dest:h}"

    if [[ -e "$dest" && ! -L "$dest" ]]; then
        init_backup_dir
        local rel_dest="${dest#$HOME/}"
        [[ "$rel_dest" == "$dest" ]] && rel_dest="${dest:t}"
        local backup_target="$BACKUP_DIR/$rel_dest"
        [[ -d "${backup_target:h}" ]] || run_cmd mkdir -p "${backup_target:h}"
        log_warn "Existing file or directory found at $dest. Moving to backup."
        run_cmd mv "$dest" "$backup_target"
        needs_link=true
    elif [[ -L "$dest" && "${dest:A}" != "${src:A}" ]]; then
        log_warn "Broken or incorrect symlink at $dest. Re-linking."
        run_cmd rm -f "$dest"
        needs_link=true
    elif [[ ! -e "$dest" && ! -L "$dest" ]]; then
        needs_link=true
    fi

    if [[ "$needs_link" == "true" ]]; then
        run_cmd ln -sfn "$src" "$dest"
        log_success "Linked $src to $dest"
    else
        log_success "$dest already correctly linked."
    fi
}

# --- Declarative Link Manifest ---
# Format: "source_relative_to_dotfiles:destination_path:step_owner"
LINK_MANIFEST=(
    "config/zsh/.zshrc:$HOME/.zshrc:setup_zsh"
    "config/zsh/aliases.zsh:$HOME/.aliases.zsh:setup_zsh"
    "config/vim/.vimrc:$HOME/.vimrc:setup_vim"
    "config/vim/.vimrc:$HOME/.config/nvim/init.vim:setup_vim"
    "config/git/.gitignore_global:$HOME/.gitignore_global:setup_git"
    "config/tmux/.tmux.conf:$HOME/.tmux.conf:setup_tmux"
    "config/ai/AGENTS.md:$HOME/.gemini/config/GEMINI.md:setup_ai"
    "config/ai/AGENTS.md:$HOME/.gemini/config/AGENTS.md:setup_ai"
    "config/ai/AGENTS.md:$HOME/.claude/CLAUDE.md:setup_ai"
    "config/ai/settings.json:$HOME/.gemini/settings.json:setup_ai"
    "config/ai/mcp_config.json:$HOME/.gemini/config/mcp_config.json:setup_ai"
    "config/ai/skills:$HOME/.gemini/config/skills:setup_ai"
)

setup_links() {
    local target_step="${1:-}"
    for entry in "${LINK_MANIFEST[@]}"; do
        local src_rel="${entry%%:*}"
        local rest="${entry#*:}"
        local dest="${rest%%:*}"
        local step_owner="${rest#*:}"

        [[ -n "$target_step" && "$step_owner" != "$target_step" ]] && continue
        safe_link "$DOTFILES_DIR/$src_rel" "$dest"
    done
}

prune_dead_symlinks() {
    log_info "Scanning for dead dotfiles symlinks..."
    local canon_dotfiles="${DOTFILES_DIR:A}"
    local raw_prefix="${DOTFILES_DIR%/}/"
    local canon_prefix="${canon_dotfiles%/}/"
    local dead_links=()
    local link target

    local scan_globs=(
        "$HOME"/*(-@N)
        "$HOME"/.*(-@N)
        "$HOME/.config"/**/*(-@N)
        "$HOME/.gemini"/**/*(-@N)
        "$HOME/.claude"/**/*(-@N)
    )
    if [[ "$OSTYPE" == "darwin"* ]]; then
        scan_globs+=("$HOME/Library/Application Support/iTerm2/DynamicProfiles"/*(-@N))
    fi

    for link in "${scan_globs[@]}"; do
        target="$(readlink "$link" 2>/dev/null || true)"
        if [[ "$target" == "$raw_prefix"* || "$target" == "$canon_prefix"* ]]; then
            dead_links+=("$link")
        fi
    done

    if (( ${#dead_links[@]} == 0 )); then
        log_success "No dead dotfiles symlinks found."
        return 0
    fi

    for link in "${dead_links[@]}"; do
        run_cmd rm -f "$link"
        log_success "Removed dead symlink: $link"
    done
}

clean_dotfiles() {
    log_info "🧹 Starting dotfiles cleanup and maintenance..."
    prune_dead_symlinks
    rotate_backups 5
    log_success "Cleanup complete."
}

# --- Setup Steps ---

check_dependencies() {
    log_info "Checking dependencies..."
    local deps=("git" "curl" "vim" "zsh")
    local missing=()

    for dep in "${deps[@]}"; do
        command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
    done

    if (( ${#missing[@]} > 0 )); then
        if [[ "$AUTO_INSTALL_DEPS" == "true" ]]; then
            if command -v apt-get >/dev/null 2>&1; then
                log_info "Installing missing packages via apt-get: ${missing[*]}..."
                run_cmd sudo apt-get update
                run_cmd sudo apt-get install -y "${missing[@]}"
            elif command -v brew >/dev/null 2>&1; then
                log_info "Installing missing packages via brew: ${missing[*]}..."
                run_cmd brew install "${missing[@]}"
            fi
            missing=()
            if [[ "$DRY_RUN" != "true" ]]; then
                for dep in "${deps[@]}"; do
                    command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
                done
            fi
        fi
        if (( ${#missing[@]} > 0 )); then
            log_error "Missing required dependencies: ${missing[*]}"
            log_error "Run dot.sh with --install-deps to permit automated package installation."
            exit 1
        fi
    fi

    if [[ "$OSTYPE" == "darwin"* && "$GITHUB_ACTIONS" != "true" && ! -d "/Applications/iTerm.app" ]]; then
        log_warn "iTerm2 (/Applications/iTerm.app) not found. Run with --install-deps to install via Homebrew bundle."
    fi

    log_success "Dependency check complete."
}

setup_packages() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local brewfile="$DOTFILES_DIR/config/brew/Brewfile"
        command -v brew >/dev/null 2>&1 && [[ -f "$brewfile" ]] || return 0

        log_info "Verifying Homebrew bundle..."
        if [[ "$AUTO_INSTALL_DEPS" == "true" ]]; then
            run_cmd brew bundle --file="$brewfile" || log_warn "Some brew packages could not be installed."
            log_success "Homebrew bundle installed."
        elif [[ "$DRY_RUN" == "true" ]]; then
            echo "   [DRY-RUN] Would check: brew bundle check --file=$brewfile"
        elif brew bundle check --file="$brewfile" >/dev/null 2>&1; then
            log_success "Homebrew bundle packages already satisfied."
        else
            log_warn "Some Homebrew bundle packages are not installed. Run with --install-deps to install."
        fi
        return 0
    fi

    command -v apt-get >/dev/null 2>&1 || return 0
    log_info "Verifying Linux CLI packages..."
    local pkg_map=("tmux:tmux" "rg:ripgrep" "fzf:fzf" "nvim:neovim" "gh:gh")
    local missing_pkgs=()
    local pair bin pkg
    for pair in "${pkg_map[@]}"; do
        bin="${pair%%:*}"
        pkg="${pair#*:}"
        command -v "$bin" >/dev/null 2>&1 || missing_pkgs+=("$pkg")
    done
    if ! command -v fd >/dev/null 2>&1 && ! command -v fdfind >/dev/null 2>&1; then
        missing_pkgs+=("fd-find")
    fi

    if (( ${#missing_pkgs[@]} > 0 )); then
        if [[ "$AUTO_INSTALL_DEPS" == "true" ]]; then
            log_info "Installing optional CLI packages via apt-get: ${missing_pkgs[*]}..."
            run_cmd sudo apt-get update
            run_cmd sudo apt-get install -y "${missing_pkgs[@]}" || log_warn "Some optional apt packages could not be installed."
        else
            log_warn "Optional CLI packages not installed (${missing_pkgs[*]}). Run with --install-deps to install."
        fi
    else
        log_success "Linux CLI packages already satisfied."
    fi

    if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
        [[ -d "$HOME/.local/bin" ]] || run_cmd mkdir -p "$HOME/.local/bin"
        run_cmd ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
    fi
}

download_assets() {
    log_info "Syncing dotfiles repository..."
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        run_cmd git -C "$DOTFILES_DIR" pull --rebase
    else
        local tarball_url="https://github.com/$GITHUB_USER/$REPO_NAME/archive/refs/heads/main.tar.gz"
        [[ -d "$DOTFILES_DIR" ]] || run_cmd mkdir -p "$DOTFILES_DIR"
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "   [DRY-RUN] Would execute: curl -fsSL '$tarball_url' | tar -xzp -C '$DOTFILES_DIR' --strip-components=1"
        else
            curl -fsSL "$tarball_url" | tar -xzp -C "$DOTFILES_DIR" --strip-components=1
        fi
    fi
    log_success "Assets synced to $DOTFILES_DIR"
}

setup_zsh() {
    log_info "Configuring Zsh..."

    if [[ "$GITHUB_ACTIONS" != "true" && ! -d "$HOME/.oh-my-zsh" ]]; then
        if [[ "$AUTO_INSTALL_DEPS" == "true" ]]; then
            log_info "Installing Oh My Zsh (--install-deps permitted)..."
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "   [DRY-RUN] Would install Oh My Zsh"
            else
                sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
            fi
        else
            log_warn "Oh My Zsh not installed at $HOME/.oh-my-zsh. Run with --install-deps to install."
        fi
    fi

    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    local plugins=(
        "zsh-autosuggestions:https://github.com/zsh-users/zsh-autosuggestions"
        "zsh-syntax-highlighting:https://github.com/zsh-users/zsh-syntax-highlighting"
    )
    for plugin_pair in "${plugins[@]}"; do
        local name="${plugin_pair%%:*}"
        local url="${plugin_pair#*:}"
        if [[ ! -d "$zsh_custom/plugins/$name" ]]; then
            if [[ "$AUTO_INSTALL_DEPS" == "true" ]]; then
                run_cmd git clone --depth=1 "$url" "$zsh_custom/plugins/$name"
            else
                log_warn "Zsh plugin '$name' not found. Run with --install-deps to clone."
            fi
        fi
    done

    local iterm_int="$HOME/.iterm2_shell_integration.zsh"
    if [[ ! -f "$iterm_int" && "$AUTO_INSTALL_DEPS" == "true" ]]; then
        run_cmd curl -fsSL https://iterm2.com/shell_integration/zsh -o "$iterm_int"
    fi

    setup_links "setup_zsh"

    if [[ "$SHELL" != *"zsh"* && "$GITHUB_ACTIONS" != "true" && -t 0 ]] && command -v zsh >/dev/null 2>&1; then
        run_cmd chsh -s "$(command -v zsh)" || log_warn "chsh could not update login shell (e.g. LDAP/PAM policy); update manually if needed."
    fi

    log_success "Zsh environment ready."
}

setup_vim() {
    log_info "Setting up Vim & Neovim..."
    local plug_url="https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
    local plug_dest="$HOME/.vim/autoload/plug.vim"

    setup_links "setup_vim"
    run_cmd mkdir -p "$HOME/.vim/undo"

    if [[ "$AUTO_INSTALL_DEPS" == "true" ]]; then
        [[ -f "$plug_dest" ]] || run_cmd curl -fLo "$plug_dest" --create-dirs "$plug_url"
        DOTFILES_INSTALL_DEPS=true run_cmd vim +PlugInstall +qall!
    elif [[ ! -f "$plug_dest" ]]; then
        log_warn "Vim-Plug not found at $plug_dest. Run with --install-deps to install plugins."
    fi
    log_success "Vim & Neovim ready."
}

setup_tmux() {
    log_info "Setting up Tmux..."
    local tpm_dir="$HOME/.tmux/plugins/tpm"
    if [[ ! -d "$tpm_dir" ]]; then
        if [[ "$AUTO_INSTALL_DEPS" == "true" ]]; then
            [[ -d "${tpm_dir:h}" ]] || run_cmd mkdir -p "${tpm_dir:h}"
            run_cmd git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
        else
            log_warn "Tmux Plugin Manager (TPM) not found. Run with --install-deps to clone."
        fi
    fi
    setup_links "setup_tmux"
    log_success "Tmux ready."
}

has_git_include() {
    local conf_file="$1" expected_path="$2"
    [[ -f "$conf_file" ]] || return 1
    git config --file "$conf_file" --get-all include.path 2>/dev/null | grep -qxF "$expected_path"
}

has_ssh_include() {
    local conf_file="$1" expected_inc="Include $2" line trimmed
    [[ -f "$conf_file" ]] || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        trimmed="${line#"${line%%[![:space:]]*}"}"
        [[ "$trimmed" == "$expected_inc" ]] && return 0
    done < "$conf_file"
    return 1
}

setup_git() {
    log_info "Configuring Git..."
    local git_conf_src="$DOTFILES_DIR/config/git/.gitconfig"
    local git_conf_dest="$HOME/.gitconfig"

    setup_links "setup_git"

    if [[ -f "$git_conf_src" ]]; then
        if ! has_git_include "$git_conf_dest" "$git_conf_src"; then
            run_cmd git config --global --add include.path "$git_conf_src"
            log_success "Git config linked."
        else
            log_success "Git config already linked."
        fi
    fi

    if [[ -d "$DOTFILES_DIR/.git" && -d "$DOTFILES_DIR/.githooks" ]]; then
        run_cmd git -C "$DOTFILES_DIR" config core.hooksPath .githooks
        log_success "Git pre-commit and pre-push hooks configured (.githooks)."
    fi
}

setup_ssh() {
    log_info "Configuring SSH (Mode: $WORK_MODE)..."
    run_cmd mkdir -p "$HOME/.ssh"
    run_cmd chmod 700 "$HOME/.ssh"

    local ssh_filename="linux.config"
    [[ "$WORK_MODE" == "macos" ]] && ssh_filename="macos.config"
    local git_ssh_conf="$DOTFILES_DIR/config/ssh/$ssh_filename"
    local local_ssh_conf="$HOME/.ssh/config"

    if [[ -f "$git_ssh_conf" ]]; then
        run_cmd chmod 600 "$git_ssh_conf"

        local other_filename="macos.config"
        [[ "$ssh_filename" == "macos.config" ]] && other_filename="linux.config"
        local other_ssh_conf="$DOTFILES_DIR/config/ssh/$other_filename"

        if has_ssh_include "$local_ssh_conf" "$other_ssh_conf"; then
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "   [DRY-RUN] Would remove stale Include $other_ssh_conf from $local_ssh_conf"
            else
                local tmp_conf
                tmp_conf="$(mktemp "${local_ssh_conf}.tmp.XXXXXX")"
                chmod 600 "$tmp_conf"
                grep -vxF "Include $other_ssh_conf" "$local_ssh_conf" > "$tmp_conf" || true
                mv -f "$tmp_conf" "$local_ssh_conf"
            fi
        fi

        safe_prepend "Include $git_ssh_conf" "$local_ssh_conf"
        run_cmd chmod 600 "$local_ssh_conf"
    fi

    if [[ "$WORK_MODE" == "linux-server" ]]; then
        local git_auth_keys="$DOTFILES_DIR/config/ssh/authorized_keys"
        [[ -f "$DOTFILES_DIR/config/ssh/authorized_keys.local" ]] && git_auth_keys="$DOTFILES_DIR/config/ssh/authorized_keys.local"
        local local_auth_keys="$HOME/.ssh/authorized_keys"
        if [[ -f "$git_auth_keys" ]]; then
            while IFS= read -r key; do
                [[ -z "$key" || "$key" =~ ^# ]] && continue
                safe_append "$key" "$local_auth_keys"
            done < "$git_auth_keys"
            run_cmd chmod 600 "$local_auth_keys"
            log_success "Authorized keys imported from ${git_auth_keys:t}."
        fi
    fi
}

setup_iterm2() {
    [[ "$OSTYPE" == "darwin"* && "$WORK_MODE" == "macos" ]] || return 0
    log_info "Configuring iTerm2 Dynamic Profiles..."

    local iterm_profiles_src="$DOTFILES_DIR/config/iterm2/profiles.json"
    local iterm_profiles_dest="$HOME/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json"
    if [[ -f "$iterm_profiles_src" ]]; then
        safe_link "$iterm_profiles_src" "$iterm_profiles_dest"
    fi

    run_cmd defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool false
    run_cmd defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "A8B35DB8-2639-4712-865E-53ADC0FA22BF"
    run_cmd defaults write com.googlecode.iterm2 TmuxUsesDedicatedProfile -bool true
    run_cmd defaults write com.googlecode.iterm2 GPU -bool true
    run_cmd defaults write com.googlecode.iterm2 CopySelection -bool true
    run_cmd defaults write com.googlecode.iterm2 PromptOnQuit -bool false
    run_cmd defaults write com.googlecode.iterm2 MaxPasteHistoryEntries -int 50
    run_cmd defaults write com.googlecode.iterm2 AutohideTmuxClientSession -bool true
    run_cmd defaults write com.googlecode.iterm2 OpenTmuxWindowsAs -int 0
    run_cmd defaults write com.googlecode.iterm2 OpenTmuxWindowsIn -int 1
    run_cmd defaults write com.googlecode.iterm2 OpenTmuxDashboardIfMoreThanXWindows -int 999
    run_cmd defaults write com.googlecode.iterm2 SshIntegrationForURLs -bool true
    log_success "iTerm2 complete."
}

setup_macos() {
    [[ "$OSTYPE" == "darwin"* && "$WORK_MODE" == "macos" ]] || return 0
    log_info "Applying macOS Defaults & Fonts..."

    local font_dest="$HOME/Library/Fonts/MesloLGS NF Regular.ttf"
    if [[ ! -f "$font_dest" && "$AUTO_INSTALL_DEPS" == "true" ]]; then
        run_cmd mkdir -p "$HOME/Library/Fonts"
        run_cmd curl -fLo "$font_dest" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
    fi

    run_cmd defaults write NSGlobalDomain KeyRepeat -int 1
    run_cmd defaults write NSGlobalDomain InitialKeyRepeat -int 15
    run_cmd defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    run_cmd defaults write com.apple.finder AppleShowAllExtensions -bool true
    run_cmd defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
    run_cmd defaults write com.apple.dock autohide -bool true
    run_cmd defaults write com.apple.dock autohide-delay -float 0
    run_cmd defaults write com.apple.dock tilesize -int 48

    [[ "$DRY_RUN" == "false" ]] && { killall Finder Dock >/dev/null 2>&1 || true; }
    log_success "macOS complete."
}

setup_ai() {
    log_info "Setting up AI Agents (Gemini & Claude)..."
    setup_links "setup_ai"
    log_success "AI agents configuration complete."
}

run_doctor() {
    log_info "🩺 Starting Dotfiles Diagnostic..."
    local errors=0

    for entry in "${LINK_MANIFEST[@]}"; do
        local src_rel="${entry%%:*}"
        local rest="${entry#*:}"
        local dest="${rest%%:*}"
        local src="$DOTFILES_DIR/$src_rel"

        if [[ -L "$dest" && "${dest:A}" == "${src:A}" ]]; then
            log_success "Link OK: ${dest:t}"
        else
            log_error "Link BROKEN: ${dest:t} -> expected $src"
            errors=$((errors + 1))
        fi
    done

    local git_conf="$HOME/.gitconfig"
    if has_git_include "$git_conf" "$DOTFILES_DIR/config/git/.gitconfig"; then
        log_success "Git: Include directive present in $git_conf"
    else
        log_error "Git: Include directive MISSING in $git_conf"
        errors=$((errors + 1))
    fi

    local ssh_conf="$HOME/.ssh/config"
    local ssh_filename="linux.config"
    [[ "$WORK_MODE" == "macos" ]] && ssh_filename="macos.config"
    if has_ssh_include "$ssh_conf" "$DOTFILES_DIR/config/ssh/$ssh_filename"; then
        log_success "SSH: Include directive present in $ssh_conf"
    else
        log_error "SSH: Include directive MISSING in $ssh_conf"
        errors=$((errors + 1))
    fi

    if [[ "$OSTYPE" == "darwin"* && "$WORK_MODE" == "macos" ]]; then
        local iterm_dyn="$HOME/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json"
        local iterm_src="$DOTFILES_DIR/config/iterm2/profiles.json"
        if [[ -L "$iterm_dyn" && "${iterm_dyn:A}" == "${iterm_src:A}" ]]; then
            log_success "iTerm2: Dynamic Profile linked (${iterm_dyn:t})"
        else
            log_error "iTerm2: Dynamic Profile MISSING at $iterm_dyn"
            errors=$((errors + 1))
        fi
    fi

    if [[ $errors -eq 0 ]]; then
        log_success "All systems operational!"
        return 0
    else
        log_error "Detected $errors issue(s). Run dot.sh to repair."
        return 1
    fi
}

run_benchmark() {
    log_info "⚡ Running performance benchmarks..."
    zmodload zsh/datetime
    local errors=0

    # 1. Zsh Startup Time
    float t0=$(( EPOCHREALTIME * 1000 ))
    if zsh -i -c exit >/dev/null 2>&1; then
        float t1=$(( EPOCHREALTIME * 1000 ))
        integer zsh_ms=$(( t1 - t0 ))
        if (( zsh_ms < 150 )); then
            log_success "Zsh startup latency: ${zsh_ms}ms (target < 150ms)"
        else
            log_warn "Zsh startup latency: ${zsh_ms}ms (target < 150ms)"
        fi
    else
        log_error "Zsh interactive startup failed."
        errors=$((errors + 1))
    fi

    # 2. Vim Headless Startup Time
    if command -v vim >/dev/null 2>&1; then
        local vimrc="$DOTFILES_DIR/config/vim/.vimrc"
        [[ -f "$HOME/.vimrc" ]] && vimrc="$HOME/.vimrc"
        if [[ -f "$vimrc" ]]; then
            float vt0=$(( EPOCHREALTIME * 1000 ))
            if vim -u "$vimrc" -e -s -c "q" >/dev/null 2>&1; then
                float vt1=$(( EPOCHREALTIME * 1000 ))
                integer vim_ms=$(( vt1 - vt0 ))
                if (( vim_ms < 150 )); then
                    log_success "Vim startup latency: ${vim_ms}ms (target < 150ms)"
                else
                    log_warn "Vim startup latency: ${vim_ms}ms (target < 150ms)"
                fi
            else
                log_error "Vim startup check failed while loading $vimrc."
                errors=$((errors + 1))
            fi
        else
            log_warn "Vim config not found at $vimrc; skipping Vim benchmark."
        fi
    fi

    # 3. Zsh Prompt Execution (vcs_info + build_prompt inside repo context)
    local zshrc="$DOTFILES_DIR/config/zsh/.zshrc"
    [[ -f "$HOME/.zshrc" ]] && zshrc="$HOME/.zshrc"
    if [[ -f "$zshrc" ]]; then
        local prompt_raw
        if prompt_raw=$(zsh -c "
            [[ -d '$DOTFILES_DIR' ]] && cd '$DOTFILES_DIR'
            zmodload zsh/datetime
            source '$zshrc' >/dev/null 2>&1
            float pt0=\$(( EPOCHREALTIME * 1000 ))
            vcs_info >/dev/null 2>&1
            build_prompt >/dev/null 2>&1
            float pt1=\$(( EPOCHREALTIME * 1000 ))
            integer p_diff=\$(( pt1 - pt0 ))
            print \$p_diff
        " 2>/dev/null); then
            integer prompt_ms=${prompt_raw:-0}
            if (( prompt_ms < 50 )); then
                log_success "Prompt render latency: ${prompt_ms}ms (target < 50ms)"
            else
                log_warn "Prompt render latency: ${prompt_ms}ms (target < 50ms)"
            fi
        else
            log_error "Prompt render benchmark failed while sourcing $zshrc."
            errors=$((errors + 1))
        fi
    fi

    return $(( errors > 0 ? 1 : 0 ))
}

# --- Main Execution ---
main() {
    if [[ "$CLEAN_MODE" == "true" ]]; then
        clean_dotfiles
        exit 0
    fi

    if [[ "$RUN_DOCTOR" == "true" ]]; then
        run_doctor
        exit $?
    fi

    if [[ "$RUN_BENCHMARK" == "true" ]]; then
        run_benchmark
        exit $?
    fi

    check_dependencies

    if [[ "$REMOTE_MODE" == "true" ]]; then
        download_assets
    elif [[ ! -d "$DOTFILES_DIR" ]]; then
        log_error "Dotfiles directory ($DOTFILES_DIR) not found. Clone it or pass --remote."
        exit 1
    fi

    if [[ -n "$ONLY_STEP" ]]; then
        if (( $+functions[$ONLY_STEP] )); then
            "$ONLY_STEP"
            exit 0
        else
            log_error "Function '$ONLY_STEP' does not exist."
            exit 1
        fi
    fi

    local steps=(setup_packages setup_zsh setup_vim setup_tmux setup_git setup_ssh setup_iterm2 setup_macos setup_ai)
    for step in "${steps[@]}"; do
        "$step"
    done

    echo "\n✨ Setup complete! Run with --doctor to verify integrity."
}

if [[ "${ZSH_EVAL_CONTEXT:-}" != *:file* ]]; then
    main
fi
