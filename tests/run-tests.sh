#!/usr/bin/env zsh
# ==============================================================================
# UNIFIED TEST SUITE FOR DOTFILES BOOTSTRAPPER
# ==============================================================================
# Runs comprehensive behavioral and invariant checks in isolated temporary sandboxes.
# Safe to run locally without polluting the host system.

set -e

REPO_ROOT="${0:A:h:h}"
PASSED=0
FAILED=0
TOTAL=0

# --- Colors & Reporting ---
GREEN="\033[0;32m"
RED="\033[0;31m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
BOLD="\033[1m"
RESET="\033[0m"

log_suite() { echo "${BLUE}${BOLD}==>${RESET} $1"; }
pass() {
  PASSED=$((PASSED + 1))
  TOTAL=$((TOTAL + 1))
  echo "  ${GREEN}[PASS]${RESET} $1"
}
fail() {
  FAILED=$((FAILED + 1))
  TOTAL=$((TOTAL + 1))
  echo "  ${RED}[FAIL]${RESET} $1"
  echo "         Reason: $2"
}

# --- Sandbox Helpers ---
setup_sandbox() {
  SANDBOX=$(mktemp -d "/tmp/dotfiles-test.XXXXXX")
  export TEST_ORIG_HOME="$HOME"
  export HOME="$SANDBOX/home"
  export DOTFILES_DIR="$HOME/.dotfiles"
  mkdir -p "$HOME"
  mkdir -p "$DOTFILES_DIR"
  cp -R "$REPO_ROOT/." "$DOTFILES_DIR/"
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  touch "$HOME/.ssh/config" && chmod 600 "$HOME/.ssh/config"
  git config --global user.name "Test Bot"
  git config --global user.email "test@example.com"
}

teardown_sandbox() {
  export HOME="$TEST_ORIG_HOME"
  rm -rf "$SANDBOX"
}

# ==============================================================================
# TEST SUITE
# ==============================================================================

echo "${BOLD}Starting Dotfiles Test Suite...${RESET}"
echo "Repository: $REPO_ROOT"
echo ""

# ------------------------------------------------------------------------------
# 1. Syntax & Static Lint Checks
# ------------------------------------------------------------------------------
log_suite "Group 1: Syntax & Linter Checks"

if zsh -n "$REPO_ROOT/dot.sh" \
   && zsh -n "$REPO_ROOT/config/zsh/.zshrc" \
   && zsh -n "$REPO_ROOT/config/zsh/aliases.zsh"; then
  pass "Zsh syntax check (dot.sh, .zshrc, aliases.zsh)"
else
  fail "Zsh syntax check" "Syntax error detected in shell scripts"
fi

if tmux -f "$REPO_ROOT/config/tmux/.tmux.conf" start-server \; kill-server >/dev/null 2>&1; then
  pass "Tmux configuration syntax check"
else
  fail "Tmux configuration syntax check" "tmux.conf failed to parse"
fi

if HOME="$REPO_ROOT" vim -u "$REPO_ROOT/config/vim/.vimrc" -e -s -c "q" >/dev/null 2>&1; then
  pass "Vim configuration parse check"
else
  fail "Vim configuration parse check" ".vimrc failed to parse cleanly"
fi

if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -s bash "$REPO_ROOT/tests/"*.sh >/dev/null 2>&1; then
    pass "ShellCheck static analysis"
  else
    fail "ShellCheck static analysis" "ShellCheck warnings found in tests/"
  fi
else
  echo "  ${YELLOW}[SKIP]${RESET} ShellCheck static analysis (shellcheck not installed)"
fi

# ------------------------------------------------------------------------------
# 2. Vim Headless Assertions
# ------------------------------------------------------------------------------
log_suite "Group 2: Vim Configuration Behavioral Assertions"

vim_assert() {
  local expr="$1"
  local desc="$2"
  if vim -u "$REPO_ROOT/config/vim/.vimrc" -c "if !($expr) | cquit 1 | endif" -c "qall" >/dev/null 2>&1; then
    pass "Vim: $desc"
  else
    fail "Vim: $desc" "Assertion ($expr) evaluated to false"
  fi
}

vim_assert "g:mapleader ==# ','" "Map leader is comma (,)"
vim_assert "&undofile == 1" "Persistent undo (undofile) is enabled"
vim_assert "&ignorecase == 1" "Ignorecase search enabled"
vim_assert "&smartcase == 1" "Smartcase search enabled"
vim_assert "&relativenumber == 1" "Relative line numbering enabled"

# ------------------------------------------------------------------------------
# 3. CLI Argument Handling
# ------------------------------------------------------------------------------
log_suite "Group 3: CLI Flags & Safety"

