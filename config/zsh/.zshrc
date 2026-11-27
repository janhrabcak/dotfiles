# ==============================================================================
# ZSH CONFIGURATION (.zshrc)
# ==============================================================================

# --- 1. Environment & Identity ---
export DOT="$HOME/.dotfiles"
export OHMYZSH="$HOME/.oh-my-zsh"
export DEFAULT_USER="${USER:-$(whoami)}"
export LANG=en_US.UTF-8

# Completion Caching
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"

# Path management
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
[[ -d "$HOME/.npm-global/bin" ]] && export PATH="$HOME/.npm-global/bin:$PATH"

# SSH Agent Persistence (Linux/Remote only)
if [[ "$OSTYPE" != "darwin"* ]]; then
  _setup_ssh_agent() {
    local auth_symlink="$HOME/.ssh/ssh_auth_sock"
    # 1. If we have a fresh agent, update the stable symlink (only fork ln if target changed)
    if [[ -n "$SSH_AUTH_SOCK" && -S "$SSH_AUTH_SOCK" && "$SSH_AUTH_SOCK" != "$auth_symlink" ]]; then
      [[ -d "$HOME/.ssh" ]] || mkdir -p -m 700 "$HOME/.ssh"
      [[ "${auth_symlink:A}" != "${SSH_AUTH_SOCK:A}" ]] && ln -sf "$SSH_AUTH_SOCK" "$auth_symlink"
      export SSH_AUTH_SOCK="$auth_symlink"
    # 2. If falling back to existing symlink (e.g. inside tmux), verify the agent socket is live
    elif [[ -S "$auth_symlink" ]]; then
      local agent_rc=0
      SSH_AUTH_SOCK="$auth_symlink" ssh-add -l >/dev/null 2>&1 || agent_rc=$?
      if (( agent_rc != 2 )); then
        export SSH_AUTH_SOCK="$auth_symlink"
      else
        rm -f "$auth_symlink"
        [[ "$SSH_AUTH_SOCK" == "$auth_symlink" ]] && unset SSH_AUTH_SOCK
      fi
    elif [[ -L "$auth_symlink" ]]; then
      rm -f "$auth_symlink"
      [[ "$SSH_AUTH_SOCK" == "$auth_symlink" ]] && unset SSH_AUTH_SOCK
    fi
  }
  _setup_ssh_agent
  unfunction _setup_ssh_agent
fi

# --- 2. Oh My Zsh Settings ---
ZSH_THEME="agnoster"
DISABLE_UPDATE_PROMPT="true"
UPDATE_ZSH_DAYS=13
plugins=(git colorize golang zsh-autosuggestions zsh-syntax-highlighting)
[[ "$OSTYPE" == darwin* ]] && plugins+=(macos)

[[ -f "$OHMYZSH/oh-my-zsh.sh" ]] && source "$OHMYZSH/oh-my-zsh.sh"

# iTerm2 Shell Integration (Required for Automatic Profile Switching)
[[ -e "$HOME/.iterm2_shell_integration.zsh" ]] && source "$HOME/.iterm2_shell_integration.zsh"

# --- 3. Shell Options & Behavior ---
setopt APPEND_HISTORY INC_APPEND_HISTORY SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS EXTENDED_HISTORY

# Better history searching with arrow keys
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search


# --- 4. Terminal Title & Hooks ---
autoload -Uz add-zsh-hook vcs_info

set_terminal_title() {
  local title="$1"
  [[ -n "$SSH_CLIENT" ]] && title="[REMOTE] $title"
  case "$TERM" in
    xterm*|rxvt*|alacritty|kitty|gnome*|screen*|tmux*)
      print -Pn "\e]2;${title}\a"
      ;;
  esac
}

_title_precmd() {
  set_terminal_title "%n@%m: %~"
}

_title_preexec() {
  set_terminal_title "${1[(w)1]} | %~"
}

# Native Zsh VCS Info (replaces OMZ prompt_git to eliminate subshell forks)
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' max-exports 2
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr '✚'
zstyle ':vcs_info:git:*' unstagedstr '±'
zstyle ':vcs_info:git:*' formats '%b' '%u%c'
zstyle ':vcs_info:git:*' actionformats '%b|%a' '%u%c'

add-zsh-hook precmd _title_precmd
add-zsh-hook precmd vcs_info
add-zsh-hook preexec _title_preexec

# --- 5. Custom Agnoster Prompt Segments ---

# Fallback prompt helpers when Oh My Zsh / Agnoster is not installed
if (( ! $+functions[prompt_segment] )); then
  prompt_segment() { [[ -n "${3:-}" ]] && print -n "${3} "; }
  prompt_status() { (( RETVAL != 0 )) && print -n "%F{red}✘%f "; }
  prompt_virtualenv() { [[ -n "${VIRTUAL_ENV:-}" ]] && print -n "(${VIRTUAL_ENV:t}) "; }
  prompt_end() { print -n "%# "; }
fi

