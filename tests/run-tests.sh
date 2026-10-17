#!/usr/bin/env zsh
# ==============================================================================
# UNIFIED TEST SUITE FOR DOTFILES BOOTSTRAPPER
# ==============================================================================
# Runs behavioral and invariant checks in isolated temporary sandboxes.
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
  mkdir -p "$HOME/.ssh" "$DOTFILES_DIR" "$HOME/.vim/autoload"
  chmod 700 "$HOME/.ssh"
  touch "$HOME/.ssh/config" && chmod 600 "$HOME/.ssh/config"

  cp "$REPO_ROOT/dot.sh" "$DOTFILES_DIR/"
  cp -R "$REPO_ROOT/.githooks" "$REPO_ROOT/config" "$DOTFILES_DIR/"
  git init -q "$DOTFILES_DIR"

  git config --global user.name "Test Bot"
  git config --global user.email "test@example.com"

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

[[ -x "$REPO_ROOT/.githooks/pre-commit" ]] \
  && pass "Pre-commit hook is present and executable" \
  || fail "Pre-commit hook" ".githooks/pre-commit is missing or not executable"

[[ -f "$REPO_ROOT/.github/dependabot.yml" ]] \
  && pass "Dependabot configuration present" \
  || fail "Dependabot configuration" ".github/dependabot.yml is missing"

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

[[ -f "$REPO_ROOT/config/brew/Brewfile" ]] \
  && pass "Homebrew Brewfile present" \
  || fail "Homebrew Brewfile" "config/brew/Brewfile is missing"

if grep -q "corp.google.com" "$REPO_ROOT/config/zsh/aliases.zsh"; then
  fail "Secret sanitization" "Corporate hostnames detected in aliases.zsh"
else
  pass "Secret sanitization: no internal corporate hostnames in public config"
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
  local expr="$1" desc="$2" tmp_vh
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
# 3. CLI Argument Handling & Safety
# ------------------------------------------------------------------------------
log_suite "Group 3: CLI Flags & Safety"

setup_sandbox

set +e
zsh "$DOTFILES_DIR/dot.sh" --invalid-flag >/dev/null 2>&1
exit_code=$?
zsh "$DOTFILES_DIR/dot.sh" --only >/dev/null 2>&1
missing_val_code=$?
set -e

[[ $exit_code -eq 1 ]] \
  && pass "CLI rejects unknown parameters with exit code 1" \
  || fail "CLI rejects unknown parameters" "Expected exit code 1, got $exit_code"

[[ $missing_val_code -eq 1 ]] \
  && pass "CLI rejects flags missing required values (--mode/--only)" \
  || fail "CLI missing option value" "Expected exit code 1, got $missing_val_code"

zsh "$DOTFILES_DIR/dot.sh" --dry-run >/dev/null 2>&1
if [[ ! -L "$HOME/.zshrc" && ! -L "$HOME/.vimrc" && ! -L "$HOME/.tmux.conf" ]]; then
  pass "Dry-run leaves home directory completely untouched"
else
  fail "Dry-run leaves home directory untouched" "Found modified/created symlinks after --dry-run"
fi

zsh "$DOTFILES_DIR/dot.sh" --only setup_git >/dev/null 2>&1
if grep -q "config/git/.gitconfig" "$HOME/.gitconfig" && [[ ! -L "$HOME/.zshrc" && ! -L "$HOME/.vimrc" ]]; then
  pass "--only flag executes targeted step only"
else
  fail "--only flag targeted execution" "Targeted step failed or side-effect files created"
fi

ln -s "$DOTFILES_DIR/nonexistent_test_dead" "$HOME/.dead_dotfile"
ln -s "/nonexistent_external_target" "$HOME/.dead_external"
zsh "$DOTFILES_DIR/dot.sh" --clean --dry-run >/dev/null 2>&1
if [[ -L "$HOME/.dead_dotfile" && -L "$HOME/.dead_external" ]]; then
  pass "--clean --dry-run leaves all symlinks untouched"
else
  fail "--clean --dry-run" "Symlink was unexpectedly removed during dry run"
fi

zsh "$DOTFILES_DIR/dot.sh" --clean >/dev/null 2>&1
if [[ ! -L "$HOME/.dead_dotfile" && -L "$HOME/.dead_external" ]]; then
  pass "--clean prunes dead dotfiles symlinks while preserving external symlinks"
else
  fail "--clean pruning" "Dead dotfiles symlink was not pruned or external symlink was removed"
fi

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