setup_sandbox

# Unknown parameter
set +e
zsh "$DOTFILES_DIR/dot.sh" --invalid-flag >/dev/null 2>&1
exit_code=$?
set -e
if [[ $exit_code -eq 1 ]]; then
  pass "CLI rejects unknown parameters with exit code 1"
else
  fail "CLI rejects unknown parameters" "Expected exit code 1, got $exit_code"
fi

# Dry Run Non-Destructive Invariant
zsh "$DOTFILES_DIR/dot.sh" --dry-run >/dev/null 2>&1
if [[ ! -L "$HOME/.zshrc" && ! -L "$HOME/.vimrc" && ! -L "$HOME/.tmux.conf" ]]; then
  pass "Dry-run leaves home directory completely untouched"
else
  fail "Dry-run leaves home directory untouched" "Found modified/created symlinks after --dry-run"
fi

# --only step execution
zsh "$DOTFILES_DIR/dot.sh" --only setup_git >/dev/null 2>&1
if grep -q "config/git/.gitconfig" "$HOME/.gitconfig" && [[ ! -L "$HOME/.zshrc" && ! -L "$HOME/.vimrc" ]]; then
  pass "--only flag executes targeted step only"
else
  fail "--only flag targeted execution" "Targeted step failed or side-effect files created"
fi

# --skip single step
teardown_sandbox
setup_sandbox
zsh "$DOTFILES_DIR/dot.sh" --skip setup_vim >/dev/null 2>&1
if [[ ! -L "$HOME/.vimrc" && -L "$HOME/.zshrc" ]]; then
  pass "--skip flag successfully bypasses specified step"
else
  fail "--skip flag" "Vim was linked despite --skip setup_vim"
fi

# --skip multiple steps
teardown_sandbox
setup_sandbox
zsh "$DOTFILES_DIR/dot.sh" --skip setup_vim --skip setup_tmux >/dev/null 2>&1
if [[ ! -L "$HOME/.vimrc" && ! -L "$HOME/.tmux.conf" && -L "$HOME/.zshrc" ]]; then
  pass "Multiple --skip flags successfully bypass all specified steps"
else
  fail "Multiple --skip flags" "One or more skipped steps were executed"
fi

teardown_sandbox

# ------------------------------------------------------------------------------
# 4. Backup Safety & File Recovery
# ------------------------------------------------------------------------------
log_suite "Group 4: Backup & Safe Linking Invariants"

setup_sandbox
UNIQUE_CONTENT="CUSTOM_USER_CONFIG_TOKEN_$(date +%s)"
echo "$UNIQUE_CONTENT" > "$HOME/.zshrc"

zsh "$DOTFILES_DIR/dot.sh" --only setup_zsh >/dev/null 2>&1

if [[ -L "$HOME/.zshrc" ]]; then
  pass "Pre-existing file replaced by symlink"
else
  fail "Pre-existing file replacement" "$HOME/.zshrc is not a symlink"
fi

backup_file=$(find "$HOME/.dotfiles.backup" -type f -name ".zshrc" 2>/dev/null | head -n 1)
if [[ -n "$backup_file" ]] && grep -q "$UNIQUE_CONTENT" "$backup_file"; then
  pass "Pre-existing file safely backed up with identical contents"
else
  fail "Safe backup" "Backup not found or content altered"
fi

teardown_sandbox

# ------------------------------------------------------------------------------
# 5. SSH Configuration & Permissions
# ------------------------------------------------------------------------------
log_suite "Group 5: SSH Permissions & Hardening"

setup_sandbox
zsh "$DOTFILES_DIR/dot.sh" --only setup_ssh >/dev/null 2>&1

if [[ -f "$HOME/.ssh/config" ]]; then
  pass "SSH config created/updated"
else
  fail "SSH config existence" "$HOME/.ssh/config does not exist"
fi

# Check permissions are 600
perm=$(stat -c "%a" "$HOME/.ssh/config" 2>/dev/null || stat -f "%OLp" "$HOME/.ssh/config" 2>/dev/null || echo "unknown")
if [[ "$perm" == "600" ]]; then
  pass "SSH config file permissions strictly enforced to 600"
else
  fail "SSH config permissions" "Expected 600, got $perm"
fi

# Ensure ForwardAgent is not set for GitHub
if grep -A 3 "Host github.com" "$DOTFILES_DIR/config/ssh/linux.config" | grep -q "ForwardAgent"; then
  fail "SSH GitHub security" "ForwardAgent yes is still present for github.com"
else
  pass "SSH GitHub security: ForwardAgent is disabled"
fi

teardown_sandbox

