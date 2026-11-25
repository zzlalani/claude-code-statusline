#!/bin/bash
# Claude Code status line: model + thinking effort, context usage bar, rate-limit bars with reset countdowns.
input=$(cat)

# Decimal-comma locales make printf/awk reject the "12.4"-style percentages in the input.
export LC_ALL=C

# Empty fields become "-" because read collapses consecutive tabs (IFS whitespace).
IFS=$'\t' read -r model effort thinking used_pct ctx_tokens ctx_size five five_reset week week_reset < <(
  echo "$input" | jq -r '
    def f: if . == null or . == "" then "-" else tostring end;
    [
      .model.display_name,
      .effort.level,
      (.thinking.enabled // false),
      .context_window.used_percentage,
      (.context_window.current_usage
        | if . == null then null
          else ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))
          end),
      .context_window.context_window_size,
      .rate_limits.five_hour.used_percentage,
      .rate_limits.five_hour.resets_at,
      .rate_limits.seven_day.used_percentage,
      .rate_limits.seven_day.resets_at
    ] | map(f) | @tsv'
)
for var in model effort used_pct ctx_tokens ctx_size five five_reset week week_reset; do
  [ "${!var}" = "-" ] && printf -v "$var" '%s' ''
done

DIM='\033[2m'
RESET='\033[0m'
CYAN='\033[2;36m'
TRACK='\033[38;5;238m'
GREEN='\033[38;5;42m'
BLUE='\033[38;5;39m'
ORANGE='\033[38;5;208m'
RED='\033[38;5;196m'
BLOOD='\033[38;5;124m'

now=$(date +%s)

BAR_WIDTH=8

# STATUSLINE_WIDTH wins; otherwise the width Claude Code passes via COLUMNS (no tty is available), then tput.
# The detected width keeps a margin because Claude Code crops the status line well short of COLUMNS (measured: 117 columns, ~100 visible).
DETECTED_MARGIN=17
detect_width() {
  local cols="${COLUMNS:-0}"
  [[ "$cols" =~ ^[0-9]+$ ]] && [ "$cols" -gt 0 ] || cols=$(tput cols 2>/dev/null)
  [[ "$cols" =~ ^[0-9]+$ ]] && [ "$cols" -gt "$DETECTED_MARGIN" ] || cols=80
  echo $(( cols - DETECTED_MARGIN ))
}
LINE_WIDTH="${STATUSLINE_WIDTH:-$(detect_width)}"
ACCOUNT_FILE="${STATUSLINE_CLAUDE_JSON:-$HOME/.claude.json}"

# Per-item "blue orange red blood" lower bounds (% used); below the first is green.
CTX_THRESHOLDS="30 50 70 90"
FIVE_HOUR_THRESHOLDS="50 70 90 100"
SEVEN_DAY_THRESHOLDS="80 90 95 100"

# Thresholds are integers, so flooring the percentage is equivalent to comparing the raw float.
severity_color() {
  local pct="${1%.*}" blue orange red blood
  read -r blue orange red blood <<< "$2"
  pct="${pct:-0}"
  if [ "$pct" -ge "$blood" ]; then echo "$BLOOD"
  elif [ "$pct" -ge "$red" ]; then echo "$RED"
  elif [ "$pct" -ge "$orange" ]; then echo "$ORANGE"
  elif [ "$pct" -ge "$blue" ]; then echo "$BLUE"
  else echo "$GREEN"
  fi
}

repeat_block() {
  local count="$1" out="" i
  for ((i=0; i<count; i++)); do out="${out}█"; done
  printf "%s" "$out"
}

# Render an 8-segment solid bar for a percentage in the given color.
render_bar() {
  local pct="$1" color="$2" width="$BAR_WIDTH" filled
  filled=$(awk -v p="$pct" -v w="$width" 'BEGIN{v=int((p/100)*w+0.5); if(v>w)v=w; if(v<0)v=0; print v}')
  printf "%b%s%b%b%s%b" "$color" "$(repeat_block "$filled")" "$RESET" "$TRACK" "$(repeat_block $((width - filled)))" "$RESET"
}

# Format seconds-until epoch as "4h18m" or "2d3h".
fmt_countdown() {
  local target="$1" diff d h m
  [ -z "$target" ] && return
  diff=$(( target - now ))
  [ "$diff" -lt 0 ] && diff=0
  d=$(( diff / 86400 ))
  h=$(( (diff % 86400) / 3600 ))
  m=$(( (diff % 3600) / 60 ))
  if [ "$d" -gt 0 ]; then
    printf "%dd%dh" "$d" "$h"
  else
    printf "%dh%dm" "$h" "$m"
  fi
}

fmt_k() {
  printf "%dk" $(( ($1 + 500) / 1000 ))
}