set +e
DOTFILES_INSTALL_DEPS=false vim -u "$DOTFILES_DIR/config/vim/.vimrc" -c "if has_key(g:plugs['fzf'], 'do') | cquit 1 | else | cquit 0 | endif" >/dev/null 2>&1
status_false=$?
DOTFILES_INSTALL_DEPS=true vim -u "$DOTFILES_DIR/config/vim/.vimrc" -c "if has_key(g:plugs['fzf'], 'do') | cquit 0 | else | cquit 1 | endif" >/dev/null 2>&1
status_true=$?
set -e

[[ $status_false -eq 0 ]] \
  && pass "Vim: Binary post-install hooks are disabled when DOTFILES_INSTALL_DEPS is false" \
  || fail "Vim binary hooks guard" "Binary hook fzf#install was registered despite DOTFILES_INSTALL_DEPS=false"

[[ $status_true -eq 0 ]] \
  && pass "Vim: Binary post-install hooks are enabled when DOTFILES_INSTALL_DEPS=true" \
  || fail "Vim binary hooks guard" "Binary hook fzf#install was not registered when DOTFILES_INSTALL_DEPS=true"

set +e
zsh -c "DOTFILES_DIR='$HOME/nonexistent_dotfiles' zsh '$DOTFILES_DIR/dot.sh' --dry-run" >/dev/null 2>&1
remote_missing_code=$?
remote_dry_run_out=$(zsh -c "DOTFILES_DIR='$HOME/nonexistent_dotfiles' zsh '$DOTFILES_DIR/dot.sh' --remote --dry-run 2>&1")
remote_dry_run_code=$?
set -e

[[ $remote_missing_code -eq 1 ]] \
  && pass "Day-zero: missing dotfiles directory without --remote fails cleanly" \
  || fail "Day-zero missing directory" "Expected exit code 1, got $remote_missing_code"

if [[ $remote_dry_run_code -eq 0 ]] && echo "$remote_dry_run_out" | grep -q "Would execute: curl"; then
  pass "Day-zero: --remote flag triggers remote asset download flow"
else
  fail "Day-zero --remote execution" "Expected 0 with curl download command, got code $remote_dry_run_code"
fi

mock_bin="$SANDBOX/mock_bin"
mkdir -p "$mock_bin"
cat << 'MOCK_EOF' > "$mock_bin/apt-get"
#!/bin/sh
exit 0
MOCK_EOF
chmod +x "$mock_bin/apt-get"

