# Path management
export PATH=$HOME/.bin:/usr/local/bin:$PATH
[[ -d "$HOME/.bin/google-cloud-sdk/bin" ]] && export PATH="$HOME/.bin/google-cloud-sdk/bin:$PATH"

# Path to your oh-my-zsh installation.
export OHMYZSH=$HOME/.oh-my-zsh
export DOT=$HOME/.dotfiles

# 1. Unset any existing agent to prevent conflicts
unset SSH_AUTH_SOCK

# 2. Point specifically to the 1Password socket
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

ZSH_THEME="agnoster"

# Uncomment the following line to automatically update without prompting.
DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
export UPDATE_ZSH_DAYS=13

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Standard plugins
plugins=(git colorize golang macos zsh-syntax-highlighting zsh-autosuggestions) 

source $OHMYZSH/oh-my-zsh.sh

# iTerm2 Shell Integration (Skip inside tmux to prevent Control Mode crashes)
[[ -z "$TMUX" && -e "$HOME/.iterm2_shell_integration.zsh" ]] && source "$HOME/.iterm2_shell_integration.zsh"

# Font Check for Agnoster Theme
if [[ "$ZSH_THEME" == "agnoster" ]]; then
  if ! (echo $TERMINAL_EMULATOR | grep -q "iTerm" || echo $TERM_PROGRAM | grep -q "Apple_Terminal"); then
     echo "💡 Note: The 'agnoster' theme requires Powerline-compatible fonts."
  fi
fi

# User configuration

# --- Secrets Management (1Password) ---
# Uncomment and configure this block to securely load secrets into your environment
# if command -v op >/dev/null 2>&1; then
#   # Example: Load an API key
#   # export OPENAI_API_KEY=$(op read "op://Private/OpenAI/credential")
#   
#   # Example: Evaluate a template file containing multiple secrets
#   # eval $(op inject -i ~/.env.tpl)
# fi

# You may need to manually set your language environment
export LANG=en_US.UTF-8

# History handlng
setopt APPEND_HISTORY # adds history
setopt INC_APPEND_HISTORY SHARE_HISTORY  # adds history incrementally and share it across sessions
setopt HIST_IGNORE_ALL_DUPS  # don't record dupes in history
setopt HIST_REDUCE_BLANKS
setopt EXTENDED_HISTORY # add timestamps to history

# Credits to https://coderwall.com/p/jpj_6q/zsh-better-history-searching-with-arrow-keys
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search # Up
bindkey "^[[B" down-line-or-beginning-search # Down


# Dir: current working directory
prompt_dir() {
  prompt_segment blue $CURRENT_FG '%2~'
}

