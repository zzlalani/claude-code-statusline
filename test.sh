#!/bin/bash
# Run: bash test.sh
cd "$(dirname "$0")" || exit 1

failures=0
now=$(date +%s)

render() {
  echo "$1" | STATUSLINE_WIDTH=200 bash ./statusline-command.sh 2>&1 | sed $'s/\033\\[[0-9;]*m//g'
}

assert_contains() {
  local name="$1" output="$2" expected="$3"
  if [[ "$output" == *"$expected"* ]]; then
    echo "PASS $name"
  else
    echo "FAIL $name: expected '$expected' in:"
    echo "$output"
    failures=$((failures + 1))
  fi
}

assert_equals() {
  local name="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    echo "PASS $name"
  else
    echo "FAIL $name: expected '$expected' got '$actual'"
    failures=$((failures + 1))
  fi
}

assert_not_contains() {
  local name="$1" output="$2" unexpected="$3"
  if [[ "$output" != *"$unexpected"* ]]; then
    echo "PASS $name"
  else
    echo "FAIL $name: did not expect '$unexpected' in:"
    echo "$output"
    failures=$((failures + 1))
  fi
}

render_raw() {
  echo "$1" | bash ./statusline-command.sh 2>&1
}

assert_label_color() {
  local name="$1" json="$2" label="$3" code="$4" out
  out=$(render_raw "$json")
  if [[ "$out" == *$'\033[38;5;'"$code"'m'"$label"* ]]; then
    echo "PASS $name"
  else
    echo "FAIL $name: expected color $code before '$label'"
    failures=$((failures + 1))
  fi
}

ctx_json() { echo '{"context_window":{"used_percentage":'"$1"'}}'; }
rate_json() { echo '{"rate_limits":{"five_hour":{"used_percentage":'"$1"'},"seven_day":{"used_percentage":'"$2"'}}}'; }

full='{"model":{"display_name":"Opus"},"effort":{"level":"high"},"thinking":{"enabled":true},
"context_window":{"used_percentage":12.4,"total_input_tokens":450000,"total_output_tokens":5000,"context_window_size":1000000,
"current_usage":{"input_tokens":1000,"cache_creation_input_tokens":2000,"cache_read_input_tokens":120000,"output_tokens":500}},
"rate_limits":{"five_hour":{"used_percentage":45.2,"resets_at":'"$((now + 15500))"'},"seven_day":{"used_percentage":80,"resets_at":'"$((now + 200000))"'}}}'

out=$(render "$full")
assert_contains "model with effort" "$out" "Opus (high)"
assert_contains "ctx tokens use current usage, not session totals" "$out" "12% (123k/1000k)"
assert_contains "5h countdown" "$out" "5h: ████████ 45% 4h18m"
assert_contains "7d countdown" "$out" "7d: ████████ 80% 2d7h"

out=$(render '{"context_window":{"used_percentage":5}}')
assert_not_contains "missing model never prints null" "$out" "null"
assert_contains "ctx without size or usage omits tokens" "$out" "ctx: ████████ 5%"
assert_not_contains "ctx without size omits tokens" "$out" "("

out=$(render '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":5,"context_window_size":"abc"}}')
assert_not_contains "non-integer ctx size does not error" "$out" "integer expression"

out=$(LC_ALL=de_DE.UTF-8 render "$full")
assert_contains "locale-independent rounding" "$out" "12%"

assert_label_color "ctx 29 green" "$(ctx_json 29)" "ctx:" 42
assert_label_color "ctx 30 blue" "$(ctx_json 30)" "ctx:" 39
assert_label_color "ctx 50 orange" "$(ctx_json 50)" "ctx:" 208
assert_label_color "ctx 70 red" "$(ctx_json 70)" "ctx:" 196
assert_label_color "ctx 90 blood" "$(ctx_json 90)" "ctx:" 124

assert_label_color "5h 49 green" "$(rate_json 49 0)" "5h:" 42
assert_label_color "5h 50 blue" "$(rate_json 50 0)" "5h:" 39
assert_label_color "5h 70 orange" "$(rate_json 70 0)" "5h:" 208
assert_label_color "5h 90 red" "$(rate_json 90 0)" "5h:" 196
assert_label_color "5h 100 blood" "$(rate_json 100 0)" "5h:" 124

assert_label_color "7d 79 green" "$(rate_json 0 79)" "7d:" 42
assert_label_color "7d 80 blue" "$(rate_json 0 80)" "7d:" 39
assert_label_color "7d 90 orange" "$(rate_json 0 90)" "7d:" 208
assert_label_color "7d 95 red" "$(rate_json 0 95)" "7d:" 196
assert_label_color "7d 100 blood" "$(rate_json 0 100)" "7d:" 124

account_file=$(mktemp)
echo '{"oauthAccount":{"emailAddress":"a@b.com"}}' > "$account_file"
model_json='{"model":{"display_name":"Opus"}}'

out=$(echo "$model_json" | STATUSLINE_CLAUDE_JSON="$account_file" STATUSLINE_WIDTH=40 bash ./statusline-command.sh | sed $'s/\033\\[[0-9;]*m//g' | head -1)
assert_contains "email right-aligned" "$out" "Opus"
assert_contains "email shown" "$out" "a@b.com"
if [ "${#out}" -eq 40 ]; then echo "PASS line padded to width"; else echo "FAIL line padded to width: ${#out} != 40"; failures=$((failures + 1)); fi

strip_ansi() { sed $'s/\033\\[[0-9;]*m//g'; }

out=$(echo "$model_json" | STATUSLINE_CLAUDE_JSON="$account_file" STATUSLINE_WIDTH=10 bash ./statusline-command.sh | strip_ansi)
assert_equals "email wraps to its own right-aligned line when it does not fit" "$out" "Opus
   a@b.com"

