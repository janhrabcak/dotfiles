# ==============================================================================
# ZSH ALIASES
# ==============================================================================

# --- Navigation & File Listing ---
if [[ "$OSTYPE" == "darwin"* ]]; then
  alias ls="ls -laG"
else
  alias ls="ls -la --color=auto"
fi
alias l="ls"
alias ll="ls -la"
alias la="ls -A"
alias lh="ls -lh"
alias sl="ls"
alias s="ls"
alias ..="cd .."
alias ...="cd ../.."

# --- Git ---
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git log --oneline --graph --decorate"

# --- Tmux ---
alias tn="tmux new"
alias ta="tmux attach"

# --- SSH & Networking ---
alias sshp="ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no"
alias gv="rw papagaj.hot.corp.google.com"
alias vssh="$DOT/bin/ssh-tmux papagaj.hot.corp.google.com"

# --- Developer Tools ---
alias objdump="command objdump -M intel"

# --- Helpers ---
# Desktop notification for long-running commands
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Manual prompt overrides
alias gprompt="export GOOGLE_PROMPT=true"
alias unprompt="unset GOOGLE_PROMPT"
