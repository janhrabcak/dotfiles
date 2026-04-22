# Path management
export PATH=$HOME/.bin:/usr/local/bin:$PATH
[[ -d "$HOME/.bin/google-cloud-sdk/bin" ]] && export PATH="$HOME/.bin/google-cloud-sdk/bin:$PATH"

# Path to your oh-my-zsh installation.
export OHMYZSH=$HOME/.oh-my-zsh
export DOT=$HOME/.dotfiles

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

# Context: user@hostname (who am I and where am I)
prompt_context() {
  # 1. Google-specific styling (Rainbow Hostname)
  if [[ "$HOST" == *"google"* || "$(hostname)" == *"google"* || "$GOOGLE_PROMPT" == "true" ]]; then
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
     prompt_segment black white "%n@$colored_host"
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
add-zsh-hook precmd title_precmd
add-zsh-hook preexec title_preexec

# Load Aliases
[[ -f "$DOT/zsh/aliases.zsh" ]] && source "$DOT/zsh/aliases.zsh"

