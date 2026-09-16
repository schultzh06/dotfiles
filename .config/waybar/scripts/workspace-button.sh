#!/usr/bin/env bash
# Drives one workspace-number button for one output. Takes the Hyprland
# output name and a workspace id as args (e.g. "eDP-1" 3). Shows/hides
# itself depending on whether that workspace currently exists on that
# output, and highlights when it's the globally active workspace.
#
# Exists because hyprland/workspaces' own click handler is hardcoded in
# waybar's C++ to call Hyprland's plain-text dispatch IPC ("workspace 3"),
# which this Hyprland build (native Lua config, 0.56.2) no longer accepts
# from external clients — every dispatch call is routed through a Lua
# evaluator expecting `hl.dsp.*` call syntax instead, so waybar's built-in
# click silently fails for everyone, not just this config. There's no way
# to override just the click on that module (no on-click support), so this
# reimplements the display logic and points on-click at the working
# `hyprctl dispatch 'hl.dsp.focus({ workspace = N })'` form instead
# (confirmed working — see hyprland.lua's own numbered keybinds, which use
# exactly this call).
set -uo pipefail

OUTPUT="$1"
ID="$2"
SOCK="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"

current=""

emit() {
    local exists=$1 active=$2
    if [ "$exists" != "1" ]; then
        printf '{"text":"","class":"empty"}\n'
        return
    fi
    local cls="normal"
    [ "$active" = "1" ] && cls="active"
    printf '{"text":"%s","class":"%s"}\n' "$ID" "$cls"
}

state() {
    local exists=0 active=0 found act_id
    found=$(hyprctl workspaces 2>/dev/null | awk -v id="$ID" -v out="$OUTPUT" '
        $0 ~ "^workspace ID "id" \\(" && $0 ~ ("on monitor "out":$") { print "yes"; exit }
    ')
    [ -n "$found" ] && exists=1

    act_id=$(hyprctl activeworkspace 2>/dev/null | awk '/^workspace ID/{print $3; exit}')
    [ "$act_id" = "$ID" ] && active=1

    printf '%s %s' "$exists" "$active"
}

update() {
    local new="$1"
    [ "$new" = "$current" ] && return
    current="$new"
    local exists active
    read -r exists active <<< "$new"
    emit "$exists" "$active"
}

update "$(state)"

socat -U - UNIX-CONNECT:"$SOCK" 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        *workspace*|focusedmon\>\>*)
            update "$(state)"
            ;;
    esac
done