out=$(echo "$full" | STATUSLINE_CLAUDE_JSON=/nonexistent STATUSLINE_WIDTH=50 bash ./statusline-command.sh | strip_ansi)
assert_equals "metrics wrap greedily across lines" "$(echo "$out" | wc -l | tr -d ' ')" "3"
assert_not_contains "first metrics line holds only ctx" "$(echo "$out" | sed -n 2p)" "5h:"
assert_contains "second metrics line packs 5h and 7d" "$(echo "$out" | sed -n 3p)" "5h: ▇▇▇▇▇▇▇▇ 45% 4h18m | 7d: ▇▇▇▇▇▇▇▇ 80% 2d7h"
assert_not_contains "wrapped bars leave a gap between stacked lines" "$out" "█"

out=$(echo "$full" | STATUSLINE_CLAUDE_JSON=/nonexistent STATUSLINE_WIDTH=100 bash ./statusline-command.sh | strip_ansi)
assert_equals "wide terminal keeps metrics on one line" "$(echo "$out" | wc -l | tr -d ' ')" "2"
assert_contains "single metrics line keeps full-height bars" "$out" "ctx: ████████"

out=$(echo "$model_json" | STATUSLINE_CLAUDE_JSON="$account_file" STATUSLINE_WIDTH=12 bash ./statusline-command.sh | sed $'s/\033\\[[0-9;]*m//g' | head -1)
if [ "$out" = "Opus a@b.com" ]; then echo "PASS email kept with one space when it just fits"; else echo "FAIL email kept when it just fits: '$out'"; failures=$((failures + 1)); fi

out=$(echo "$model_json" | STATUSLINE_CLAUDE_JSON="$account_file" COLUMNS=77 bash ./statusline-command.sh | sed $'s/\033\\[[0-9;]*m//g' | head -1)
if [ "${#out}" -eq 60 ]; then echo "PASS width follows COLUMNS minus margin"; else echo "FAIL width follows COLUMNS: ${#out} != 60"; failures=$((failures + 1)); fi

out=$(echo "$model_json" | STATUSLINE_CLAUDE_JSON="$account_file" COLUMNS=77 STATUSLINE_WIDTH=30 bash ./statusline-command.sh | sed $'s/\033\\[[0-9;]*m//g' | head -1)
if [ "${#out}" -eq 30 ]; then echo "PASS STATUSLINE_WIDTH overrides COLUMNS"; else echo "FAIL STATUSLINE_WIDTH override: ${#out} != 30"; failures=$((failures + 1)); fi

out=$(echo "$model_json" | STATUSLINE_CLAUDE_JSON=/nonexistent bash ./statusline-command.sh | sed $'s/\033\\[[0-9;]*m//g' | head -1)
if [ "$out" = "Opus" ]; then echo "PASS missing account file shows model only"; else echo "FAIL missing account file: '$out'"; failures=$((failures + 1)); fi
rm -f "$account_file"

sync_dir=$(mktemp -d)
echo "old" > "$sync_dir/statusline-command.sh"
STATUSLINE_TARGET="$sync_dir/statusline-command.sh" STATUSLINE_SKIP_TESTS=1 bash ./sync.sh >/dev/null
if cmp -s statusline-command.sh "$sync_dir/statusline-command.sh"; then echo "PASS sync copies script to target"; else echo "FAIL sync copies script to target"; failures=$((failures + 1)); fi
if [ "$(cat "$sync_dir/statusline-command.sh.bak")" = "old" ]; then echo "PASS sync backs up previous target"; else echo "FAIL sync backs up previous target"; failures=$((failures + 1)); fi
rm -rf "$sync_dir"

run_install() {
  STATUSLINE_INSTALL_DIR="$1" STATUSLINE_SOURCE="$PWD/statusline-command.sh" bash ./install.sh 2>&1
}

install_dir=$(mktemp -d)
echo '{"theme":"dark","statusLine":null}' | jq 'del(.statusLine)' > "$install_dir/settings.json"
run_install "$install_dir" >/dev/null
assert_equals "install copies script" "$(cmp -s statusline-command.sh "$install_dir/statusline-command.sh" && echo yes)" "yes"
assert_equals "install sets statusLine command" "$(jq -r '.statusLine.command' "$install_dir/settings.json")" "bash $install_dir/statusline-command.sh"
assert_equals "install keeps other settings" "$(jq -r '.theme' "$install_dir/settings.json")" "dark"
assert_equals "install backs up settings" "$(jq -r '.theme' "$install_dir/settings.json.bak")" "dark"
out=$(run_install "$install_dir")
assert_contains "install is idempotent" "$out" "already installed"
rm -rf "$install_dir"

install_dir=$(mktemp -d)
run_install "$install_dir" >/dev/null
assert_equals "install creates settings when missing" "$(jq -r '.statusLine.type' "$install_dir/settings.json")" "command"
rm -rf "$install_dir"

install_dir=$(mktemp -d)
echo '{"statusLine":{"type":"command","command":"my-other-line"}}' > "$install_dir/settings.json"
out=$(run_install "$install_dir")
assert_contains "install refuses to replace another status line" "$out" "another status line"
assert_equals "other status line untouched" "$(jq -r '.statusLine.command' "$install_dir/settings.json")" "my-other-line"
out=$(STATUSLINE_FORCE=1 run_install "$install_dir")
assert_equals "force replaces another status line" "$(jq -r '.statusLine.command' "$install_dir/settings.json")" "bash $install_dir/statusline-command.sh"
rm -rf "$install_dir"

[ "$failures" -eq 0 ] && echo "all passed" || { echo "$failures failed"; exit 1; }