# Context / Identity Segment (Unified Google & SSH Logic)
prompt_context() {
  local h="${HOST:-$HOSTNAME}"
  [[ -z "$h" ]] && h=$(hostname)

  # 1. Google Identity (Official Brand Colors)
  if [[ "$h" == *"google"* || -n "$GOOGLE_PROMPT" ]]; then
    local c=(33 160 220 33 64 160) # Google Blue, Red, Yellow, Blue, Green, Red
    local rb="%(!.%{%F{yellow}%}.)$USER@"
    local len=${#h}
    # Distribute the 6 brand colors evenly across any hostname length
    for (( i=1; i<=len; i++ )); do
      local color_idx=$(( (i - 1) * 6 / len + 1 ))
      rb+="%F{${c[color_idx]}}${h[$i]}%f"
    done
    prompt_segment black default "$rb"
    return
  fi

  # 2. Standard SSH / Root / Non-Default User (Red)
  if [[ $EUID -eq 0 || "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]; then
    prompt_segment red black "%(!.%{%F{yellow}%}.)$USER@%M"
  fi
}

# Dir: current working directory (Limited to 3 levels)
prompt_dir() {
  prompt_segment blue black '%3~'
}

# Git Segment (Streamlined via Zsh native vcs_info)
prompt_git() {
  [[ -z "$vcs_info_msg_0_" ]] && return
  local pl_branch_char=$'\ue0a0'
  local status_str=""
  [[ -n "$vcs_info_msg_1_" ]] && status_str=" $vcs_info_msg_1_"
  if [[ -n "$vcs_info_msg_1_" ]]; then
    prompt_segment "${AGNOSTER_GIT_DIRTY_BG:-yellow}" "${AGNOSTER_GIT_DIRTY_FG:-black}" "${pl_branch_char} ${vcs_info_msg_0_}${status_str}"
  else
    prompt_segment "${AGNOSTER_GIT_CLEAN_BG:-green}" "${AGNOSTER_GIT_CLEAN_FG:-black}" "${pl_branch_char} ${vcs_info_msg_0_}"
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

# --- 6. Passive Update Check (Git & Non-Git ETag) ---
_dotfiles_check_updates() {
  [[ -o interactive && "${GITHUB_ACTIONS:-}" != "true" && "${DOTFILES_AUTO_CHECK:-1}" != "0" && -d "$DOT" ]] || return 0

  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
  local stamp_file="$cache_dir/last-check"
  local notice_file="$cache_dir/update-available"
  local etag_file="$cache_dir/remote.etag"

  if [[ -f "$notice_file" ]]; then
    print -P "%F{yellow}[dotfiles]%f Update available — run %Bdot-update%b to sync."
  fi

  zmodload -F zsh/stat b:zstat 2>/dev/null || return 0
  zmodload zsh/datetime 2>/dev/null || return 0

  local interval=$(( ${DOTFILES_UPDATE_DAYS:-7} * 86400 ))
  local last_check=0
  [[ -f "$stamp_file" ]] && last_check=$(zstat +mtime "$stamp_file" 2>/dev/null || echo 0)
  (( EPOCHSECONDS - last_check >= interval )) || return 0

  [[ -d "$cache_dir" ]] || mkdir -p "$cache_dir"
  touch "$stamp_file"

  (
    if [[ -d "$DOT/.git" ]]; then
      git -C "$DOT" fetch -q --prune 2>/dev/null || exit 0
      local local_sha remote_sha
      local_sha="$(git -C "$DOT" rev-parse HEAD 2>/dev/null)" || exit 0
      remote_sha="$(git -C "$DOT" rev-parse '@{u}' 2>/dev/null || git -C "$DOT" rev-parse origin/main 2>/dev/null)" || exit 0
      if [[ "$local_sha" != "$remote_sha" ]] && git -C "$DOT" merge-base --is-ancestor "$local_sha" "$remote_sha" 2>/dev/null; then
        touch "$notice_file"
      else
        rm -f "$notice_file"
      fi
    elif command -v curl >/dev/null 2>&1; then
      local api_url="https://api.github.com/repos/janhrabcak/dotfiles/commits/main"
      local saved_etag="" headers http_code new_etag
      [[ -f "$etag_file" ]] && saved_etag="$(<"$etag_file")"
      if [[ -n "$saved_etag" ]]; then
        headers="$(curl -fsSI --max-time 5 -H "If-None-Match: $saved_etag" "$api_url" 2>/dev/null)" || exit 0
      else
        headers="$(curl -fsSI --max-time 5 "$api_url" 2>/dev/null)" || exit 0
      fi
      http_code="$(printf '%s\n' "$headers" | awk 'NR==1 {print $2}')"
      new_etag="$(printf '%s\n' "$headers" | awk 'tolower($1)=="etag:" {gsub(/\r/,""); print $2; exit}')"
      if [[ "$http_code" == "304" ]]; then
        rm -f "$notice_file"
      elif [[ "$http_code" == "200" && -n "$new_etag" ]]; then
        if [[ -z "$saved_etag" ]]; then
          printf '%s\n' "$new_etag" > "$etag_file"
        elif [[ "$new_etag" != "$saved_etag" ]]; then
          touch "$notice_file"
        fi
      fi
    fi
  ) </dev/null >/dev/null 2>&1 &!
}
_dotfiles_check_updates
unfunction _dotfiles_check_updates

# --- 7. Aliases & Local Overrides ---
[[ -f "$HOME/.aliases.zsh" ]] && source "$HOME/.aliases.zsh"
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
:
