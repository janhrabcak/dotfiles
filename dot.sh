#!/usr/bin/env zsh

# ==============================================================================
# BOOTSTRAP SCRIPT (v2.1)
# ==============================================================================
# USAGE (One-Liner):
# /bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/janhrabcak/dotfiles/main/dot.sh)" -- --remote
# ==============================================================================

set -e # Exit on error

# --- Configuration ---
GITHUB_USER="janhrabcak"
REPO_NAME="dotfiles"
DOTFILES_DIR="$HOME/.dotfiles"
DRY_RUN=false
REMOTE_MODE=false
WORK_MODE="macos"

# --- Logging Helpers ---
log_info()  { echo "\033[0;34m[INFO]\033[0m  $1"; }
log_warn()  { echo "\033[0;33m[WARN]\033[0m  $1"; }
log_error() { echo "\033[0;31m[ERROR]\033[0m $1"; exit 1; }
log_success() { echo "\033[0;32m[OK]\033[0m    $1"; }

# --- CLI Argument Parsing ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run|-d) DRY_RUN=true; log_warn "DRY RUN MODE ENABLED."; shift ;;
        --remote)    REMOTE_MODE=true; shift ;;
        --mode)      WORK_MODE="$2"; shift 2 ;;
        --test)      RUN_TESTS=true; shift ;;
        *) echo "Unknown parameter: $1"; shift ;;
    esac
done

# --- Execution Wrapper ---
execute() {
    if [ "$DRY_RUN" = true ]; then
        echo "   [DRY-RUN] Would execute: $@"
    else
        eval "$@"
    fi
}

# --- Safety/Idempotency Helpers ---
safe_append() {
    local line="$1"
    local file="$2"
    if [ ! -f "$file" ]; then execute "touch '$file'"; fi
    if grep -qsF "$line" "$file"; then
        log_success "Entry already exists in $(basename $file)"
    else
        execute "echo '$line' >> '$file'"
        log_success "Updated $(basename $file)"
    fi
}

safe_link() {
    local src="$1"
    local dest="$2"
    if [ -f "$src" ]; then
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            log_warn "Existing file found at $dest. Backing up to ${dest}.bak"
            execute "mv '$dest' '${dest}.bak'"
        fi
        execute "ln -sfn '$src' '$dest'"
    fi
}

# --- Functions ---

check_dependencies() {
    log_info "Step 0: Checking dependencies..."
    local deps=("git" "curl" "vim" "zsh" "gh")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log_warn "Optional dependency missing: $dep."
        fi
    done
    log_success "Dependency check complete."
}

download_assets() {
    log_info "Step 1: Downloading dotfiles archive..."
    local TARBALL_URL="https://github.com/$GITHUB_USER/$REPO_NAME/archive/refs/heads/main.tar.gz"
    [ ! -d "$DOTFILES_DIR" ] && execute "mkdir -p '$DOTFILES_DIR'"
    execute "curl -fsSL '$TARBALL_URL' | tar -xzp -C '$DOTFILES_DIR' --strip-components=1"
    log_success "Assets synced to $DOTFILES_DIR"
}

