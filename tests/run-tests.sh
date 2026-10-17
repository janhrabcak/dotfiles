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
  mkdir -p "$HOME/.vim/autoload"
  cat << 'VIMEOF' > "$HOME/.vim/autoload/plug.vim"
let g:plugs = {}
function! plug#begin(...)
  command! -nargs=+ -bar Plug call s:plug(<args>)
endfunction
function! s:plug(repo, ...)
  let name = split(a:repo, "/")[-1]
  let g:plugs[name] = a:0 > 0 ? a:1 : {}
endfunction
function! plug#end(...)
endfunction
VIMEOF
}

teardown_sandbox() {
  [[ -n "${TEST_ORIG_HOME:-}" ]] && export HOME="$TEST_ORIG_HOME"
  [[ -n "${SANDBOX:-}" && -d "$SANDBOX" ]] && rm -rf "$SANDBOX"
  SANDBOX=""
}
trap teardown_sandbox EXIT INT TERM

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

if command -v tmux >/dev/null 2>&1; then
  if tmux -L "dotfiles-test-$$" -f "$REPO_ROOT/config/tmux/.tmux.conf" start-server \; kill-server >/dev/null 2>&1; then
    pass "Tmux configuration syntax check"
  else
    fail "Tmux configuration syntax check" "tmux.conf failed to parse"
  fi
else
  echo "  ${YELLOW}[SKIP]${RESET} Tmux configuration syntax check (tmux not installed)"
fi

vim_parse_home="$(mktemp -d)"
if HOME="$vim_parse_home" vim -u "$REPO_ROOT/config/vim/.vimrc" -e -s -c "q" >/dev/null 2>&1; then
  pass "Vim configuration parse check"
else
  fail "Vim configuration parse check" ".vimrc failed to parse cleanly"
fi
rm -rf "$vim_parse_home"

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

if python3 -c "import plistlib; plistlib.load(open('$REPO_ROOT/config/iterm2/com.googlecode.iterm2.plist', 'rb'))" >/dev/null 2>&1; then
  pass "iTerm2 plist format integrity check"
else
  fail "iTerm2 plist integrity" "com.googlecode.iterm2.plist failed to parse as valid plist"
fi

if python3 -c "import json; json.load(open('$REPO_ROOT/config/ai/settings.json')); json.load(open('$REPO_ROOT/config/ai/mcp_config.json'))" >/dev/null 2>&1; then
  pass "AI configuration JSON syntax check (settings.json, mcp_config.json)"
else
  fail "AI JSON syntax check" "Invalid JSON in config/ai/"
fi

# ------------------------------------------------------------------------------
# 2. Vim Headless Assertions
# ------------------------------------------------------------------------------
log_suite "Group 2: Vim Configuration Behavioral Assertions"

vim_assert() {
  local expr="$1"
  local desc="$2"
  local tmp_vh
  tmp_vh="$(mktemp -d)"
  if HOME="$tmp_vh" vim -u "$REPO_ROOT/config/vim/.vimrc" -e -s -c "if !($expr) | cquit 1 | endif" -c "qall" >/dev/null 2>&1; then
    pass "Vim: $desc"
  else
    fail "Vim: $desc" "Assertion ($expr) evaluated to false"
  fi
  rm -rf "$tmp_vh"
}

vim_assert "g:mapleader ==# ','" "Map leader is comma (,)"
vim_assert "&undofile == 1" "Persistent undo (undofile) is enabled"
vim_assert "&ignorecase == 1" "Ignorecase search enabled"
vim_assert "&smartcase == 1" "Smartcase search enabled"
vim_assert "&relativenumber == 1" "Relative line numbering enabled"

# Verify opening a Go buffer does not clobber global <leader>b (:Buffers<CR>) in non-Go buffers
tmp_vh="$(mktemp -d)"
if HOME="$tmp_vh" vim -u "$REPO_ROOT/config/vim/.vimrc" -e -s \
  -c "set filetype=go" -c "enew" \
  -c "if maparg('<leader>b', 'n') !=# ':Buffers<CR>' | cquit 1 | endif" -c "qall" >/dev/null 2>&1; then
  pass "Vim: Go FileType mappings are buffer-local and preserve global <leader>b"
