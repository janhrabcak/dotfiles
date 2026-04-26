# ==============================================================================
# ZSH CONFIGURATION (.zshrc)
# ==============================================================================

# --- 1. Environment & Identity ---
export DOT="$HOME/.dotfiles"
export OHMYZSH="$HOME/.oh-my-zsh"
export DEFAULT_USER=$(whoami)
export LANG=en_US.UTF-8

# Path management
export PATH="$HOME/.bin:/usr/local/bin:$PATH"
[[ -d "$HOME/.bin/google-cloud-sdk/bin" ]] && export PATH="$HOME/.bin/google-cloud-sdk/bin:$PATH"

# SSH Agent Persistence (Linux/Remote only)
if [[ "$OSTYPE" != "darwin"* ]]; then
  # 1. If we have a fresh agent, update the stable symlink
  if [[ -S "$SSH_AUTH_SOCK" && "$SSH_AUTH_SOCK" != "$HOME/.ssh/ssh_auth_sock" ]]; then
    ln -sf "$SSH_AUTH_SOCK" "$HOME/.ssh/ssh_auth_sock"
  fi
  # 2. Always prefer the stable symlink if it exists (ensures tmux persistence)
  if [[ -S "$HOME/.ssh/ssh_auth_sock" ]]; then
    export SSH_AUTH_SOCK="$HOME/.ssh/ssh_auth_sock"
  fi
fi

# --- 2. Oh My Zsh Settings ---
ZSH_THEME="agnoster"
DISABLE_UPDATE_PROMPT="true"
UPDATE_ZSH_DAYS=13
plugins=(git colorize golang macos zsh-syntax-highlighting zsh-autosuggestions)

source "$OHMYZSH/oh-my-zsh.sh"

# iTerm2 Shell Integration (Skip inside tmux to prevent Control Mode crashes)
[[ -z "$TMUX" && -e "$HOME/.iterm2_shell_integration.zsh" ]] && source "$HOME/.iterm2_shell_integration.zsh"

# --- 3. Shell Options & Behavior ---
setopt APPEND_HISTORY INC_APPEND_HISTORY SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS EXTENDED_HISTORY

# Better history searching with arrow keys
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search

# --- 4. Custom Agnoster Prompt Segments ---



# --- 5. Terminal Title & Hooks ---
autoload -Uz add-zsh-hook

function set_terminal_title() {
  local title="$1"
  [[ -n "$SSH_CLIENT" ]] && title="[REMOTE] $title"
  case $TERM in
    xterm*|rxvt*|alacritty|kitty|gnome*|screen*|tmux*)
      print -Pn "\e]2;${title}\a"
      ;;
  esac
}

add-zsh-hook precmd  () { set_terminal_title "%n@%m: %~" }
add-zsh-hook preexec () { set_terminal_title "${1[(w)1]} | %~" }

# --- 6. Final Inclusions & Visuals ---

# Load Aliases & Local Overrides
[[ -f "$HOME/.aliases.zsh" ]] && source "$HOME/.aliases.zsh"
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# --- 6. Custom Agnoster Prompt Segments ---

# Context / Identity Segment (Unified Google & SSH Logic)
prompt_context() {
  # 1. Google Identity (Official Brand Colors)
  if [[ "$(hostname -s)" == *"google"* || -n "$GOOGLE_PROMPT" ]]; then
    local h=$(hostname -s)
    local c=(33 160 220 33 64 160) # Google Blue, Red, Yellow, Blue, Green, Red
    local rb=""
    for (( i=0; i<${#h}; i++ )); do rb+="%F{${c[i % 6 + 1]}}${h:i:1}%f"; done
    prompt_segment black default "$rb"
    return
  fi

  # 2. Standard SSH / Non-Default User (Red)
  if [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]; then
    prompt_segment red black "%(!.%{%F{yellow}%}.)$USER@%m"
  fi
}

# Clean Build Order
build_prompt() {
  RETVAL=$?
  prompt_status
  prompt_virtualenv
  prompt_context
  prompt_dir
  prompt_git
  prompt_end
}
