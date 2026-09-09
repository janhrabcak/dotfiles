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
   && zsh -n "$REPO_ROOT/config/zsh/aliases.zsh" \
   && zsh -n "$REPO_ROOT/.githooks/pre-commit" \
   && zsh -n "$REPO_ROOT/tests/run-tests.sh"; then
  pass "Zsh syntax check (dot.sh, .zshrc, aliases, pre-commit, run-tests)"
else
  fail "Zsh syntax check" "Syntax error detected in shell scripts"
fi

if [[ -x "$REPO_ROOT/.githooks/pre-commit" ]]; then
  pass "Pre-commit hook is present and executable"
else
  fail "Pre-commit hook" ".githooks/pre-commit is missing or not executable"
fi

if [[ -f "$REPO_ROOT/.github/dependabot.yml" ]]; then
  pass "Dependabot configuration present"
else
  fail "Dependabot configuration" ".github/dependabot.yml is missing"
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

if [[ -f "$REPO_ROOT/config/brew/Brewfile" ]]; then
  pass "Homebrew Brewfile present"
else
  fail "Homebrew Brewfile" "config/brew/Brewfile is missing"
fi

if grep -q "corp.google.com" "$REPO_ROOT/config/zsh/aliases.zsh"; then
  fail "Secret sanitization" "Corporate hostnames detected in aliases.zsh"
else
  pass "Secret sanitization: no internal corporate hostnames in public config"
fi

if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -s bash "$REPO_ROOT/tests/dot-local-ci-test.sh" "$REPO_ROOT/tests/test-vim.sh" >/dev/null 2>&1; then
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

# --clean dry-run safety
teardown_sandbox
setup_sandbox
ln -s "$DOTFILES_DIR/nonexistent_test_dead" "$HOME/.dead_dotfile"
ln -s "/nonexistent_external_target" "$HOME/.dead_external"
zsh "$DOTFILES_DIR/dot.sh" --clean --dry-run >/dev/null 2>&1
if [[ -L "$HOME/.dead_dotfile" && -L "$HOME/.dead_external" ]]; then
  pass "--clean --dry-run leaves all symlinks untouched"
else
  fail "--clean --dry-run" "Symlink was unexpectedly removed during dry run"
fi

# --clean removes dead dotfiles symlinks but preserves external dead symlinks
zsh "$DOTFILES_DIR/dot.sh" --clean >/dev/null 2>&1
if [[ ! -L "$HOME/.dead_dotfile" && -L "$HOME/.dead_external" ]]; then
  pass "--clean prunes dead dotfiles symlinks while preserving external symlinks"
else
  fail "--clean pruning" "Dead dotfiles symlink was not pruned or external symlink was removed"
fi