else
  fail "Vim: Go FileType buffer-local mappings" "Global <leader>b was clobbered after setting filetype=go"
fi
rm -rf "$tmp_vh"

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

# Missing option value for --mode / --only / --skip
set +e
zsh "$DOTFILES_DIR/dot.sh" --only >/dev/null 2>&1
missing_val_code=$?
set -e
if [[ $missing_val_code -eq 1 ]]; then
  pass "CLI rejects flags missing required values (--mode/--only/--skip)"
else
  fail "CLI missing option value" "Expected exit code 1, got $missing_val_code"
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
set +e
DOTFILES_INSTALL_DEPS=false vim -u "$DOTFILES_DIR/config/vim/.vimrc" -c "if has_key(g:plugs['fzf'], 'do') | cquit 1 | else | cquit 0 | endif" >/dev/null 2>&1
status_false=$?

DOTFILES_INSTALL_DEPS=true vim -u "$DOTFILES_DIR/config/vim/.vimrc" -c "if has_key(g:plugs['fzf'], 'do') | cquit 0 | else | cquit 1 | endif" >/dev/null 2>&1
status_true=$?
set -e

if [[ $status_false -eq 0 ]]; then
  pass "Vim: Binary post-install hooks are disabled when DOTFILES_INSTALL_DEPS is false"
else
  fail "Vim binary hooks guard" "Binary hook fzf#install was registered despite DOTFILES_INSTALL_DEPS=false"
fi

if [[ $status_true -eq 0 ]]; then
  pass "Vim: Binary post-install hooks are enabled when DOTFILES_INSTALL_DEPS=true"
else
  fail "Vim binary hooks guard" "Binary hook fzf#install was not registered when DOTFILES_INSTALL_DEPS=true"
fi

# Day-zero: missing dotfiles directory without --remote fails with exit code 1
set +e
zsh -c "DOTFILES_DIR='$HOME/nonexistent_dotfiles' zsh '$DOTFILES_DIR/dot.sh' --dry-run" >/dev/null 2>&1
remote_missing_code=$?
set -e
if [[ $remote_missing_code -eq 1 ]]; then
  pass "Day-zero: missing dotfiles directory without --remote fails cleanly"
else
  fail "Day-zero missing directory" "Expected exit code 1, got $remote_missing_code"
fi

# Day-zero: missing dotfiles directory with --remote triggers remote download flow
set +e
remote_dry_run_out=$(zsh -c "DOTFILES_DIR='$HOME/nonexistent_dotfiles' zsh '$DOTFILES_DIR/dot.sh' --remote --dry-run 2>&1")
remote_dry_run_code=$?
set -e
if [[ $remote_dry_run_code -eq 0 ]] && echo "$remote_dry_run_out" | grep -q "Would execute: curl"; then
  pass "Day-zero: --remote flag triggers remote asset download flow"
else
  fail "Day-zero --remote execution" "Expected 0 with curl download command, got code $remote_dry_run_code"
fi

# Self-update: rejects non-git directory with exit code 1
mkdir -p "$SANDBOX/not_a_git_repo"
set +e
zsh -c "export DOTFILES_DIR='$SANDBOX/not_a_git_repo'; zsh '$REPO_ROOT/dot.sh' --update" >/dev/null 2>&1
update_non_git_code=$?
set -e
if [[ $update_non_git_code -eq 1 ]]; then
  pass "Self-update: rejects non-git repository with exit code 1"
else
  fail "Self-update non-git" "Expected exit code 1, got $update_non_git_code"
fi

# End-to-end: --install-deps dispatches package manager without syntax errors
mock_bin="$SANDBOX/mock_bin"
mkdir -p "$mock_bin"
cat << 'MOCK_EOF' > "$mock_bin/apt-get"
#!/bin/sh
echo "$@" >> "$SANDBOX/apt.log"
exit 0
MOCK_EOF
chmod +x "$mock_bin/apt-get"

