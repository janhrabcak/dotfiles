#!/usr/bin/env zsh

# ==============================================================================
# BOOTSTRAP SCRIPT (v3.4)
# ==============================================================================

set -e 

# --- Configuration ---
GITHUB_USER="janhrabcak"
REPO_NAME="dotfiles"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
BACKUP_DIR="$HOME/.dotfiles.backup/$(date +%Y%m%d_%H%M%S)"
DRY_RUN=false
REMOTE_MODE=false
# Detect OS and set default mode
if [[ "$OSTYPE" == "darwin"* ]]; then
    WORK_MODE="macos"
else
    WORK_MODE="linux-server"
fi
ONLY_STEP=""

# --- Logging Helpers ---
log_info()    { echo "\033[0;34m[INFO]\033[0m  $1"; }
log_warn()    { echo "\033[0;33m[WARN]\033[0m  $1"; }
log_error()   { echo "\033[0;31m[ERROR]\033[0m $1"; }
log_success() { echo "\033[0;32m[OK]\033[0m    $1"; }

# --- CLI Argument Parsing ---
ORIGINAL_ARGS=("$@")

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run|-d) DRY_RUN=true; log_warn "DRY RUN MODE ENABLED."; shift ;;
        --remote)    REMOTE_MODE=true; shift ;;
        --update)    UPDATE_MODE=true; shift ;;
        --mode)      WORK_MODE="$2"; shift 2 ;;
        --only)      ONLY_STEP="$2"; shift 2 ;;
        --skip)      SKIP_STEP="$2"; shift 2 ;;
        --doctor)    RUN_DOCTOR=true; shift ;;
        --test)      RUN_TESTS=true; shift ;;
        *) log_error "Unknown parameter: $1"; exit 1 ;;
    esac
done

# --- Execution Wrapper ---
execute() {
    local cmd=$1
    local critical=${2:-false}
    
    if [ "$DRY_RUN" = true ]; then
        echo "   [DRY-RUN] Would execute: $cmd"
    else
        if eval "$cmd"; then
            return 0
        else
            log_error "Command failed: $cmd"
            if [ "$critical" = true ]; then
                echo "\033[0;31mFATAL: Critical step failed. Aborting.\033[0m"
                exit 1
            fi
            return 0
        fi
    fi
}

# --- Safety/Idempotency Helpers ---

init_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        execute "mkdir -p '$BACKUP_DIR'"
    fi
}

