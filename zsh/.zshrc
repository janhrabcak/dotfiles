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

prompt_context() {
  if [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
#    Show only username without hostname
#    prompt_segment black default "%(!.%{%F{yellow}%}.)$USER"
     prompt_segment black default "%(!.%{%F{yellow}%}.)%n@%m"
  fi
}

DEFAULT_USER=`whoami`

function title() {
  # escape '%' chars in $1, make nonprintables visible
  a=${(V)1//\%/\%\%}

  # Truncate command, and join lines.
  a=$(print -Pn "%40>...>$a" | tr -d "\n")

  case $TERM in
  screen)
    print -Pn "\ek$a:$3\e\\" # screen title (in ^A")
    ;;
  xterm*|rxvt)
    print -Pn "\e]2;$2\a" # plain xterm title ($3 for pwd)
    ;;
  esac
}

# Aliases
#alias gv="$HOME/_profile/home_dir/bin/auth-refresh-gtunnel.py papagaj.hot.corp.google.com"
alias gv="rw papagaj.hot.corp.google.com"
alias vssh="$HOME/_profile/home_dir/bin/ssh-tmux papagaj.hot.corp.google.com"

# Git
alias gs="git status"

# Tmux
alias tn="tmux new"
alias ta="tmux attach"


alias sshp="ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no"

alias ll="ls -laG"
alias lo="ls -o"
alias lh="ls -lh"
alias la="ls -la"
alias sl="ls"
alias l="ls"
alias s="ls"


# Intel format plz
alias objdump="command objdump -M intel"

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

