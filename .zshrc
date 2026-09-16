# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# ---- vi mode ----
bindkey -v
export KEYTIMEOUT=25   # ms*10 to wait for multi-char sequences; lower = snappier Esc

# reduce mode-switch lag/flicker in the prompt (optional but common with vi-mode)
# (Starship handles its own vi indicator if you enable it)

# Home / End
bindkey -M viins '^[[H' beginning-of-line
bindkey -M viins '^[[F' end-of-line
bindkey -M vicmd '^[[H' beginning-of-line
bindkey -M vicmd '^[[F' end-of-line

# Ctrl-Left / Ctrl-Right (word jump) — kitty sends these xterm-style codes
bindkey -M viins '^[[1;5C' forward-word
bindkey -M viins '^[[1;5D' backward-word
bindkey -M vicmd '^[[1;5C' forward-word
bindkey -M vicmd '^[[1;5D' backward-word

# Standard editing keys in insert mode (these aren't vi defaults)
bindkey -M viins '^A' beginning-of-line
bindkey -M viins '^E' end-of-line
bindkey -M viins '^U' backward-kill-line      # kill to start of line (bash-style)
bindkey -M viins '^K' kill-line               # kill to end of line
bindkey -M viins '^W' backward-kill-word
bindkey -M viins '^Y' yank
bindkey -M viins '^R' history-incremental-search-backward

# Backspace/Delete
bindkey -M viins '^?' backward-delete-char
bindkey -M viins '^[[3~' delete-char

# ---- history ----
HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY APPEND_HISTORY

# ---- completion ----
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# ---- aliases ----
alias grep='grep --color=auto'
alias larp='tmuxinator start larp'
alias ls='eza --group-directories-first --icons=auto'
alias ll='eza -lah --group-directories-first --icons=auto --git'
alias lt='eza --tree --level=2 --icons=auto'
alias cat='bat --paging=never'
alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

# ---- custom ----

bt() {
  local mac
  case "$1" in
    scan)
      echo "scanning 10s..."
      bluetoothctl --timeout 10 scan on >/dev/null 2>&1
      mac=$(bluetoothctl devices | fzf --with-nth 3.. --prompt="pair> " | cut -d' ' -f2)
      [ -n "$mac" ] && bluetoothctl pair "$mac" && bluetoothctl trust "$mac" \
        && bluetoothctl connect "$mac"
      ;;
    off|d|disconnect)
      mac=$(bluetoothctl devices Connected | fzf --with-nth 3.. --prompt="disconnect> " | cut -d' ' -f2)
      [ -n "$mac" ] && bluetoothctl disconnect "$mac"
      ;;
    rm|forget)
      mac=$(bluetoothctl devices | fzf --with-nth 3.. --prompt="remove> " | cut -d' ' -f2)
      [ -n "$mac" ] && bluetoothctl remove "$mac"
      ;;
    *)
      mac=$(bluetoothctl devices | fzf --with-nth 3.. --prompt="connect> " | cut -d' ' -f2)
      [ -n "$mac" ] && bluetoothctl connect "$mac"
      ;;
  esac
}

# ---- node ----
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac

# ---- tools ----
eval "$(zoxide init zsh --cmd cd)"

[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# ---- prompt ----
eval "$(starship init zsh)"

# syntax highlighting must be LAST
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# pnpm
export PNPM_HOME='/home/schultzh/.local/share/pnpm'
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end
