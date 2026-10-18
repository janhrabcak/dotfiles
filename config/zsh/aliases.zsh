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
  local icon="terminal"
  (( $? != 0 )) && icon="error"
  command -v notify-send >/dev/null 2>&1 && notify-send --urgency=low -i "$icon" "Command completed" "${history[$HISTCMD]}"
}

# Manual prompt overrides (set to any non-empty value to activate Google prompt style)
alias gprompt="export GOOGLE_PROMPT=1"
alias unprompt="unset GOOGLE_PROMPT"