set +e
deps_out=$(PATH="$mock_bin:/usr/bin:/bin" zsh -c "
  command() { if [[ \"\$2\" == 'zsh' ]]; then return 1; fi; builtin command \"\$@\"; }
  source '$DOTFILES_DIR/dot.sh' --install-deps --dry-run
  AUTO_INSTALL_DEPS=true
  check_dependencies
" 2>&1)
deps_code=$?
set -e
if [[ $deps_code -eq 0 ]] && echo "$deps_out" | grep -q "install -y zsh"; then
  pass "End-to-end: --install-deps dispatches package manager without syntax errors"
else
  fail "End-to-end: --install-deps dispatch" "Expected exit 0 and package install command, got $deps_code"
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

[[ -L "$HOME/.zshrc" ]] \
  && pass "Pre-existing file replaced by symlink" \
  || fail "Pre-existing file replacement" "$HOME/.zshrc is not a symlink"

backup_file=$(find "$HOME/.dotfiles.backup" -type f -name ".zshrc" 2>/dev/null | head -n 1)
if [[ -n "$backup_file" ]] && grep -q "$UNIQUE_CONTENT" "$backup_file"; then
  pass "Pre-existing file safely backed up with identical contents"
else
  fail "Safe backup" "Backup not found or content altered"
fi

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

[[ -f "$HOME/.ssh/config" ]] \
  && pass "SSH config created/updated" \
  || fail "SSH config existence" "$HOME/.ssh/config does not exist"

perm=$(stat -c "%a" "$HOME/.ssh/config" 2>/dev/null || stat -f "%OLp" "$HOME/.ssh/config" 2>/dev/null || echo "unknown")
[[ "$perm" == "600" ]] \
  && pass "SSH config file permissions strictly enforced to 600" \
  || fail "SSH config permissions" "Expected 600, got $perm"

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

hooks_path=$(git -C "$DOTFILES_DIR" config core.hooksPath 2>/dev/null || true)
[[ "$hooks_path" == ".githooks" ]] \
  && pass "Git setup configures core.hooksPath to .githooks" \
  || fail "Git pre-commit hooks" "core.hooksPath is '$hooks_path', expected '.githooks'"

if "$REPO_ROOT/.githooks/pre-commit" >/dev/null 2>&1; then
  pass "Git pre-commit hook runs and passes validation"
else
  fail "Git pre-commit hook" ".githooks/pre-commit failed execution"
fi

cat << 'CONFIG_EOF' > "$DOTFILES_DIR/config/git/.gitconfig.local"
[user]
	name = Test Identity
	email = identity@testdomain.com
CONFIG_EOF

git_resolved_email=$(git config user.email 2>/dev/null || true)
[[ "$git_resolved_email" == "identity@testdomain.com" ]] \
  && pass "Git include path resolves local identity (.gitconfig.local)" \
  || fail "Git include path resolution" "Expected identity@testdomain.com, got '$git_resolved_email'"

teardown_sandbox

# ------------------------------------------------------------------------------
# 7. Zsh Runtime Environment & Aliases
# ------------------------------------------------------------------------------
log_suite "Group 7: Zsh Environment & Aliases"

setup_sandbox
zsh "$DOTFILES_DIR/dot.sh" --only setup_zsh >/dev/null 2>&1

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

[[ "$alias_test" == "OK" ]] \
  && pass "Git, editor, and tmux aliases/functions successfully defined" \
  || fail "Zsh aliases" "One or more core aliases/functions missing"

zsh "$DOTFILES_DIR/dot.sh" --only setup_vim >/dev/null 2>&1
[[ -L "$HOME/.config/nvim/init.vim" ]] \
  && pass "Neovim init.vim correctly symlinked to .vimrc" \
  || fail "Neovim init.vim" "Expected symlink at $HOME/.config/nvim/init.vim"

zsh "$DOTFILES_DIR/dot.sh" --only setup_ai >/dev/null 2>&1
if [[ -L "$HOME/.gemini/config/GEMINI.md" && -L "$HOME/.gemini/config/AGENTS.md" && -L "$HOME/.claude/CLAUDE.md" && -L "$HOME/.gemini/settings.json" && -L "$HOME/.gemini/config/mcp_config.json" && -L "$HOME/.gemini/config/skills" ]]; then
  pass "AI Agent rules (Gemini, Claude) and configs correctly symlinked"
else
  fail "AI Agent symlinks" "Expected symlinks for Gemini and Claude"
fi

mkdir -p "$HOME/.ssh"
ln -sf "/tmp/nonexistent_test_socket_$$" "$HOME/.ssh/ssh_auth_sock"
zsh -c "
  export HOME='$HOME'
  export SSH_AUTH_SOCK='$HOME/.ssh/ssh_auth_sock'
  source '$DOTFILES_DIR/config/zsh/.zshrc'
" >/dev/null 2>&1
[[ ! -L "$HOME/.ssh/ssh_auth_sock" ]] \
  && pass "SSH Agent: .zshrc prunes dangling socket symlinks on startup" \
  || fail "SSH Agent dangling symlink" "Expected dead symlink to be pruned"

if command -v strace >/dev/null 2>&1; then
  git_forks=$(strace -f -e trace=execve zsh -c "
    export HOME='$HOME'
    source '$DOTFILES_DIR/config/zsh/.zshrc' >/dev/null 2>&1
    vcs_info
    build_prompt
  " 2>&1 | grep -c 'execve("/.*git"' || echo "0")
  [[ "$git_forks" -le 10 ]] \
    && pass "Prompt performance: build_prompt stays within fork budget (git forks: $git_forks <= 10)" \
    || fail "Prompt performance" "Excessive git subprocess forks: $git_forks (expected <= 10)"
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

set +e
zsh "$DOTFILES_DIR/dot.sh" --doctor >/dev/null 2>&1
exit_code=$?
set -e
[[ $exit_code -eq 0 ]] \
  && pass "Doctor reports success (exit 0) on healthy installation" \
  || fail "Doctor healthy check" "Expected 0, got $exit_code"

rm -f "$HOME/.vimrc"
ln -s "/nonexistent/path/to/vimrc" "$HOME/.vimrc"
set +e
zsh "$DOTFILES_DIR/dot.sh" --doctor >/dev/null 2>&1
exit_code=$?
set -e
[[ $exit_code -ne 0 ]] \
  && pass "Doctor detects broken symlink and exits with non-zero status" \
  || fail "Doctor broken symlink detection" "Doctor returned 0 despite broken symlink"

# Repair symlink and test missing Git include directive
zsh "$DOTFILES_DIR/dot.sh" --only setup_vim >/dev/null 2>&1
echo "# Empty gitconfig" > "$HOME/.gitconfig"
set +e
zsh "$DOTFILES_DIR/dot.sh" --doctor >/dev/null 2>&1
git_missing_code=$?
set -e
[[ $git_missing_code -ne 0 ]] \
  && pass "Doctor detects missing Git include directive and exits non-zero" \
  || fail "Doctor Git include detection" "Doctor returned 0 despite missing Git include"

# Repair Git and test missing SSH include directive
zsh "$DOTFILES_DIR/dot.sh" --only setup_git >/dev/null 2>&1
echo "# Empty ssh config" > "$HOME/.ssh/config"
set +e
zsh "$DOTFILES_DIR/dot.sh" --doctor >/dev/null 2>&1
ssh_missing_code=$?
set -e
[[ $ssh_missing_code -ne 0 ]] \
  && pass "Doctor detects missing SSH include directive and exits non-zero" \
  || fail "Doctor SSH include detection" "Doctor returned 0 despite missing SSH include"

teardown_sandbox

# ------------------------------------------------------------------------------
# 9. Idempotency & Chaos State Resilience
# ------------------------------------------------------------------------------
log_suite "Group 9: Idempotency & Chaos Resilience"

setup_sandbox
zsh "$DOTFILES_DIR/dot.sh" >/dev/null 2>&1
snapshot_first=$(ls -l "$HOME/.zshrc" "$HOME/.vimrc" "$HOME/.aliases.zsh")

zsh "$DOTFILES_DIR/dot.sh" >/dev/null 2>&1
snapshot_second=$(ls -l "$HOME/.zshrc" "$HOME/.vimrc" "$HOME/.aliases.zsh")

[[ "$snapshot_first" == "$snapshot_second" ]] \
  && pass "Second execution is completely idempotent (no link changes)" \
  || fail "Idempotency" "Symlinks changed after second execution"

# Broken symlink recovery
rm -f "$HOME/.zshrc"
ln -s "/completely/broken/nonexistent/path" "$HOME/.zshrc"
zsh "$DOTFILES_DIR/dot.sh" --only setup_links >/dev/null 2>&1
zshrc_link="$HOME/.zshrc"
zshrc_target="$DOTFILES_DIR/config/zsh/.zshrc"
[[ -L "$zshrc_link" && "${zshrc_link:A}" == "${zshrc_target:A}" ]] \
  && pass "Chaos: Cleanly repaired pre-existing broken symlink" \
  || fail "Chaos: Broken symlink recovery" "Failed to repair dangling symlink at ~/.zshrc"

# Cyclic self-referencing symlink recovery
rm -f "$HOME/.tmux.conf"
ln -s "$HOME/.tmux.conf" "$HOME/.tmux.conf" 2>/dev/null || true
zsh "$DOTFILES_DIR/dot.sh" --only setup_links >/dev/null 2>&1
tmux_link="$HOME/.tmux.conf"
tmux_target="$DOTFILES_DIR/config/tmux/.tmux.conf"
[[ -L "$tmux_link" && "${tmux_link:A}" == "${tmux_target:A}" ]] \
  && pass "Chaos: Cleanly repaired cyclic self-referencing symlink" \
  || fail "Chaos: Cyclic symlink recovery" "Failed to recover from self-referencing symlink"

# Existing directory collision
rm -f "$HOME/.vimrc"
mkdir -p "$HOME/.vimrc/nested_content"
echo "nested" > "$HOME/.vimrc/nested_content/file.txt"
zsh "$DOTFILES_DIR/dot.sh" --only setup_links >/dev/null 2>&1
[[ -L "$HOME/.vimrc" && -d "$HOME/.dotfiles.backup" ]] \
  && pass "Chaos: Replaced collided directory with symlink and backed up directory" \
  || fail "Chaos: Directory collision" "Failed to safely replace directory with symlink"

# Missing parent directories for deep links (~/.config/nvim)
rm -rf "$HOME/.config"
zsh "$DOTFILES_DIR/dot.sh" --only setup_links >/dev/null 2>&1
[[ -L "$HOME/.config/nvim/init.vim" ]] \
  && pass "Chaos: Automatically created missing parent directory hierarchy" \
  || fail "Chaos: Missing parent directories" "Failed to create ~/.config/nvim before linking"

# SSH Config Preservation of Custom Directives
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