safe_append() {
    local line="$1"
    local file="$2"
    if [ ! -f "$file" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "   [DRY-RUN] Would create: $file"
        else
            execute "mkdir -p '$(dirname "$file")' && touch '$file'"
        fi
    fi
    if [ -f "$file" ] && grep -qsF "$line" "$file"; then
        log_success "Entry already exists in $(basename "$file")"
    else
        if [ "$DRY_RUN" = true ]; then
            echo "   [DRY-RUN] Would append to $file: $line"
        else
            printf '%s\n' "$line" >> "$file"
        fi
        log_success "Updated $(basename "$file") (appended)"
    fi
}

safe_prepend() {
    local line="$1"
    local file="$2"
    if [ ! -f "$file" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "   [DRY-RUN] Would create: $file"
        else
            execute "mkdir -p '$(dirname "$file")' && touch '$file'"
        fi
    fi
    if [ -f "$file" ] && grep -qxF "$line" "$file"; then
        log_success "Entry already exists in $(basename "$file")"
    else
        if [ "$DRY_RUN" = true ]; then
            echo "   [DRY-RUN] Would prepend to $file: $line"
        else
            local tmp_file
            tmp_file="$(mktemp "${file}.tmp.XXXXXX")"
            if [[ "$file" == *"/ssh/"* ]]; then
                chmod 600 "$tmp_file"
            fi
            printf '%s\n' "$line" > "$tmp_file"
            [ -f "$file" ] && cat "$file" >> "$tmp_file"
            mv -f "$tmp_file" "$file"
        fi
        log_success "Updated $(basename "$file") (prepended)"
    fi
}

safe_link() {
    local src="$1"
    local dest="$2"
    if [ -e "$src" ]; then
        local needs_link=false
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            init_backup_dir
            log_warn "Existing file found at $dest. Moving to backup."
            execute "mv '$dest' '$BACKUP_DIR/$(basename "$dest")'"
            needs_link=true
        elif [ -L "$dest" ] && [ "${dest:A}" != "${src:A}" ]; then
            log_warn "Broken or incorrect symlink at $dest. Re-linking."
            execute "rm -f '$dest'"
            needs_link=true
        elif [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
            needs_link=true
        fi
        
        if [ "$needs_link" = true ]; then
            execute "ln -sfn '$src' '$dest'"
            log_success "Linked $src to $dest"
        else
            log_success "$dest already correctly linked."
        fi
    fi
}

# --- Functions ---

check_dependencies() {
    log_info "Step 0: Checking dependencies..."
    local deps=("git" "curl" "vim" "zsh")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    # Check for iTerm2 on macOS (skip in CI)
    if [[ "$OSTYPE" == "darwin"* && "$GITHUB_ACTIONS" != "true" ]]; then
        [[ -d "/Applications/iTerm.app" ]] || missing+=("iTerm2 (App)")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing[*]}"
        exit 1
    fi
    log_success "Dependency check complete."
}

download_assets() {
    log_info "Step 1: Downloading dotfiles archive..."
    if [ -d "$DOTFILES_DIR/.git" ]; then
        log_info "Git repository found. Pulling latest changes..."
        execute "git -C '$DOTFILES_DIR' pull --rebase" true
    else
        local TARBALL_URL="https://github.com/$GITHUB_USER/$REPO_NAME/archive/refs/heads/main.tar.gz"
        [ ! -d "$DOTFILES_DIR" ] && execute "mkdir -p '$DOTFILES_DIR'" true
        execute "curl -fsSL '$TARBALL_URL' | tar -xzp -C '$DOTFILES_DIR' --strip-components=1" true
    fi
    log_success "Assets synced to $DOTFILES_DIR"
}

install_zsh_plugins() {
    local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    local plugins=(
        "zsh-autosuggestions:https://github.com/zsh-users/zsh-autosuggestions"
        "zsh-syntax-highlighting:https://github.com/zsh-users/zsh-syntax-highlighting"
    )

    for plugin_pair in "${plugins[@]}"; do
        local name="${plugin_pair%%:*}"
        local url="${plugin_pair#*:}"
        if [ ! -d "$ZSH_CUSTOM/plugins/$name" ]; then
            log_info "Cloning $name..."
            execute "git clone --depth=1 '$url' '$ZSH_CUSTOM/plugins/$name'"
        fi
    done
}

setup_zsh() {
    log_info "Step 2: Configuring Zsh & Oh My Zsh..."
    
    # 1. Install Oh My Zsh
    if [[ "$GITHUB_ACTIONS" != "true" && ! -d "$HOME/.oh-my-zsh" ]]; then
        execute "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended --keep-zshrc"
        log_success "Oh My Zsh installed."
    fi

    # 2. Install Custom Plugins
    install_zsh_plugins

    # 3. iTerm2 Shell Integration
    local ITERM_SHELL_INT="$HOME/.iterm2_shell_integration.zsh"
    if [ ! -f "$ITERM_SHELL_INT" ]; then
        log_info "Downloading iTerm2 shell integration..."
        execute "curl -fsSL https://iterm2.com/shell_integration/zsh -o '$ITERM_SHELL_INT'"
    fi

    # 4. Change Default Shell
    if [[ "$SHELL" != *"zsh"* && "$GITHUB_ACTIONS" != "true" ]]; then
        if command -v zsh >/dev/null 2>&1; then
            local zsh_path=$(command -v zsh)
            log_info "Changing default shell to $zsh_path (may prompt for password)."
            execute "chsh -s '$zsh_path'"
        fi
    fi

    # 4. Link Configurations
    safe_link "$DOTFILES_DIR/config/zsh/.zshrc" "$HOME/.zshrc"
    safe_link "$DOTFILES_DIR/config/zsh/aliases.zsh" "$HOME/.aliases.zsh"
    [ -d "$DOTFILES_DIR/bin" ] && safe_link "$DOTFILES_DIR/bin" "$HOME/.bin"
    
    log_success "Zsh environment ready."
}

setup_vim() {
    log_info "Step 3: Setting up Vim..."
    local PLUG_URL="https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
    local PLUG_DEST="$HOME/.vim/autoload/plug.vim"
    
    if [ ! -f "$PLUG_DEST" ]; then
        execute "curl -fLo '$PLUG_DEST' --create-dirs '$PLUG_URL'" true
        log_success "Vim-Plug installed."
    fi

    safe_link "$DOTFILES_DIR/config/vim/.vimrc" "$HOME/.vimrc"
    execute "mkdir -p '$HOME/.vim/undo'"
    log_info "Installing Vim plugins..."
    execute "vim +PlugInstall +qall!"
    log_success "Vim ready."
}

setup_tmux() {
    log_info "Step 4: Setting up Tmux..."
    local TPM_DIR="$HOME/.tmux/plugins/tpm"
    if [ ! -d "$TPM_DIR" ]; then
        execute "mkdir -p '$(dirname "$TPM_DIR")'"
        execute "git clone https://github.com/tmux-plugins/tpm '$TPM_DIR'"
        log_success "TPM installed."
    fi
    [ -f "$DOTFILES_DIR/config/tmux/.tmux.conf" ] && safe_link "$DOTFILES_DIR/config/tmux/.tmux.conf" "$HOME/.tmux.conf"
    log_success "Tmux ready."
}

setup_git() {
    log_info "Step 5: Configuring Git..."
    local GIT_CONF_SRC="$DOTFILES_DIR/config/git/.gitconfig"
    local GIT_CONF_DEST="$HOME/.gitconfig"

    if [ -f "$GIT_CONF_SRC" ]; then
        if ! grep -q "path = $GIT_CONF_SRC" "$GIT_CONF_DEST" 2>/dev/null; then
            execute "git config --global include.path '$GIT_CONF_SRC'"
            log_success "Git config linked."
        else
            log_success "Git config already linked."
        fi
    fi
}

setup_ssh() {
    log_info "Step 6: Configuring SSH (Mode: $WORK_MODE)..."
    execute "mkdir -p '$HOME/.ssh' && chmod 700 '$HOME/.ssh'"
    
    local SSH_FILENAME="linux.config"
    [[ "$WORK_MODE" == "macos" ]] && SSH_FILENAME="macos.config"
    local GIT_SSH_CONF="$DOTFILES_DIR/config/ssh/$SSH_FILENAME"
    local LOCAL_SSH_CONF="$HOME/.ssh/config"
    
    if [ -f "$GIT_SSH_CONF" ]; then
        execute "chmod 600 '$GIT_SSH_CONF'"
        
        # 1. Remove the other platform's include if it exists (avoids "vice versa" confusion)
        local OTHER_FILENAME="macos.config"
        [[ "$SSH_FILENAME" == "macos.config" ]] && OTHER_FILENAME="linux.config"
        local OTHER_GIT_SSH_CONF="$DOTFILES_DIR/config/ssh/$OTHER_FILENAME"
        
        if [ -f "$LOCAL_SSH_CONF" ] && grep -qF "Include $OTHER_GIT_SSH_CONF" "$LOCAL_SSH_CONF"; then
            log_info "Cleaning up old $OTHER_FILENAME include from $LOCAL_SSH_CONF..."
            if [ "$DRY_RUN" = true ]; then
                echo "   [DRY-RUN] Would remove old include $OTHER_GIT_SSH_CONF from $LOCAL_SSH_CONF"
            else
                local tmp_conf
                tmp_conf="$(mktemp "${LOCAL_SSH_CONF}.tmp.XXXXXX")"
                chmod 600 "$tmp_conf"
                grep -vF "Include $OTHER_GIT_SSH_CONF" "$LOCAL_SSH_CONF" > "$tmp_conf" || true
                mv -f "$tmp_conf" "$LOCAL_SSH_CONF"
            fi
        fi

        # 2. Add the correct include
        safe_prepend "Include $GIT_SSH_CONF" "$LOCAL_SSH_CONF"
        execute "chmod 600 '$LOCAL_SSH_CONF'"
    fi

    if [[ "$WORK_MODE" == "linux-server" ]]; then
        local GIT_AUTH_KEYS="$DOTFILES_DIR/config/ssh/authorized_keys"
        [[ -f "$DOTFILES_DIR/config/ssh/authorized_keys.local" ]] && GIT_AUTH_KEYS="$DOTFILES_DIR/config/ssh/authorized_keys.local"
        local LOCAL_AUTH_KEYS="$HOME/.ssh/authorized_keys"
        if [ -f "$GIT_AUTH_KEYS" ]; then
            while IFS= read -r key; do
                [[ -z "$key" || "$key" =~ ^# ]] && continue
                safe_append "$key" "$LOCAL_AUTH_KEYS"
            done < "$GIT_AUTH_KEYS"
            execute "chmod 600 '$LOCAL_AUTH_KEYS'"
            log_success "Authorized keys imported from $(basename "$GIT_AUTH_KEYS")."
        fi
    fi
}

setup_iterm2() {
    if [[ "$OSTYPE" != "darwin"* || "$WORK_MODE" != "macos" ]]; then return; fi
    log_info "Step 7: Configuring iTerm2..."

    local ITERM_DIR="$DOTFILES_DIR/config/iterm2"
    if [ -f "$ITERM_DIR/com.googlecode.iterm2.plist" ]; then
        log_info "Linking iTerm2 preferences..."
        execute "defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true"
        execute "defaults write com.googlecode.iterm2 PrefsCustomFolder -string '$ITERM_DIR'"
        execute "defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile -bool true"
    else
        log_warn "No iTerm2 plist found in $ITERM_DIR. Skipping sync."
    fi

    log_info "Applying iTerm2 optimizations..."
    execute "defaults write com.googlecode.iterm2 GPU -bool true"
    execute "defaults write com.googlecode.iterm2 CopySelection -bool true"
    execute "defaults write com.googlecode.iterm2 PromptOnQuit -bool false"
    execute "defaults write com.googlecode.iterm2 MaxPasteHistoryEntries -int 50"
    execute "defaults write com.googlecode.iterm2 AutohideTmuxClientSession -bool true"
    execute "defaults write com.googlecode.iterm2 OpenTmuxWindowsAs -int 0"
    execute "defaults write com.googlecode.iterm2 OpenTmuxDashboardIfMoreThanXWindows -int 999"
    
    log_success "iTerm2 complete."
}

setup_macos() {
    if [[ "$OSTYPE" != "darwin"* || "$WORK_MODE" != "macos" ]]; then return; fi
    log_info "Step 8: Applying macOS Defaults & Fonts..."

    local FONT_DEST="$HOME/Library/Fonts/MesloLGS NF Regular.ttf"
    if [ ! -f "$FONT_DEST" ]; then
        execute "mkdir -p '$HOME/Library/Fonts'"
        execute "curl -fLo '$FONT_DEST' 'https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf'" true
    fi
    
    execute "defaults write NSGlobalDomain KeyRepeat -int 1"
    execute "defaults write NSGlobalDomain InitialKeyRepeat -int 15"
    execute "defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true"
    execute "defaults write com.apple.finder AppleShowAllExtensions -bool true"
    execute "defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false"
    execute "defaults write com.apple.dock autohide -bool true"
    execute "defaults write com.apple.dock autohide-delay -float 0"
    execute "defaults write com.apple.dock tilesize -int 48"

    if [ "$DRY_RUN" = false ]; then
        killall Finder Dock > /dev/null 2>&1 || true
    fi
    log_success "macOS complete."
}

run_smoke_tests() {
    log_info "🧪 Running Post-Install Verification..."
    run_doctor
}

run_doctor() {
    log_info "🩺 Starting Dotfiles Diagnostic..."
    local errors=0

    # 1. Symlink Checks
    local links=(
        "config/zsh/.zshrc:$HOME/.zshrc"
        "config/zsh/aliases.zsh:$HOME/.aliases.zsh"
        "config/vim/.vimrc:$HOME/.vimrc"
        "config/tmux/.tmux.conf:$HOME/.tmux.conf"
    )

    for pair in "${links[@]}"; do
        local src="$DOTFILES_DIR/${pair%%:*}"
        local dest="${pair#*:}"
        # Resolve both to absolute physical paths before comparing
        if [[ -L "$dest" && "${dest:A}" == "${src:A}" ]]; then
            log_success "Link OK: $(basename "$dest")"
        else
            log_error "Link BROKEN: $(basename "$dest") -> expected $src"
            errors=$((errors + 1))
        fi
    done

    # 1.3 Git Config Check
    local git_conf="$HOME/.gitconfig"
    if grep -q "path = $DOTFILES_DIR/config/git/.gitconfig" "$git_conf" 2>/dev/null; then
        log_success "Git: Include directive present in $git_conf"
    else
        log_error "Git: Include directive MISSING in $git_conf"
        errors=$((errors + 1))
    fi

    # 1.5 SSH Inclusion Check
    local ssh_conf="$HOME/.ssh/config"
    local SSH_FILENAME="linux.config"
    [[ "$WORK_MODE" == "macos" ]] && SSH_FILENAME="macos.config"
    if [[ -f "$ssh_conf" ]] && grep -q "Include $DOTFILES_DIR/config/ssh/$SSH_FILENAME" "$ssh_conf"; then
        log_success "SSH: Include directive present in $ssh_conf"
    else
        log_error "SSH: Include directive MISSING in $ssh_conf"
        errors=$((errors + 1))
    fi

    # 2. SSH Agent Check
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ -S "$SSH_AUTH_SOCK" ]]; then
            log_success "SSH Agent: Active agent found ($SSH_AUTH_SOCK)"
        else
            log_warn "SSH Agent: No active agent found in environment."
        fi
    else
        if [[ -S "$SSH_AUTH_SOCK" ]]; then
            log_success "SSH Agent: Forwarded agent found."
        elif [[ "$GITHUB_ACTIONS" == "true" ]]; then
            log_success "SSH Agent: Skipping check in CI."
        else
            log_warn "SSH Agent: No active agent found (Ensure SSH agent forwarding is active)."
        fi
    fi

    # 3. iTerm2 Sync Check
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local pref_folder=$(defaults read com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null)
        if [[ "$pref_folder" == "$DOTFILES_DIR/config/iterm2" ]]; then
            log_success "iTerm2: Preferences correctly linked."
        else
            log_warn "iTerm2: Preferences pointing to $pref_folder (not $DOTFILES_DIR/iterm2)"
        fi
    fi

    # 4. Repo Health
    if [ -z "$(git -C "$DOTFILES_DIR" status --porcelain)" ]; then
        log_success "Repo: Workspace is clean."
    else
        log_warn "Repo: You have uncommitted changes in $DOTFILES_DIR"
    fi

    echo "\n--- Diagnostic Summary ---"
    if [[ $errors -eq 0 ]]; then
        log_success "All systems operational. Your environment is healthy!"
        return 0
    else
        log_error "Detected $errors issues. Run dot.sh to repair."
        return 1
    fi
}

# --- Main Execution ---

main() {
    if [ "$RUN_DOCTOR" = true ]; then
        run_doctor
        exit $?
    fi

    if [ "$UPDATE_MODE" = true ]; then
        log_info "🔄 Running self-update..."
        if [ -d "$DOTFILES_DIR/.git" ]; then
            execute "git -C '$DOTFILES_DIR' pull --rebase"
            log_success "Update complete. Restarting script..."
            local remaining_args=()
            for arg in "${ORIGINAL_ARGS[@]}"; do
                [[ "$arg" != "--update" ]] && remaining_args+=("$arg")
            done
            exec "$DOTFILES_DIR/dot.sh" "${remaining_args[@]}"
        else
            log_error "Cannot update: $DOTFILES_DIR is not a git repository."
            exit 1
        fi
    fi

    check_dependencies
    if [ "$REMOTE_MODE" = true ]; then 
        download_assets
    else
        if [ ! -d "$DOTFILES_DIR" ]; then
            log_error "Dotfiles directory ($DOTFILES_DIR) not found."
            log_error "Please clone the repository there or run the script with --remote."
            exit 1
        fi
    fi

    if [ -n "$ONLY_STEP" ]; then
        if declare -f "$ONLY_STEP" > /dev/null; then
            log_info "Running targeted step: $ONLY_STEP..."
            "$ONLY_STEP"
            exit 0
        else
            log_error "Function '$ONLY_STEP' does not exist."
            exit 1
        fi
    fi

    [[ "$SKIP_STEP" == "setup_zsh"    ]] && log_warn "Skipping setup_zsh"    || setup_zsh
    [[ "$SKIP_STEP" == "setup_vim"    ]] && log_warn "Skipping setup_vim"    || setup_vim
    [[ "$SKIP_STEP" == "setup_tmux"   ]] && log_warn "Skipping setup_tmux"   || setup_tmux
    [[ "$SKIP_STEP" == "setup_git"    ]] && log_warn "Skipping setup_git"    || setup_git
    [[ "$SKIP_STEP" == "setup_ssh"    ]] && log_warn "Skipping setup_ssh"    || setup_ssh
    [[ "$SKIP_STEP" == "setup_iterm2" ]] && log_warn "Skipping setup_iterm2" || setup_iterm2
    [[ "$SKIP_STEP" == "setup_macos"  ]] && log_warn "Skipping setup_macos"  || setup_macos

    if [ "$RUN_TESTS" = true ]; then
        run_smoke_tests
        exit $?
    else
        echo "\n✨ Setup complete! Run with --doctor or --test to verify integrity."
    fi
}

main "${ORIGINAL_ARGS[@]}"
