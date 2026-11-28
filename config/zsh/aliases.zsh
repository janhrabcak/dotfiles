# ==============================================================================
# ZSH ALIASES
# ==============================================================================

# --- Navigation & File Listing ---
if [[ "$OSTYPE" == "darwin"* ]]; then
  _ls_flags="-laG"
else
  _ls_flags="-la --color=auto"
fi
alias ls="ls $_ls_flags"
alias l="ls"
alias ll="command ls $_ls_flags"
alias la="command ls -A"
alias lh="command ls -lh"
alias sl="ls"
alias s="ls"
alias ..="cd .."
alias ...="cd ../.."
unset _ls_flags

# --- Git ---
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git log --oneline --graph --decorate"

# --- Tmux ---
alias tn="tmux new"
alias ta="tmux attach"
alias tcc="tmux -CC attach || tmux -CC new" # iTerm2 Control Mode
ssh-cc() { ssh -t "$@" 'tmux -CC attach || tmux -CC new'; }

# --- SSH & Networking ---
alias sshp="ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no"
# Note: Place private/work hosts and custom aliases into ~/.zshrc.local (automatically sourced)

# --- Editor ---
if command -v nvim >/dev/null 2>&1; then
  alias v="nvim"
  alias vim="nvim"
else
  alias v="vim"
fi

# --- Developer Tools ---
alias objdump="command objdump -M intel"

# --- Helpers ---
# Desktop notification for long-running commands (notify-send)
alert() {
  local rc=$?
  local icon="terminal"
  (( rc != 0 )) && icon="error"
  command -v notify-send >/dev/null 2>&1 && notify-send --urgency=low -i "$icon" "Command completed" "${history[$HISTCMD]}"
}

# Update local dotfiles deployment (supports both Git clones and --remote tarball installs)
dot-update() {
  local dot="${DOT:-$HOME/.dotfiles}"
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
  if [[ ! -d "$dot" ]]; then
    echo "[dotfiles] Directory not found: $dot" >&2
    return 1
  fi

  if [[ -d "$dot/.git" ]]; then
    if [[ -n "$(git -C "$dot" status --porcelain 2>/dev/null)" ]]; then
      echo "[dotfiles] Uncommitted local changes in $dot — commit or stash before updating." >&2
      return 1
    fi
    git -C "$dot" pull --ff-only || return $?
    "$dot/dot.sh" "$@" || return $?
  else
    "$dot/dot.sh" --remote "$@" || return $?
    if command -v curl >/dev/null 2>&1; then
      local api_url="${DOTFILES_REMOTE_API:-https://api.github.com/repos/janhrabcak/dotfiles/commits/main}"
      local hdr new_etag=""
      while IFS= read -r hdr; do
        hdr="${hdr%$'\r'}"
        if [[ "${hdr:l}" == etag:* ]]; then
          new_etag="${${hdr#*:}# }"
          break
        fi
      done < <(curl -fsSI --max-time 5 "$api_url" 2>/dev/null || true)
      if [[ -n "$new_etag" ]]; then
        mkdir -p "$cache_dir"
        printf '%s\n' "$new_etag" > "$cache_dir/remote.etag"
      fi
    fi
  fi

  "$dot/dot.sh" --doctor
  local rc=$?
  mkdir -p "$cache_dir"
  rm -f "$cache_dir/update-available"
  touch "$cache_dir/last-check"
  return $rc
}

# Manual prompt overrides (set to any non-empty value to activate Google prompt style)
alias gprompt="export GOOGLE_PROMPT=1"
alias unprompt="unset GOOGLE_PROMPT"
