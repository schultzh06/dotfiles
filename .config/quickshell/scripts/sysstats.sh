#!/usr/bin/env bash
# Polled every ~2s by SysStats.qml. Emits three lines to stdout:
#   line 1: raw /proc/stat cpu fields, memory (used/total GB), cpu temp C
#   line 2: network status as "<kind> <name>" (kind: ethernet|wifi|offline)
#   line 3: network tooltip detail as "<ifname> <ipaddr>"
set -uo pipefail

read -r _ u n s i wa irq softirq steal _ < /proc/stat

mem=$(awk '
    /^MemTotal:/{t=$2}
    /^MemAvailable:/{a=$2}
    END{printf "%.3f %.3f", (t-a)/1048576, t/1048576}
' /proc/meminfo)

temp=0
for d in /sys/class/hwmon/hwmon*; do
    name="$(cat "$d/name" 2>/dev/null)"
    if [ "$name" = "k10temp" ] || [ "$name" = "coretemp" ]; then
        v=$(cat "$d/temp1_input" 2>/dev/null) && temp=$((v / 1000))
        break
    fi
done

net_kind="offline"
net_name=""
if nmcli -t -f TYPE,STATE dev status 2>/dev/null | grep -q '^ethernet:connected$'; then
    net_kind="ethernet"
elif ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}') && [ -n "$ssid" ]; then
    net_kind="wifi"
    net_name="$ssid"
fi

ifname=""
if [ "$net_kind" != "offline" ]; then
    ifname=$(nmcli -t -f DEVICE,TYPE,STATE dev status 2>/dev/null | awk -F: -v k="$net_kind" '$2==k && $3=="connected"{print $1; exit}')
fi
ipaddr=""
[ -n "$ifname" ] && ipaddr=$(ip -4 -o addr show "$ifname" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)

printf '%s %s %s %s %s %s %s %s %s %s %s\n' "$u" "$n" "$s" "$i" "$wa" "$irq" "$softirq" "$steal" $mem "$temp"
printf '%s %s\n' "$net_kind" "$net_name"
printf '%s %s\n' "${ifname:--}" "${ipaddr:--}"
