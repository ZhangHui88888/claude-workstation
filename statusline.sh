#!/usr/bin/env bash
# Claude Code statusLine: ccline output with effort level after the model + 5h/weekly rate limits (from the JSON Claude Code passes in).
# Shared by WSL and native Windows (Git Bash); needs jq and ccline in ~/.claude/ccline/.
input=$(cat)
ccline=~/.claude/ccline/ccline
[[ -x $ccline.exe ]] && ccline+=.exe
base=$(printf '%s' "$input" | "$ccline")

IFS=$'\t' read -r effort h5 h5r d7 d7r < <(printf '%s' "$input" | jq -r '[
  (.effort.level // "-"),
  (.rate_limits.five_hour.used_percentage // "-"),
  (.rate_limits.five_hour.resets_at // 0),
  (.rate_limits.seven_day.used_percentage // "-"),
  (.rate_limits.seven_day.resets_at // 0)
] | @tsv' | tr -d '\r')

# Usage color: <50 green, <80 yellow, else red
color() { [[ $1 == - ]] && { printf '37'; return; }; (( ${1%.*} < 50 )) && printf '92' || { (( ${1%.*} < 80 )) && printf '93' || printf '91'; }; }
fmt_reset() { (( $1 > 0 )) && date -d "@$1" "$2" || printf -- '-'; }

sep=$'\e[37m | \e[0m'
# Effort goes right after the model (ccline's first segment, same separator)
if [[ $base == *"$sep"* ]]; then
  base="${base%%"$sep"*} "$'\e[95m🧠 '"${effort}"$'\e[0m'"${sep}${base#*"$sep"}"
else
  base+=" "$'\e[95m🧠 '"${effort}"$'\e[0m'
fi
extra="\e[$(color "$h5")m5h ${h5}%\e[0m \e[90m$(fmt_reset "$h5r" +%H:%M)\e[0m${sep}"
extra+="\e[$(color "$d7")m周 ${d7}%\e[0m \e[90m$(fmt_reset "$d7r" '+%m-%d %H:%M')\e[0m"
printf '%s%s%b\n' "$base" "$sep" "$extra"