install_omz() {
    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
        log_warn "[CI] Skipping Oh My Zsh install."
        return
    fi
    log_info "Step 2: Checking Oh My Zsh & Plugins..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        execute "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended --keep-zshrc"
        log_success "Oh My Zsh installed."
    else
        log_success "Oh My Zsh already present."
    fi

    # Install custom plugins
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

set_default_shell() {
    log_info "Setting default shell to Zsh..."
    if [[ "$SHELL" == *"zsh"* ]]; then
        log_success "Default shell is already Zsh."
        return
    fi

    if command -v zsh >/dev/null 2>&1; then
        local zsh_path=$(command -v zsh)
        
        if [[ "$GITHUB_ACTIONS" == "true" ]]; then
            log_warn "[CI] Skipping chsh."
            return
        fi

        log_info "Changing default shell to $zsh_path (may prompt for password)."
        execute "chsh -s '$zsh_path'"
        log_success "Default shell changed."
    else
        log_warn "Zsh is not installed. Cannot set as default."
    fi
}

install_vim_plug() {
    log_info "Step 3: Setting up Vim-Plug..."
    local PLUG_URL="https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
    local PLUG_DEST="$HOME/.vim/autoload/plug.vim"
    
    if [ ! -f "$PLUG_DEST" ]; then
        execute "curl -fLo '$PLUG_DEST' --create-dirs '$PLUG_URL'"
        log_success "Vim-Plug installed."
    fi

    log_info "Installing Vim plugins..."
    execute "vim +PlugInstall +qall"
}

install_tmux_tpm() {
    if [[ "$WORK_MODE" == "linux-server" ]]; then
        log_info "Setting up Tmux Plugin Manager (TPM)..."
        local TPM_DEST="$HOME/.tmux/plugins/tpm"
        if [ ! -d "$TPM_DEST" ]; then
            execute "git clone https://github.com/tmux-plugins/tpm '$TPM_DEST'"
            log_success "TPM installed."
        else
            log_success "TPM already installed."
        fi
    fi
}

setup_git() {
    log_info "Step 5: Configuring Git..."
    local GIT_CONF_SRC="$DOTFILES_DIR/git/.gitconfig"
    local GIT_CONF_DEST="$HOME/.gitconfig"

    if [ -f "$GIT_CONF_SRC" ]; then
        # Use includeIf or simple include to keep local settings
        if ! grep -q "path = $GIT_CONF_SRC" "$GIT_CONF_DEST" 2>/dev/null; then
            execute "git config --global include.path '$GIT_CONF_SRC'"
            log_success "Git config linked."
        else
            log_success "Git config already linked."
        fi
    fi

    # GitHub CLI initialization
    if command -v gh >/dev/null 2>&1; then
        log_info "Checking GitHub CLI status..."
        if ! gh auth status >/dev/null 2>&1; then
            log_warn "GitHub CLI is not authenticated. Run 'gh auth login' to initialize."
        else
            log_success "GitHub CLI is authenticated."
        fi
    fi
}

link_configs() {
    log_info "Step 4: Linking Configurations..."
    safe_link "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
    safe_link "$DOTFILES_DIR/zsh/aliases.zsh" "$HOME/.aliases.zsh"
    safe_link "$DOTFILES_DIR/vim/.vimrc" "$HOME/.vimrc"
    
    if [[ "$WORK_MODE" == "linux-server" ]]; then
        [ -f "$DOTFILES_DIR/tmux/.tmux.conf" ] && safe_link "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
    fi
    
    log_success "Symlinks created."
}

setup_ssh() {
    log_info "Step 5: Configuring SSH (Mode: $WORK_MODE)..."
    execute "mkdir -p '$HOME/.ssh' && chmod 700 '$HOME/.ssh'"
    
    local GIT_SSH_CONF="$DOTFILES_DIR/ssh/config"
    local LOCAL_SSH_CONF="$HOME/.ssh/config"
    
    if [ -f "$GIT_SSH_CONF" ]; then
        execute "chmod 600 '$GIT_SSH_CONF'"
        safe_append "Include $GIT_SSH_CONF" "$LOCAL_SSH_CONF"
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
    log_info "Step 6: Configuring iTerm2..."

    # iTerm2 - Load preferences from our dotfiles directory
    local ITERM_DIR="$DOTFILES_DIR/iterm2"
    if [ -d "$ITERM_DIR" ]; then
        log_info "Linking iTerm2 preferences to $ITERM_DIR..."
        execute "defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true"
        execute "defaults write com.googlecode.iterm2 PrefsCustomFolder -string '$ITERM_DIR'"
        execute "defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile -bool true"
    fi

    # iTerm2 - Shell Integration
    local ITERM_SHELL_INT="$HOME/.iterm2_shell_integration.zsh"
    if [ ! -f "$ITERM_SHELL_INT" ]; then
        log_info "Downloading iTerm2 Shell Integration..."
        execute "curl -L https://iterm2.com/shell_integration/zsh -o '$ITERM_SHELL_INT'"
    fi

    # iTerm2 - Performance & UX Boosts
    log_info "Applying iTerm2 performance tweaks..."
    execute "defaults write com.googlecode.iterm2 GPU -bool true"
    execute "defaults write com.googlecode.iterm2 CopySelection -bool true"
    execute "defaults write com.googlecode.iterm2 PromptOnQuit -bool false"
    execute "defaults write com.googlecode.iterm2 MaxPasteHistoryEntries -int 50"
    
    # iTerm2 - tmux Control Mode Integration
    log_info "Optimizing iTerm2 + tmux Control Mode..."
    execute "defaults write com.googlecode.iterm2 AutohideTmuxClientSession -bool true"
    execute "defaults write com.googlecode.iterm2 OpenTmuxWindowsAs -int 0" # 0 = Native Tabs
    
    log_success "iTerm2 setup complete."
}

setup_macos() {
    if [[ "$OSTYPE" != "darwin"* || "$WORK_MODE" != "macos" ]]; then return; fi
    log_info "Step 6: Applying macOS System Defaults & Fonts..."

    # Fonts
    local FONT_DIR="$HOME/Library/Fonts"
    local FONT_NAME="MesloLGS NF Regular.ttf"
    local FONT_DEST="$FONT_DIR/$FONT_NAME"
    local FONT_URL="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"

    if [ ! -f "$FONT_DEST" ]; then
        log_info "Downloading and installing Powerline Nerd Font..."
        execute "mkdir -p '$FONT_DIR'"
        execute "curl -fLo '$FONT_DEST' '$FONT_URL'"
        log_success "Nerd Font installed."
    else
        log_success "Nerd Font already installed."
    fi
    
    # Keyboard & Trackpad
    execute "defaults write NSGlobalDomain KeyRepeat -int 1"
    execute "defaults write NSGlobalDomain InitialKeyRepeat -int 15"
    execute "defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true"
    
    # Finder
    execute "defaults write com.apple.finder AppleShowAllExtensions -bool true"
    execute "defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false"
    
    # Dock
    execute "defaults write com.apple.dock autohide -bool true"
    execute "defaults write com.apple.dock autohide-delay -float 0"
    execute "defaults write com.apple.dock tilesize -int 48"

    # Terminal Profile
    local TERMINAL_PROFILE="$DOTFILES_DIR/macos-terminal/zsh.terminal"
    if [ -f "$TERMINAL_PROFILE" ]; then
        log_info "Importing Terminal profile 'Zsh'..."
        # 'open' will import the .terminal file into Terminal.app
        execute "open '$TERMINAL_PROFILE'"
        # Set it as default and startup profile
        execute "defaults write com.apple.Terminal 'Default Window Settings' -string 'Zsh'"
        execute "defaults write com.apple.Terminal 'Startup Window Settings' -string 'Zsh'"
        log_success "Terminal profile set as default."
    fi

    # Security
    execute "defaults write com.apple.LaunchServices LSQuarantine -bool false"

    if [ "$DRY_RUN" = false ]; then
        log_info "Restarting Finder and Dock..."
        killall Finder Dock > /dev/null 2>&1 || true
    fi
    log_success "macOS defaults applied."
}

# --- Verification Suite ---

run_smoke_tests() {
    log_info "🧪 Running Smoke Tests..."
    local errors=0

    # Test 1: Symlinks
    if [[ -L "$HOME/.zshrc" && "$(readlink "$HOME/.zshrc")" == "$DOTFILES_DIR/zsh/.zshrc" ]]; then
        log_success "[PASS] .zshrc symlink is correct."
    else
        log_warn "[FAIL] .zshrc symlink is broken or missing."
        ((errors++))
    fi

    # Test 2: SSH Config Inclusion
    if grep -q "Include $DOTFILES_DIR/ssh/config" "$HOME/.ssh/config"; then
        log_success "[PASS] SSH config inclusion found."
    else
        log_warn "[FAIL] SSH config does not include dotfiles source."
        ((errors++))
    fi

    # Test 3: Permissions
    local ssh_perm
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ssh_perm=$(stat -f "%Lp" "$HOME/.ssh")
    else
        ssh_perm=$(stat -c "%a" "$HOME/.ssh")
    fi

    if [[ "$ssh_perm" == "700" ]]; then
        log_success "[PASS] ~/.ssh permissions are secure (700)."
    else
        log_warn "[FAIL] ~/.ssh permissions are $ssh_perm (expected 700)."
        ((errors++))
    fi

    if [[ $errors -eq 0 ]]; then
        echo "\n⭐ VERIFICATION SUCCESSFUL: System state matches configuration."
    else
        log_error "VERIFICATION FAILED: $errors errors detected."
    fi
}

# --- Main Execution ---

main() {
    check_dependencies
    if [ "$REMOTE_MODE" = true ]; then download_assets; fi
    install_omz
    set_default_shell
    link_configs
    install_vim_plug
    install_tmux_tpm
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

