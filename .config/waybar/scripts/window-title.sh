#!/usr/bin/env bash
# Streams the focused window's title, per-output, to waybar's custom/window
# module. Takes the Hyprland output name (e.g. "eDP-1") as $1: only title
# changes for windows on that output are shown, so each monitor's bar keeps
# the last title that was active on it.
#
# No fade here — the module just emits a width-tier class per title length,
# and style.css transitions #custom-window's padding, so the pill eases
# in/out on title changes while the text itself swaps instantly.
set -uo pipefail

MONITOR_ARG="${1:-}"
SOCK="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
MAX_LEN=60

current=""
# Marker for "showing the Desktop fallback", distinct from any real
# (sanitized) title so update()/show_desktop() dedup correctly.
DESKTOP_MARKER=$'\x01DESKTOP'

# Strip emoji / dingbats / variation selectors / ZWJ: these commonly fall
# back to a font whose glyphs are taller than the UI font, which otherwise
# stretches waybar's height whenever such a character appears in a title.
sanitize() {
    perl -CSD -pe '
        s/[\x{25A0}-\x{25FF}]//g;
        s/[\x{2600}-\x{27BF}]//g;
        s/[\x{2800}-\x{28FF}]//g;
        s/[\x{1F000}-\x{1FFFF}]//g;
        s/[\x{FE00}-\x{FE0F}]//g;
        s/\x{200D}//g;
        s/^\s+//;
        s/\s+$//;
    '
}

json_escape() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    printf '%s' "$s"
}

truncate_title() {
    local t=$1
    if [ "${#t}" -gt "$MAX_LEN" ]; then
        printf '%s…' "${t:0:$((MAX_LEN - 1))}"
    else
        printf '%s' "$t"
    fi
}

# Buckets title length into one of 14 width classes (w1..w14) defined in
# style.css, so the CSS transition has a concrete padding value to animate to.
width_class() {
    local len=$1
    local tier=$(( (len + 3) / 4 ))
    [ "$tier" -lt 1 ] && tier=1
    [ "$tier" -gt 14 ] && tier=14
    printf 'w%d' "$tier"
}

emit() {
    local raw=$1 text cls
    text=$(truncate_title "$raw")
    if [ -z "$text" ]; then
        cls="empty"
    else
        cls=$(width_class "${#text}")
    fi
    printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' \
        "$(json_escape "$text")" "$cls" "$(json_escape "$raw")"
}

monitor_id_for() {
    local name=$1
    [ -z "$name" ] && return
    hyprctl monitors 2>/dev/null \
        | awk -v n="$name" '$0 ~ "^Monitor "n" \\(" { gsub(/[()]/,""); print $4 }' \
        | tr -d ':'
}

TARGET_ID="$(monitor_id_for "$MONITOR_ARG")"

active_monitor()     { hyprctl activewindow 2>/dev/null | awk -F': ' '/^\tmonitor:/{print $2; exit}'; }
active_title()       { hyprctl activewindow 2>/dev/null | awk -F': ' '/^\ttitle:/{ sub(/^\ttitle: /,""); print; exit }'; }

# Whether any window at all currently sits on our monitor. Needed because
# Hyprland's activewindow event only tells us about the *globally* focused
# window going away, not about a monitor being emptied out while focus
# lives elsewhere (e.g. the last window on this screen gets closed while
# another monitor has focus) — so we check independently on every event.
monitor_has_windows() {
    if [ -z "$MONITOR_ARG" ]; then
        [ -n "$(hyprctl clients 2>/dev/null)" ]
    else
        hyprctl clients 2>/dev/null | awk -v target="$TARGET_ID" '
            /^\tmonitor: /{ v=$0; sub(/^\tmonitor: /,"",v); if (v==target) found=1 }
            END{ exit !found }
        '
    fi
}

# On startup, the globally focused window may not be on our monitor — fall
# back to whichever window on this monitor has the lowest focusHistoryID
# (Hyprland's most-recently-focused-here marker) instead of showing blank.
last_title_for_monitor() {
    local target=$1
    hyprctl clients 2>/dev/null | awk -v target="$target" '
        function flush() {
            if (mon == target && (best == "" || fhid < best)) { best = fhid; besttitle = title }
            mon = ""; fhid = ""; title = ""
        }
        /^Window /{
            flush()
            title = $0
            sub(/^Window [^ ]+ -> /, "", title)
            sub(/:$/, "", title)
        }
        /^\tmonitor: /{ sub(/^\tmonitor: /, ""); mon = $0 }
        /^\tfocusHistoryID: /{ sub(/^\tfocusHistoryID: /, ""); fhid = $0 + 0 }
        /^$/{ flush() }
        END{ flush(); print besttitle }
    '
}

on_our_monitor() {
    [ -z "$MONITOR_ARG" ] && return 0
    [ "$1" = "$TARGET_ID" ]
}

update() {
    local new
    new=$(printf '%s' "$1" | sanitize)
    [ "$new" = "$current" ] && return
    current=$new
    emit "$new"
}

show_desktop() {
    [ "$current" = "$DESKTOP_MARKER" ] && return
    current="$DESKTOP_MARKER"
    emit "Desktop"
}

refresh() {
    if ! monitor_has_windows; then
        show_desktop
        return
    fi
    if on_our_monitor "$(active_monitor)"; then
        update "$(active_title)"
    else
        update "$(last_title_for_monitor "$TARGET_ID")"
    fi
}

refresh

socat -U - UNIX-CONNECT:"$SOCK" 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        activewindow\>\>*|windowtitlev2\>\>*|closewindow\>\>*)
            refresh
            ;;
    esac
done
