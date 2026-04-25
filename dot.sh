#!/usr/bin/env zsh

# ==============================================================================
# BOOTSTRAP SCRIPT (v2.3)
# ==============================================================================

set -e 

# --- Configuration ---
GITHUB_USER="janhrabcak"
REPO_NAME="dotfiles"
DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles.backup/$(date +%Y%m%d_%H%M%S)"
DRY_RUN=false
REMOTE_MODE=false
WORK_MODE="macos"
ONLY_STEP=""

# --- Logging Helpers ---
log_info()    { echo "\033[0;34m[INFO]\033[0m  $1"; }
log_warn()    { echo "\033[0;33m[WARN]\033[0m  $1"; }
log_error()   { echo "\033[0;31m[ERROR]\033[0m $1"; }
log_success() { echo "\033[0;32m[OK]\033[0m    $1"; }

# --- CLI Argument Parsing ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run|-d) DRY_RUN=true; log_warn "DRY RUN MODE ENABLED."; shift ;;
        --remote)    REMOTE_MODE=true; shift ;;
        --mode)      WORK_MODE="$2"; shift 2 ;;
        --only)      ONLY_STEP="$2"; shift 2 ;;
        --test)      RUN_TESTS=true; shift ;;
        *) echo "Unknown parameter: $1"; shift ;;
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
            return 1
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
    if [ ! -f "$file" ]; then execute "touch '$file'"; fi
    if grep -qsF "$line" "$file"; then
        log_success "Entry already exists in $(basename $file)"
    else
        execute "echo '$line' >> '$file'"
        log_success "Updated $(basename $file) (appended)"
    fi
}

safe_prepend() {
    local line="$1"
    local file="$2"
    if [ ! -f "$file" ]; then execute "touch '$file'"; fi
    if grep -qsF "$line" "$file"; then
        log_success "Entry already exists in $(basename $file)"
    else
        execute "echo '$line' | cat - '$file' > '$file.tmp' && mv '$file.tmp' '$file'"
        log_success "Updated $(basename $file) (prepended)"
    fi
}

safe_link() {
    local src="$1"
    local dest="$2"
    if [ -f "$src" ]; then
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            init_backup_dir
            log_warn "Existing file found at $dest. Moving to backup."
            execute "mv '$dest' '$BACKUP_DIR/$(basename $dest)'"
        elif [ -L "$dest" ] && [ "$(readlink "$dest")" != "$src" ]; then
            log_warn "Broken or incorrect symlink at $dest. Re-linking."
            execute "rm '$dest'"
        fi
        
        if [[ ! -L "$dest" ]]; then
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
    local deps=("git" "curl" "vim" "zsh" "gh")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [[ "$OSTYPE" == "darwin"* && ! -d "/Applications/iTerm.app" ]]; then
        missing+=("iTerm2 (App)")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing[*]}"
        exit 1
    fi
    log_success "Dependency check complete."
}

download_assets() {
    log_info "Step 1: Downloading dotfiles archive..."
    local TARBALL_URL="https://github.com/$GITHUB_USER/$REPO_NAME/archive/refs/heads/main.tar.gz"
    [ ! -d "$DOTFILES_DIR" ] && execute "mkdir -p '$DOTFILES_DIR'" true
    execute "curl -fsSL '$TARBALL_URL' | tar -xzp -C '$DOTFILES_DIR' --strip-components=1" true
    log_success "Assets synced to $DOTFILES_DIR"
}

setup_zsh() {
    log_info "Step 2: Configuring Zsh & Oh My Zsh..."
    
    # 1. Install Oh My Zsh
    if [[ "$GITHUB_ACTIONS" != "true" && ! -d "$HOME/.oh-my-zsh" ]]; then
        execute "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended --keep-zshrc"
        log_success "Oh My Zsh installed."
    fi

    # 2. Install Custom Plugins
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

    # 3. Change Default Shell
    if [[ "$SHELL" != *"zsh"* && "$GITHUB_ACTIONS" != "true" ]]; then
        if command -v zsh >/dev/null 2>&1; then
            local zsh_path=$(command -v zsh)
            log_info "Changing default shell to $zsh_path (may prompt for password)."
            execute "chsh -s '$zsh_path'"
        fi
    fi

    # 4. Link Configurations
    safe_link "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
    safe_link "$DOTFILES_DIR/zsh/aliases.zsh" "$HOME/.aliases.zsh"
    
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

    safe_link "$DOTFILES_DIR/vim/.vimrc" "$HOME/.vimrc"
    log_info "Installing Vim plugins..."
    execute "vim +PlugInstall +qall"
    log_success "Vim ready."
}

