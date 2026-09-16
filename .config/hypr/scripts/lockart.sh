#!/bin/bash
OUT="/tmp/hyprlock_art.png"
URL=$(playerctl metadata mpris:artUrl 2>/dev/null)

if [ -z "$URL" ]; then
  # no player / no art -> point at a fallback image you provide
  echo "$HOME/.config/hypr/assets/no-art.png"
  exit 0
fi

if [[ "$URL" == file://* ]]; then
  # local file (mpd, some native players) -- just resolve the path
  echo "${URL#file://}"
elif [[ "$URL" == https://* || "$URL" == http://* ]]; then
  # streaming cover (Spotify, browser MPRIS, etc) -- download once, cache by URL hash
  HASH=$(echo -n "$URL" | md5sum | cut -d' ' -f1)
  CACHE="/tmp/hyprlock_art_${HASH}.png"
  [ -f "$CACHE" ] || curl -s -o "$CACHE" "$URL"
  echo "$CACHE"
fi

