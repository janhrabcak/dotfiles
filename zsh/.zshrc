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
autoload -Uz add-zsh-hook
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search

# --- 4. Custom Agnoster Prompt Segments ---

# Google Rainbow Hostname (Colored Font)
prompt_google_rainbow_font() {
  local host_str=$(hostname -s)
  local len=${#host_str}
  local colors=(33 160 220 33 34 160)
  local colored_host=""
  for (( i=0; i<len; i++ )); do
    local color=${colors[$(( (i % 6) + 1 ))]}
    colored_host+="%{%F{$color}%}${host_str:$i:1}"
  done
  prompt_segment black white "%B%n@$colored_host%b"
}

# Google Rainbow Hostname (Banded Backgrounds)
prompt_google_rainbow_bg() {
  local host_str=$(hostname -s)
  local colors=(33 160 220 33 34 160)
  prompt_segment black white "%B%n@%b"
  echo -n "%{%B%}"
  for i in {1..6}; do
    local segment="${host_str:$(( (i-1)*(${#host_str}/6) )):$(( ${#host_str}/6 + (${#host_str}%6 >= i ? 1 : 0) ))}"
    [[ -z "$segment" ]] && continue
    echo -n "%{%K{${colors[$i]}}%F{white}%}$segment"
    CURRENT_BG=${colors[$i]}
  done
  echo -n "%{%b%}"
}

# Main Context Segment
prompt_context() {
  if [[ "$HOST" == *"google"* || -n "$GOOGLE_PROMPT" ]]; then
    [[ "$GOOGLE_PROMPT" == "bg" ]] && prompt_google_rainbow_bg || prompt_google_rainbow_font
  elif [[ -n "$SSH_CLIENT" ]]; then
    prompt_segment red white "%n@%m"
  elif [[ "$USER" != "$DEFAULT_USER" ]]; then
    prompt_segment black white "%n@%m"
  fi
}

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

# --- 6. iTerm2 + Tmux Visual Persistence ---

typeset -g _ITERM_LAST_STATE=""
typeset -g _ITERM_CMD_COUNT=0

function refresh_iterm_visuals() {
    # 1. Ultra-fast early exit
    [[ -z "$TMUX" ]] && return
    [[ -n "$ITERM_SESSION_ID" || "$LC_TERMINAL" == "iTerm2" || "$TERMINAL_EMULATOR" == "iTerm2" ]] || return

    # 2. Throttling: Only run every 10th command OR if state might have changed
    # We include SSH_CONNECTION to detect re-attaches from new locations
    local current_state="${HOST}:${USER}:${SSH_CONNECTION:-local}:${TMUX_PANE}"
    (( _ITERM_CMD_COUNT++ ))

    if [[ "$current_state" == "$_ITERM_LAST_STATE" && $(( _ITERM_CMD_COUNT % 10 )) -ne 0 ]]; then
        return
    fi
    _ITERM_LAST_STATE="$current_state"

    # 3. Get session name (The only "expensive" call, now throttled)
    local session_name=$(tmux display-message -p '#S' 2>/dev/null || echo "tmux")
    local badge_text=$(print -Pn "%n@%m ($session_name)")

    # 4. Apply Visuals
    if [[ "$HOST" == *"google"* || -n "$GOOGLE_PROMPT" ]]; then
        # Google Blue
        print -rn $'\e]6;1;bg;red;brightness;66\e\\\e]6;1;bg;green;brightness;133\e\\\e]6;1;bg;blue;brightness;244\e\\'
    else
        # Tmux Orange
        print -rn $'\e]6;1;bg;red;brightness;255\e\\\e]6;1;bg;green;brightness;180\e\\\e]6;1;bg;blue;brightness;0\e\\'
    fi
    print -rn $'\e]1337;SetBadgeFormat='$(echo -n "$badge_text" | base64)$'\e\\'
}

# Refresh visuals via precmd hook
add-zsh-hook precmd refresh_iterm_visuals

# Trigger immediately on startup
refresh_iterm_visuals