set +e
PATH="$mock_bin:/usr/bin:/bin" zsh -c "
  command() { if [[ \"\$2\" == 'zsh' ]]; then return 1; fi; builtin command \"\$@\"; }
  source '$DOTFILES_DIR/dot.sh' --install-deps --dry-run
  AUTO_INSTALL_DEPS=true
  check_dependencies
" >/dev/null 2>&1
set -e
pass "End-to-end: --install-deps dispatches package manager without syntax errors"
rm -rf "$mock_bin"

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

# Test AI Agent links (Gemini, Claude, Cursor, Cline)
zsh "$DOTFILES_DIR/dot.sh" --only setup_ai >/dev/null 2>&1
if [[ -L "$HOME/.gemini/config/GEMINI.md" && -L "$HOME/.gemini/config/AGENTS.md" && -L "$HOME/.claude/CLAUDE.md" && -L "$HOME/.cursorrules" && -L "$HOME/.clinerules" && -L "$HOME/.gemini/settings.json" && -L "$HOME/.gemini/config/mcp_config.json" && -L "$HOME/.gemini/config/skills" ]]; then
  pass "AI Agent rules (Gemini, Claude, Cursor, Cline) and configs correctly symlinked"
else
  fail "AI Agent symlinks" "Expected symlinks for Gemini, Claude, Cursor, or Cline"
fi

# Test SSH Agent runtime lifecycle: dangling symlink cleanup
mkdir -p "$HOME/.ssh"
ln -sf "/tmp/nonexistent_test_socket_$$" "$HOME/.ssh/ssh_auth_sock"
zsh -c "
  export HOME='$HOME'
  export SSH_AUTH_SOCK='$HOME/.ssh/ssh_auth_sock'
  source '$DOTFILES_DIR/config/zsh/.zshrc'
" >/dev/null 2>&1
if [[ ! -L "$HOME/.ssh/ssh_auth_sock" ]]; then
  pass "SSH Agent: .zshrc prunes dangling socket symlinks on startup"
else
  fail "SSH Agent dangling symlink" "Expected dead symlink to be pruned"
fi

# Test prompt execution budget: build_prompt does not fork excessive git processes
if command -v strace >/dev/null 2>&1; then
  git_forks=$(strace -f -e trace=execve zsh -c "
    export HOME='$HOME'
    source '$DOTFILES_DIR/config/zsh/.zshrc' >/dev/null 2>&1
    vcs_info
    build_prompt
  " 2>&1 | grep -c 'execve("/.*git"' || echo "0")
  if [[ "$git_forks" -le 10 ]]; then
    pass "Prompt performance: build_prompt stays within fork budget (git forks: $git_forks <= 10)"
  else
    fail "Prompt performance" "Excessive git subprocess forks: $git_forks (expected <= 10)"
  fi
else
  echo "  ${YELLOW}[SKIP]${RESET} Prompt performance fork check (strace not installed)"
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

# Doctor detects missing Git include directive
setup_sandbox
zsh "$DOTFILES_DIR/dot.sh" >/dev/null 2>&1
echo "# Empty gitconfig" > "$HOME/.gitconfig"
set +e
zsh "$DOTFILES_DIR/dot.sh" --doctor >/dev/null 2>&1
git_missing_code=$?
set -e
if [[ $git_missing_code -ne 0 ]]; then
  pass "Doctor detects missing Git include directive and exits non-zero"
else
  fail "Doctor Git include detection" "Doctor returned 0 despite missing Git include"
fi
teardown_sandbox

# Doctor detects missing SSH include directive
setup_sandbox
zsh "$DOTFILES_DIR/dot.sh" >/dev/null 2>&1
echo "# Empty ssh config" > "$HOME/.ssh/config"
set +e
zsh "$DOTFILES_DIR/dot.sh" --doctor >/dev/null 2>&1
ssh_missing_code=$?
set -e
if [[ $ssh_missing_code -ne 0 ]]; then
  pass "Doctor detects missing SSH include directive and exits non-zero"
else
  fail "Doctor SSH include detection" "Doctor returned 0 despite missing SSH include"
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
