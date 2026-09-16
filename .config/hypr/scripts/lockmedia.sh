#!/bin/bash
case "$1" in
  title)
    artist=$(playerctl metadata artist 2>/dev/null)
    track=$(playerctl metadata title 2>/dev/null)
    [ -z "$track" ] && echo "" || echo "$artist - $track"
    ;;
  icon)
    status=$(playerctl status 2>/dev/null)
    if [ "$status" = "Playing" ]; then
      printf '\uf04c'   # pause glyph (Nerd Font)
    else
      printf '\uf04b'   # play glyph (Nerd Font)
    fi
    ;;
esac