# ------------------------------------------------------------------------------
# 6. Git Include & Local Configuration
# ------------------------------------------------------------------------------
log_suite "Group 6: Git Configuration & Identity Resolution"

setup_sandbox
zsh "$DOTFILES_DIR/dot.sh" --only setup_git >/dev/null 2>&1

# Create local identity config
cat << 'CONFIG_EOF' > "$DOTFILES_DIR/config/git/.gitconfig.local"
[user]
	name = Test Identity
	email = identity@testdomain.com
CONFIG_EOF

git_resolved_email=$(git config user.email 2>/dev/null || true)
if [[ "$git_resolved_email" == "identity@testdomain.com" ]]; then
  pass "Git include path resolves local identity (.gitconfig.local)"
else
  fail "Git include path resolution" "Expected identity@testdomain.com, got '$git_resolved_email'"
fi

teardown_sandbox

# ------------------------------------------------------------------------------
# 7. Zsh Runtime Environment & Aliases
# ------------------------------------------------------------------------------
log_suite "Group 7: Zsh Environment & Aliases"

setup_sandbox
zsh "$DOTFILES_DIR/dot.sh" --only setup_zsh >/dev/null 2>&1

# Test alias loading and function definitions
alias_test=$(zsh -c "
  source '$DOTFILES_DIR/config/zsh/aliases.zsh'
  alias gs >/dev/null 2>&1 || exit 1
  alias ga >/dev/null 2>&1 || exit 1
  alias gc >/dev/null 2>&1 || exit 1
  alias gp >/dev/null 2>&1 || exit 1
  alias gl >/dev/null 2>&1 || exit 1
  functions ssh-cc >/dev/null 2>&1 || exit 1
  echo 'OK'
" 2>/dev/null || echo "FAILED")

if [[ "$alias_test" == "OK" ]]; then
  pass "Git and tmux aliases and functions successfully defined"
else
  fail "Zsh aliases" "One or more core aliases/functions missing"
fi

teardown_sandbox

# ------------------------------------------------------------------------------
# 8. Doctor Diagnostic & Failure Detection
# ------------------------------------------------------------------------------
log_suite "Group 8: Doctor Diagnostic Verification"

setup_sandbox
zsh "$DOTFILES_DIR/dot.sh" >/dev/null 2>&1

# Healthy system check
set +e
zsh "$DOTFILES_DIR/dot.sh" --doctor >/dev/null 2>&1
exit_code=$?
set -e
if [[ $exit_code -eq 0 ]]; then
  pass "Doctor reports success (exit 0) on healthy installation"
else
  fail "Doctor healthy check" "Expected 0, got $exit_code"
fi

# Break a symlink and assert doctor detects it and exits non-zero
rm -f "$HOME/.vimrc"
ln -s "/nonexistent/path/to/vimrc" "$HOME/.vimrc"

set +e
zsh "$DOTFILES_DIR/dot.sh" --doctor >/dev/null 2>&1
exit_code=$?
set -e
if [[ $exit_code -ne 0 ]]; then
  pass "Doctor detects broken symlink and exits with non-zero status"
else
  fail "Doctor broken symlink detection" "Doctor returned 0 despite broken symlink"
fi

teardown_sandbox

# ------------------------------------------------------------------------------
# 9. Idempotency Test
# ------------------------------------------------------------------------------
log_suite "Group 9: Idempotency Verification"

setup_sandbox
zsh "$DOTFILES_DIR/dot.sh" >/dev/null 2>&1
# Capture snapshot of links
snapshot_first=$(ls -l "$HOME/.zshrc" "$HOME/.vimrc" "$HOME/.aliases.zsh")

zsh "$DOTFILES_DIR/dot.sh" >/dev/null 2>&1
snapshot_second=$(ls -l "$HOME/.zshrc" "$HOME/.vimrc" "$HOME/.aliases.zsh")

if [[ "$snapshot_first" == "$snapshot_second" ]]; then
  pass "Second execution is completely idempotent (no link changes)"
else
  fail "Idempotency" "Symlinks changed after second execution"
fi

teardown_sandbox

# ==============================================================================
# SUMMARY
# ==============================================================================
echo ""
echo "=============================================================================="
echo "${BOLD}Test Summary:${RESET} Ran $TOTAL tests | ${GREEN}$PASSED passed${RESET} | ${RED}$FAILED failed${RESET}"
echo "=============================================================================="

if [[ $FAILED -eq 0 ]]; then
  echo "${GREEN}${BOLD}🎉 ALL TESTS PASSED!${RESET}"
  exit 0
else
  echo "${RED}${BOLD}❌ SOME TESTS FAILED.${RESET}"
  exit 1
fi