setup_tmux() {
    if [[ "$WORK_MODE" == "linux-server" ]]; then
        log_info "Step 4: Setting up Tmux..."
        local TPM_DIR="$HOME/.tmux/plugins/tpm"
        if [ ! -d "$TPM_DIR" ]; then
            execute "mkdir -p '$(dirname "$TPM_DIR")'"
            execute "git clone https://github.com/tmux-plugins/tpm '$TPM_DIR'"
            log_success "TPM installed."
        fi
        [ -f "$DOTFILES_DIR/tmux/.tmux.conf" ] && safe_link "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
        log_success "Tmux ready."
    fi
}

setup_git() {
    log_info "Step 5: Configuring Git..."
    local GIT_CONF_SRC="$DOTFILES_DIR/git/.gitconfig"
    local GIT_CONF_DEST="$HOME/.gitconfig"

    if [ -f "$GIT_CONF_SRC" ]; then
        if ! grep -q "path = $GIT_CONF_SRC" "$GIT_CONF_DEST" 2>/dev/null; then
            execute "git config --global include.path '$GIT_CONF_SRC'"
            log_success "Git config linked."
        else
            log_success "Git config already linked."
        fi
    fi

    if command -v gh >/dev/null 2>&1; then
        if ! gh auth status >/dev/null 2>&1; then
            log_warn "GitHub CLI is not authenticated. Run 'gh auth login' later."
        fi
    fi
}

setup_ssh() {
    log_info "Step 6: Configuring SSH (Mode: $WORK_MODE)..."
    execute "mkdir -p '$HOME/.ssh' && chmod 700 '$HOME/.ssh'"
    
    local GIT_SSH_CONF="$DOTFILES_DIR/ssh/config"
    local LOCAL_SSH_CONF="$HOME/.ssh/config"
    
    if [ -f "$GIT_SSH_CONF" ]; then
        execute "chmod 600 '$GIT_SSH_CONF'"
        safe_prepend "Include $GIT_SSH_CONF" "$LOCAL_SSH_CONF"
    fi

    if [[ "$WORK_MODE" == "linux-server" ]]; then
        local GIT_AUTH_KEYS="$DOTFILES_DIR/ssh/authorized_keys"
        local LOCAL_AUTH_KEYS="$HOME/.ssh/authorized_keys"
        if [ -f "$GIT_AUTH_KEYS" ]; then
            while IFS= read -r key; do
                [[ -z "$key" || "$key" =~ ^# ]] && continue
                safe_append "$key" "$LOCAL_AUTH_KEYS"
            done < "$GIT_AUTH_KEYS"
            execute "chmod 600 '$LOCAL_AUTH_KEYS'"
            log_success "Authorized keys imported."
        fi
    fi
}

setup_iterm2() {
    if [[ "$OSTYPE" != "darwin"* || "$WORK_MODE" != "macos" ]]; then return; fi
    log_info "Step 7: Configuring iTerm2..."

    local ITERM_DIR="$DOTFILES_DIR/iterm2"
    if [ -f "$ITERM_DIR/com.googlecode.iterm2.plist" ]; then
        log_info "Linking iTerm2 preferences..."
        execute "defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true"
        execute "defaults write com.googlecode.iterm2 PrefsCustomFolder -string '$ITERM_DIR'"
        execute "defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile -bool true"
    else
        log_warn "No iTerm2 plist found in $ITERM_DIR. Skipping sync."
    fi

    local ITERM_SHELL_INT="$HOME/.iterm2_shell_integration.zsh"
    if [ ! -f "$ITERM_SHELL_INT" ]; then
        execute "curl -L https://iterm2.com/shell_integration/zsh -o '$ITERM_SHELL_INT'"
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
    execute "defaults write com.apple.LaunchServices LSQuarantine -bool false"

    if [ "$DRY_RUN" = false ]; then
        killall Finder Dock Terminal > /dev/null 2>&1 || true
    fi
    log_success "macOS complete."
}

run_smoke_tests() {
    log_info "🧪 Running Smoke Tests..."
    local errors=0
    [[ -L "$HOME/.zshrc" ]] || ((errors++))
    grep -q "Include $DOTFILES_DIR/ssh/config" "$HOME/.ssh/config" || ((errors++))
    if [[ $errors -eq 0 ]]; then
        echo "\n⭐ VERIFICATION SUCCESSFUL."
    else
        log_error "VERIFICATION FAILED: $errors errors detected."
    fi
}

# --- Main Execution ---

main() {
    check_dependencies
    if [ "$REMOTE_MODE" = true ]; then download_assets; fi

    if [ -n "$ONLY_STEP" ]; then
        if declare -f "$ONLY_STEP" > /dev/null; then
            log_info "Running targeted step: $ONLY_STEP..."
            eval "$ONLY_STEP"
            exit 0
        else
            log_error "Function '$ONLY_STEP' does not exist."
            exit 1
        fi
    fi

    setup_zsh
    setup_vim
    setup_tmux
    setup_git
    setup_ssh
    setup_iterm2
    setup_macos

    if [ "$RUN_TESTS" = true ]; then
        run_smoke_tests
    else
        echo "\n✨ Setup complete! Run with --test to verify integrity."
    fi
}

main "$@"