# --install-deps enforcement: missing dependency refuses auto-install without flag
set +e
check_output=$(PATH="/usr/bin:/bin" zsh -c "
  command() { if [[ \"\$2\" == 'zsh' ]]; then return 1; fi; builtin command \"\$@\"; }
  source '$DOTFILES_DIR/dot.sh' --dry-run
  check_dependencies
" 2>&1)
check_exit=$?
set -e
if [[ $check_exit -ne 0 ]] && echo "$check_output" | grep -q "Run dot.sh with --install-deps"; then
  pass "Dependency check refuses to install missing tools without --install-deps"
else
  fail "Dependency check --install-deps enforcement" "Script did not require --install-deps for missing dependencies"
fi

# Gated Vim binary hooks: check that without DOTFILES_INSTALL_DEPS, fzf#install and GoUpdateBinaries are omitted
vim_hooks=$(DOTFILES_INSTALL_DEPS=false vim -u "$DOTFILES_DIR/config/vim/.vimrc" -c "redir => g:plugs_out | silent echo g:plugs | redir END | echo g:plugs_out" -c "qall" 2>/dev/null || true)
if echo "$vim_hooks" | grep -q "fzf" && ! echo "$vim_hooks" | grep -q "fzf#install"; then
  pass "Vim: Binary post-install hooks are disabled when DOTFILES_INSTALL_DEPS is false"
else
  fail "Vim binary hooks guard" "Binary hooks were registered despite DOTFILES_INSTALL_DEPS=false"
fi

# When DOTFILES_INSTALL_DEPS=true, fzf#install hook is registered
vim_hooks_with_deps=$(DOTFILES_INSTALL_DEPS=true vim -u "$DOTFILES_DIR/config/vim/.vimrc" -c "redir => g:plugs_out | silent echo g:plugs | redir END | echo g:plugs_out" -c "qall" 2>/dev/null || true)
if echo "$vim_hooks_with_deps" | grep -q "fzf#install"; then
  pass "Vim: Binary post-install hooks are enabled when DOTFILES_INSTALL_DEPS=true"
else
  fail "Vim binary hooks guard" "Binary hook fzf#install was not registered when DOTFILES_INSTALL_DEPS=true"
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

# Backup rotation: keeps only 5 newest backups
teardown_sandbox
setup_sandbox
mkdir -p "$HOME/.dotfiles.backup"
for i in {1..8}; do
  mkdir -p "$HOME/.dotfiles.backup/2026010${i}_000000"
  touch "$HOME/.dotfiles.backup/2026010${i}_000000/test.txt"
done
zsh "$DOTFILES_DIR/dot.sh" --clean >/dev/null 2>&1
backup_count=$(find "$HOME/.dotfiles.backup" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
if [[ "$backup_count" -eq 5 ]] && [[ ! -d "$HOME/.dotfiles.backup/20260101_000000" ]] && [[ -d "$HOME/.dotfiles.backup/20260108_000000" ]]; then
  pass "Backup rotation prunes oldest directories and retains 5 newest"
else
  fail "Backup rotation" "Expected 5 backups with oldest pruned, found $backup_count"
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
rm -f "$DOTFILES_DIR/config/git/.gitconfig.local"
zsh "$DOTFILES_DIR/dot.sh" --only setup_git >/dev/null 2>&1

if [[ -f "$DOTFILES_DIR/config/git/.gitconfig.local" ]] && grep -q "Test Bot" "$DOTFILES_DIR/config/git/.gitconfig.local"; then
  pass "Git setup automatically generates missing .gitconfig.local with user identity"
else
  fail "Git local template generator" ".gitconfig.local was not generated or missing user identity"
fi

hooks_path=$(git -C "$DOTFILES_DIR" config core.hooksPath 2>/dev/null || true)
if [[ "$hooks_path" == ".githooks" ]]; then
  pass "Git setup configures core.hooksPath to .githooks"
else
  fail "Git pre-commit hooks" "core.hooksPath is '$hooks_path', expected '.githooks'"
fi

if "$REPO_ROOT/.githooks/pre-commit" >/dev/null 2>&1; then
  pass "Git pre-commit hook runs and passes validation"
else
  fail "Git pre-commit hook" ".githooks/pre-commit failed execution"
fi

# Test custom local identity config override
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

# Test local zshrc template auto-generator
if [[ -f "$HOME/.zshrc.local" ]]; then
  pass "Zsh setup automatically generates missing ~/.zshrc.local starter template"
else
  fail "Zsh local template generator" "Expected ~/.zshrc.local to be created"
fi

# Test alias loading and function definitions
alias_test=$(zsh -c "
  source '$DOTFILES_DIR/config/zsh/aliases.zsh'
  alias gs >/dev/null 2>&1 || exit 1
  alias ga >/dev/null 2>&1 || exit 1
  alias gc >/dev/null 2>&1 || exit 1
  alias gp >/dev/null 2>&1 || exit 1
  alias gl >/dev/null 2>&1 || exit 1
  alias v >/dev/null 2>&1 || exit 1
  functions ssh-cc >/dev/null 2>&1 || exit 1
  echo 'OK'
" 2>/dev/null || echo "FAILED")

if [[ "$alias_test" == "OK" ]]; then
  pass "Git, editor, and tmux aliases/functions successfully defined"
else
  fail "Zsh aliases" "One or more core aliases/functions missing"
fi

# Test Neovim init.vim link
zsh "$DOTFILES_DIR/dot.sh" --only setup_vim >/dev/null 2>&1
if [[ -L "$HOME/.config/nvim/init.vim" ]]; then
  pass "Neovim init.vim correctly symlinked to .vimrc"
else
  fail "Neovim init.vim" "Expected symlink at $HOME/.config/nvim/init.vim"
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

# ------------------------------------------------------------------------------
# 10. Chaos & Hostile State Resilience
# ------------------------------------------------------------------------------
log_suite "Group 10: Chaos & Hostile State Resilience"

# 10.1 Broken symlink recovery
setup_sandbox
ln -s "/completely/broken/nonexistent/path" "$HOME/.zshrc"
zsh "$DOTFILES_DIR/dot.sh" --only setup_links >/dev/null 2>&1
zshrc_link="$HOME/.zshrc"
zshrc_target="$DOTFILES_DIR/config/zsh/.zshrc"
if [[ -L "$zshrc_link" && "${zshrc_link:A}" == "${zshrc_target:A}" ]]; then
  pass "Chaos: Cleanly repaired pre-existing broken symlink"
else
  fail "Chaos: Broken symlink recovery" "Failed to repair dangling symlink at ~/.zshrc"
fi
teardown_sandbox

# 10.2 Cyclic self-referencing symlink recovery
setup_sandbox
ln -s "$HOME/.tmux.conf" "$HOME/.tmux.conf" 2>/dev/null || true
zsh "$DOTFILES_DIR/dot.sh" --only setup_links >/dev/null 2>&1
tmux_link="$HOME/.tmux.conf"
tmux_target="$DOTFILES_DIR/config/tmux/.tmux.conf"
if [[ -L "$tmux_link" && "${tmux_link:A}" == "${tmux_target:A}" ]]; then
  pass "Chaos: Cleanly repaired cyclic self-referencing symlink"
else
  fail "Chaos: Cyclic symlink recovery" "Failed to recover from self-referencing symlink"
fi
teardown_sandbox

# 10.3 Existing directory collision
setup_sandbox
mkdir -p "$HOME/.vimrc/nested_content"
echo "nested" > "$HOME/.vimrc/nested_content/file.txt"
zsh "$DOTFILES_DIR/dot.sh" --only setup_links >/dev/null 2>&1
if [[ -L "$HOME/.vimrc" && -d "$HOME/.dotfiles.backup" ]]; then
  pass "Chaos: Replaced collided directory with symlink and backed up directory"
else
  fail "Chaos: Directory collision" "Failed to safely replace directory with symlink"
fi
teardown_sandbox

# 10.4 Missing parent directories for deep links (~/.config/nvim)
setup_sandbox
rm -rf "$HOME/.config"
zsh "$DOTFILES_DIR/dot.sh" --only setup_links >/dev/null 2>&1
if [[ -L "$HOME/.config/nvim/init.vim" ]]; then
  pass "Chaos: Automatically created missing parent directory hierarchy"
else
  fail "Chaos: Missing parent directories" "Failed to create ~/.config/nvim before linking"
fi
teardown_sandbox

# 10.5 SSH Config Preservation of Custom Directives
setup_sandbox
cat << 'SSHEOF' > "$HOME/.ssh/config"
# User custom host
Host custom-work-server
  User dev
  Port 2222
SSHEOF
chmod 600 "$HOME/.ssh/config"
zsh "$DOTFILES_DIR/dot.sh" --only setup_ssh >/dev/null 2>&1
if grep -q "Include .*config/ssh" "$HOME/.ssh/config" && grep -q "custom-work-server" "$HOME/.ssh/config"; then
  pass "Chaos: SSH setup preserved custom host blocks while prepending Include"
else
  fail "Chaos: SSH setup preservation" "Custom host blocks were lost during SSH setup"
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