# Render hostname with rainbow font colors on a black background
prompt_google_rainbow_font() {
  local host_str=$(hostname -s)
  local len=${#host_str}
  local colored_host=""
  local colors=(33 160 220 33 34 160)
  local block_size=$(( len / 6 ))
  local remainder=$(( len % 6 ))
  local start=0
  for (( i=1; i<=6; i++ )); do
    local count=$block_size
    [[ $i -le $remainder ]] && (( count++ ))
    [[ $count -gt 0 ]] && colored_host+="%{%F{${colors[$i]}}%}${host_str:$start:$count}"
    (( start += count ))
  done
  prompt_segment black white "%B%n@$colored_host%b"
}

# Render hostname with rainbow background segments and white font
prompt_google_rainbow_bg() {
  local host_str=$(hostname -s)
  local len=${#host_str}
  local colors=(33 160 220 33 34 160)
  local block_size=$(( len / 6 ))
  local remainder=$(( len % 6 ))
  local start=0
  local last_col=""
  
  # 1. Render username in standard black segment
  prompt_segment black white "%B%n@%b"
  
  # 2. Render the rainbow hostname without padding between color changes
  echo -n "%{%B%}" # Start bold
  for (( i=1; i<=6; i++ )); do
    local count=$block_size
    [[ $i -le $remainder ]] && (( count++ ))
    if [[ $count -gt 0 ]]; then
      local segment="${host_str:$start:$count}"
      local current_col="${colors[$i]}"
      
      if [[ -z "$last_col" ]]; then
        # First segment: draw the arrow from black to this first Google color
        echo -n "%{%K{$current_col}%F{black}%}$SEGMENT_SEPARATOR%{%F{white}%}$segment"
      else
        # Subsequent segments: just change background color (no padding/arrows)
        echo -n "%{%K{$current_col}%}$segment"
      fi
      
      (( start += count ))
      last_col=$current_col
    fi
  done
  echo -n "%{%b%}" # End bold
  
  # 3. Update CURRENT_BG so the next Agnoster segment draws its arrow correctly
  CURRENT_BG=$last_col
}

# Context: user@hostname (who am I and where am I)
prompt_context() {
  # 1. Google-specific styling
  if [[ "$HOST" == *"google"* || "$(hostname)" == *"google"* || -n "$GOOGLE_PROMPT" ]]; then
     if [[ "$GOOGLE_PROMPT" == "bg" ]]; then
        prompt_google_rainbow_bg
     else
        prompt_google_rainbow_font
     fi
  # 2. General remote server warning (Red background)
  elif [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" || -n "$SSH_CONNECTION" ]]; then
     prompt_segment red white "%(!.%{%F{yellow}%}.)%n@%m"
  # 3. Local non-default user (Black background)
  elif [[ "$USER" != "$DEFAULT_USER" ]]; then
     prompt_segment black white "%(!.%{%F{yellow}%}.)%n@%m"
  fi
}

DEFAULT_USER=`whoami`

# --- Terminal Title Management ---

function set_terminal_title() {
  local title_str="$1"
  
  # Prefix with [REMOTE] if connected via SSH
  if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" || -n "$SSH_CONNECTION" ]]; then
    title_str="[REMOTE] $title_str"
  fi

  case $TERM in
    xterm*|rxvt*|alacritty|kitty|gnome*|screen*|tmux*)
      # Use the standard OSC 2 escape sequence to set the window/tab title
      # %n = username, %m = short hostname, %~ = directory with ~ expansion
      print -Pn "\e]2;${title_str}\a"
      ;;
  esac
}

# Automatically update title before showing the prompt (shows current directory)
function title_precmd() {
  set_terminal_title "%n@%m: %~"
}

# Automatically update title before running a command (shows the command name)
function title_preexec() {
  # $1 is the full command string
  local cmd="${1[(w)1]}"
  set_terminal_title "$cmd | %~"
}

# Register the hooks
autoload -Uz add-zsh-hook

# --- iTerm2 + Tmux Awareness ---
function iterm2_tmux_visuals() {
  # Only run if we are in iTerm2
  [[ "$ITERM_SESSION_ID" == "" && "$TERMINAL_EMULATOR" != "iTerm2" ]] && return

  if [[ -n "$TMUX" ]]; then
    # 1. Set Large Badge (Session Name)
    local session_name=$(tmux display-message -p '#S' 2>/dev/null || echo "TMUX")
    printf "\e]1337;SetBadgeFormat=%s\a" $(echo -n "$session_name" | base64)

    # 2. Shift Background
    printf "\e]11;#0f1419\a"

    # 3. Color the Tab
    printf "\e]6;1;bg;red;brightness;255\a"
    printf "\e]6;1;bg;green;brightness;180\a"
    printf "\e]6;1;bg;blue;brightness;0\a"
  else
    # RESET visuals
    printf "\e]1337;SetBadgeFormat=%s\a" $(echo -n "" | base64)
    printf "\e]11;default\a" 
    printf "\e]6;1;bg;*;default\a"
  fi
}

add-zsh-hook precmd title_precmd
add-zsh-hook preexec title_preexec
add-zsh-hook precmd iterm2_tmux_visuals

# Load Aliases
[[ -f "$HOME/.aliases.zsh" ]] && source "$HOME/.aliases.zsh"

# Load Local Overrides
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

