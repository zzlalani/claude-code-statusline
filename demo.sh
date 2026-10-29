#!/bin/bash
# Prints sample status lines in every colour tier, for screenshots. Usage: bash demo.sh
cd "$(dirname "$0")" || exit 1

account_file=$(mktemp)
trap 'rm -f "$account_file"' EXIT
echo '{"oauthAccount":{"emailAddress":"user@example.com"}}' > "$account_file"
now=$(date +%s)
rule="$(printf '─%.0s' $(seq 1 100))"

scenario() {
  local title="$1" model="$2" ctx="$3" five="$4" week="$5" width="${6:-100}"
  printf '\n\033[2m%s\033[0m\n\033[1m%s\033[0m\n' "$rule" "$title"
  jq -n --arg model "$model" --argjson ctx "$ctx" --argjson five "$five" --argjson week "$week" --argjson now "$now" '{
    model: {display_name: $model}, effort: {level: "high"}, thinking: {enabled: true},
    context_window: {used_percentage: $ctx, context_window_size: 1000000,
      current_usage: {input_tokens: ($ctx * 10000 | floor)}},
    rate_limits: {five_hour: {used_percentage: $five, resets_at: ($now + 15500)},
                  seven_day: {used_percentage: $week, resets_at: ($now + 200000)}}}' |
    STATUSLINE_CLAUDE_JSON="$account_file" STATUSLINE_WIDTH="$width" bash ./statusline-command.sh
  printf '\033[2m%s\033[0m\n' "$rule"
}

scenario "Fresh session (all green)"            "Opus" 8  12 20
scenario "Getting busy (blue)"                  "Opus" 35 55 82
scenario "Warming up (orange)"                  "Opus" 55 75 91
scenario "Running hot (red)"                    "Opus" 75 92 96
scenario "Limits hit (blood red)"               "Opus" 95 100 100
scenario "Mixed tiers (real-world)"             "Sonnet" 62 48 85
scenario "Narrow terminal (wraps onto lines)"   "Opus" 55 75 91 48
echo
