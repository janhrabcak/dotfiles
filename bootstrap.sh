#!/usr/bin/zsh

# ==============================================================================
# BOOTSTRAP SCRIPT
# ==============================================================================
# USAGE (One-Liner):
# /bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/your-username/dotfiles/main/bootstrap.sh)" -- --remote
#
# FLAGS:
#   --remote    Downloads the full dotfiles archive from GitHub
#   --dry-run   Show what would happen without making changes
#   --mode      'workstation' (default) or 'server'
#   --test      Runs post-setup verification suite
# ==============================================================================

# --- Configuration ---
GITHUB_USER="janhrabcak"
REPO_NAME="dotfiles"
DOTFILES_DIR="$HOME/.dotfiles"
DRY_RUN=false
REMOTE_MODE=false
WORK_MODE="workstation"

# --- CLI Argument Parsing ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run|-d) DRY_RUN=true; echo "🔍 DRY RUN MODE ENABLED."; shift ;;
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
        echo "   ✅ Entry already exists in $file"
    else
        execute "echo '$line' >> '$file'"
        echo "   ✅ Successfully updated $file"
    fi
}

# --- Functions ---

download_assets() {
    echo "\n📥 Step 1: Downloading dotfiles archive..."
    local TARBALL_URL="https://github.com/$GITHUB_USER/$REPO_NAME/archive/refs/heads/main.tar.gz"
    [ ! -d "$DOTFILES_DIR" ] && execute "mkdir -p '$DOTFILES_DIR'"
    execute "curl -fsSL '$TARBALL_URL' | tar -xzp -C '$DOTFILES_DIR' --strip-components=1"
    echo "   ✅ Assets synced to $DOTFILES_DIR"
}

install_omz() {
    # Inside your install_omz() function
    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
        echo "   [CI] Skipping Oh My Zsh install to save time."
        return
    fi
    echo "\n🐚 Step 2: Checking Oh My Zsh..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        execute "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended --keep-zshrc"
    else
        echo "   ✅ Oh My Zsh already present."
    fi
}

link_configs() {
    echo "\n🔗 Step 3: Linking Configurations..."
    [ -f "$DOTFILES_DIR/zsh/.zshrc" ] && execute "ln -sfn '$DOTFILES_DIR/zsh/.zshrc' '$HOME/.zshrc'"
    [ -f "$DOTFILES_DIR/vim/.vimrc" ] && execute "ln -sfn '$DOTFILES_DIR/vim/.vimrc' '$HOME/.vimrc'"
}

setup_ssh() {
    echo "\n🔑 Step 4: Configuring SSH (Mode: $WORK_MODE)..."
    execute "mkdir -p '$HOME/.ssh' && chmod 700 '$HOME/.ssh'"
    
    local GIT_SSH_CONF="$DOTFILES_DIR/ssh/config"
    local LOCAL_SSH_CONF="$HOME/.ssh/config"
    
    if [ -f "$GIT_SSH_CONF" ]; then
        execute "chmod 600 '$GIT_SSH_CONF'"
        safe_append "Include $GIT_SSH_CONF" "$LOCAL_SSH_CONF"
    fi

    if [[ "$WORK_MODE" == "server" ]]; then
        local GIT_AUTH_KEYS="$DOTFILES_DIR/ssh/authorized_keys"
        local LOCAL_AUTH_KEYS="$HOME/.ssh/authorized_keys"
        if [ -f "$GIT_AUTH_KEYS" ]; then
            while IFS= read -r key; do
                [[ -z "$key" || "$key" =~ ^# ]] && continue
                safe_append "$key" "$LOCAL_AUTH_KEYS"
            done < "$GIT_AUTH_KEYS"
            execute "chmod 600 '$LOCAL_AUTH_KEYS'"
        fi
    fi
}

setup_macos() {
    if [[ "$OSTYPE" != "darwin"* || "$WORK_MODE" == "server" ]]; then return; fi
    echo "\n💻 Step 5: Applying macOS System Defaults..."
    execute "defaults write NSGlobalDomain KeyRepeat -int 1"
    execute "defaults write com.apple.finder AppleShowAllExtensions -bool true"
    [ "$DRY_RUN" = false ] && killall Finder Dock > /dev/null 2>&1
}

# --- Verification Suite (The "Tests") ---

run_smoke_tests() {
    echo "\n🧪 Running Smoke Tests..."
    local errors=0

    # Test 1: Symlinks
    if [[ -L "$HOME/.zshrc" && "$(readlink "$HOME/.zshrc")" == "$DOTFILES_DIR/zsh/.zshrc" ]]; then
        echo "   [PASS] .zshrc symlink is correct."
    else
        echo "   [FAIL] .zshrc symlink is broken or missing."
        ((errors++))
    fi

    # Test 2: SSH Config Inclusion
    if grep -q "Include $DOTFILES_DIR/ssh/config" "$HOME/.ssh/config"; then
        echo "   [PASS] SSH config inclusion found."
    else
        echo "   [FAIL] SSH config does not include dotfiles source."
        ((errors++))
    fi

    # Test 3: Permissions
    local ssh_perm=$(stat -f "%Lp" "$HOME/.ssh")
    if [[ "$ssh_perm" == "700" ]]; then
        echo "   [PASS] ~/.ssh permissions are secure (700)."
    else
        echo "   [FAIL] ~/.ssh permissions are $ssh_perm (expected 700)."
        ((errors++))
    fi

    if [[ $errors -eq 0 ]]; then
        echo "\n⭐ VERIFICATION SUCCESSFUL: System state matches configuration."
    else
        echo "\n❌ VERIFICATION FAILED: $errors errors detected."
        exit 1
    fi
}

# --- Main Execution ---

main() {
    if [ "$REMOTE_MODE" = true ]; then download_assets; fi
    install_omz
    link_configs
    setup_ssh
    setup_macos

    if [ "$RUN_TESTS" = true ]; then
        run_smoke_tests
    else
        echo "\n✨ Setup complete! Run with --test to verify integrity."
    fi
}

main "$@"