read_account_email() {
  [ -r "$ACCOUNT_FILE" ] && jq -r '.oauthAccount.emailAddress // empty' "$ACCOUNT_FILE" 2>/dev/null
}

# Prints the padding that right-aligns `right` against LINE_WIDTH; fails if it can't fit with one space.
right_align() {
  local left="$1" right="$2" pad
  pad=$(( LINE_WIDTH - ${#left} - ${#right} ))
  [ "$pad" -lt 1 ] && return 1
  printf "%*s" "$pad" ""
}

# Printed length of a metric part; each bar block is 3 bytes under LC_ALL=C but 1 column wide.
# Strips escapes with plain expansions because macOS bash 3.2 mishandles extglob here.
part_width() {
  local plain="$1" esc=$'\033[' before
  while [[ "$plain" == *"$esc"* ]]; do
    before="${plain%%"$esc"*}"
    plain="${before}${plain#*"$esc"*m}"
  done
  echo $(( ${#plain} - 2 * BAR_WIDTH ))
}

is_positive_int() {
  [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]
}

model_str="$model"
if [ "$thinking" = "true" ] && [ -n "$effort" ]; then
  model_str="${model} (${effort})"
fi
line1="$(printf "${CYAN}%s${RESET}" "$model_str")"

email=$(read_account_email)
lines=()
if [ -n "$email" ]; then
  email_colored="$(printf "${CYAN}%s${RESET}" "$email")"
  if padding=$(right_align "$model_str" "$email"); then
    line1="${line1}${padding}${email_colored}"
  else
    email_pad=$(( LINE_WIDTH - ${#email} ))
    [ "$email_pad" -lt 0 ] && email_pad=0
    lines+=("$(printf "%*s%s" "$email_pad" "" "$email_colored")")
  fi
fi

parts=()

if [ -n "$used_pct" ]; then
  used_rounded=$(printf '%.0f' "$used_pct")
  ctx_color=$(severity_color "$used_pct" "$CTX_THRESHOLDS")
  ctx_bar=$(render_bar "$used_pct" "$ctx_color")
  if is_positive_int "$ctx_size" && is_positive_int "$ctx_tokens"; then
    tok_str="$(fmt_k "$ctx_tokens")/$(fmt_k "$ctx_size")"
    parts+=("$(printf "%bctx:%b %b %b%s%% (%s)%b" "$ctx_color" "$RESET" "$ctx_bar" "$ctx_color" "$used_rounded" "$tok_str" "$RESET")")
  else
    parts+=("$(printf "%bctx:%b %b %b%s%%%b" "$ctx_color" "$RESET" "$ctx_bar" "$ctx_color" "$used_rounded" "$RESET")")
  fi
fi

if [ -n "$five" ]; then
  five_rounded=$(printf '%.0f' "$five")
  five_color=$(severity_color "$five" "$FIVE_HOUR_THRESHOLDS")
  five_bar=$(render_bar "$five" "$five_color")
  five_cd=$(fmt_countdown "$five_reset")
  parts+=("$(printf "%b5h:%b %b %b%s%% %s%b" "$five_color" "$RESET" "$five_bar" "$five_color" "$five_rounded" "$five_cd" "$RESET")")
fi

if [ -n "$week" ]; then
  week_rounded=$(printf '%.0f' "$week")
  week_color=$(severity_color "$week" "$SEVEN_DAY_THRESHOLDS")
  week_bar=$(render_bar "$week" "$week_color")
  week_cd=$(fmt_countdown "$week_reset")
  parts+=("$(printf "%b7d:%b %b %b%s%% %s%b" "$week_color" "$RESET" "$week_bar" "$week_color" "$week_rounded" "$week_cd" "$RESET")")
fi

sep=" $(printf "${DIM}|${RESET}") "
SEP_WIDTH=3

metric_lines=()
current=""
current_width=0
for p in "${parts[@]}"; do
  p_width=$(part_width "$p")
  if [ -z "$current" ]; then
    current="$p"
    current_width="$p_width"
  elif [ $(( current_width + SEP_WIDTH + p_width )) -le "$LINE_WIDTH" ]; then
    current="${current}${sep}${p}"
    current_width=$(( current_width + SEP_WIDTH + p_width ))
  else
    metric_lines+=("$current")
    current="$p"
    current_width="$p_width"
  fi
done
[ -n "$current" ] && metric_lines+=("$current")

# Full blocks fill the whole cell, so bars on stacked lines merge; the 7/8 block leaves a gap at the top.
if [ "${#metric_lines[@]}" -gt 1 ]; then
  for i in "${!metric_lines[@]}"; do
    metric_lines[i]="${metric_lines[i]//█/▇}"
  done
fi
lines+=("${metric_lines[@]}")

printf "%b\n" "$line1" "${lines[@]}"
