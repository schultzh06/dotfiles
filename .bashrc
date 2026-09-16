#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# ---- history ----
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend checkwinsize

# ---- grep colors ----
alias grep='grep --color=auto'

# ---- custom ----
alias larp='tmuxinator start larp'
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

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

# ---- modern CLI ----
alias ls='eza --group-directories-first --icons=auto'
alias ll='eza -lah --group-directories-first --icons=auto --git'
alias lt='eza --tree --level=2 --icons=auto'
alias cat='bat --paging=never'
alias bat='bat --paging=always'

eval "$(zoxide init bash --cmd cd)"

[ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash
[ -f /usr/share/fzf/completion.bash ] && source /usr/share/fzf/completion.bash

# ---- node ----
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac

# starship — keep LAST
eval "$(starship init bash)"
