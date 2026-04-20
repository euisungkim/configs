#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values from JSON
MODEL_ID=$(echo "$input" | jq -r '.model.id')
CWD=$(echo "$input" | jq -r '.workspace.current_dir')
SESSION_ID=$(echo "$input" | jq -r '.session_id')
TRANSCRIPT=$(echo "$input" | jq -r '.transcript_path')
INPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
OUTPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
USED=$((INPUT_TOKENS + OUTPUT_TOKENS))
MAX=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
SESSION_COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

# Change to working directory
cd "$CWD" 2>/dev/null || cd "$HOME"

# Format directory path
dir="${CWD/#$HOME/~}"
[ ${#dir} -gt 30 ] && dir="…/$(basename "$(dirname "$dir")")/$(basename "$dir")"

# Git branch (simple)
git_branch=""
if git rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    [ -n "$branch" ] && git_branch=" ◰ $branch"
fi

# Format token usage in K format
used_k=$(echo "scale=1; $USED / 1000" | bc 2>/dev/null || echo "0.0")
max_k=$(echo "scale=1; $MAX / 1000" | bc 2>/dev/null || echo "200.0")
pct=$(echo "scale=0; ($USED * 100) / $MAX" | bc 2>/dev/null || echo "0")

# Color based on usage percentage
if [ "$pct" -lt 70 ]; then
    token_color='\033[32m'
elif [ "$pct" -lt 90 ]; then
    token_color='\033[33m'
else
    token_color='\033[31m'
fi

# Calculate session duration with · separator
duration='0s'
duration_seconds=$((DURATION_MS / 1000))
if [ $duration_seconds -ge 3600 ]; then
    duration="$((duration_seconds/3600))h·$((duration_seconds%3600/60))m"
elif [ $duration_seconds -ge 60 ]; then
    duration="$((duration_seconds/60))m·$((duration_seconds%60))s"
elif [ $duration_seconds -gt 0 ]; then
    duration="${duration_seconds}s"
fi

# Daily cost tracking aligned with LiteLLM budget reset at 11 PM UTC (23:00 UTC)
# Get current UTC time
UTC_HOUR=$(date -u +%H)
UTC_DATE=$(date -u +%Y-%m-%d)

# Calculate budget period: if before 23:00 UTC, use current UTC date
# If at or after 23:00 UTC, use next UTC date
if [ "$UTC_HOUR" -ge 23 ]; then
    # After 11 PM UTC, we're in the next budget period
    BUDGET_PERIOD=$(date -u -v+1d +%Y-%m-%d 2>/dev/null || date -u -d "tomorrow" +%Y-%m-%d 2>/dev/null)
else
    # Before 11 PM UTC, we're in the current budget period
    BUDGET_PERIOD="$UTC_DATE"
fi

COST_CACHE="/tmp/claude-cost-${BUDGET_PERIOD}"

if [ -f "$COST_CACHE" ]; then
    grep -v "^${SESSION_ID}|" "$COST_CACHE" > "${COST_CACHE}.tmp" 2>/dev/null || touch "${COST_CACHE}.tmp"
    mv "${COST_CACHE}.tmp" "$COST_CACHE"
fi

echo "${SESSION_ID}|${SESSION_COST}" >> "$COST_CACHE"

total_cost=0
if [ -f "$COST_CACHE" ]; then
    while IFS='|' read -r sid cost; do
        if [ -n "$cost" ] && [ "$cost" != "0" ]; then
            total_cost=$(echo "scale=4; $total_cost + $cost" | bc 2>/dev/null || echo "$total_cost")
        fi
    done < "$COST_CACHE"
fi

# Format session cost for 💸 section (current session only)
session_cost_display=$(printf "\$%.2f" "$SESSION_COST" 2>/dev/null || echo "\$0.00")

# Daily budget with progress bar
daily_budget=50
daily_pct=$(echo "scale=0; ($total_cost * 100) / $daily_budget" | bc 2>/dev/null || echo "0")
daily_display=$(printf "\$%.2f/\$%d" "$total_cost" "$daily_budget" 2>/dev/null || echo "\$0.00/\$50")

# Small progress bar (6 blocks)
bar_width=6
filled=$((daily_pct*bar_width/100))
[ $filled -gt $bar_width ] && filled=$bar_width
empty=$((bar_width-filled))

bar=""
i=0
while [ $i -lt $filled ]; do
    bar="${bar}█"
    i=$((i+1))
done
i=0
while [ $i -lt $empty ]; do
    bar="${bar}░"
    i=$((i+1))
done

# Hourly rate
hourly_rate=0
if [ $duration_seconds -gt 0 ]; then
    hours=$(echo "scale=4; $duration_seconds / 3600" | bc 2>/dev/null || echo "1")
    hourly_rate=$(echo "scale=2; $SESSION_COST / $hours" | bc 2>/dev/null || echo "0.00")
fi
hourly_display=$(printf "\$%.2f/hr" "$hourly_rate" 2>/dev/null || echo "\$0.00/hr")

# Message stats (count messages and total tokens)
msg_count=$(echo "$input" | jq -r '.message_count // 0')
total_tokens=$((INPUT_TOKENS + OUTPUT_TOKENS))

# Format total tokens in M format
if [ $total_tokens -ge 1000000 ]; then
    total_m=$(echo "scale=1; $total_tokens / 1000000" | bc 2>/dev/null || echo "0.0")
    tokens_display="${total_m}M"
else
    total_k=$(echo "scale=1; $total_tokens / 1000" | bc 2>/dev/null || echo "0.0")
    tokens_display="${total_k}K"
fi

# Print single-line status
printf "\033[2m📁\033[0m %s%s \033[2m|\033[0m \033[36m🤖 %s\033[0m \033[2m|\033[0m %b☁️  %.1fK / %.1fK (%d%%)\033[0m \033[2m|\033[0m 💸 %s \033[2m|\033[0m 💰 %s \033[32m%s\033[0m %d%% \033[2m|\033[0m ⚡ %s \033[2m|\033[0m 📊 %d → %s \033[2m|\033[0m ⏱  %s" \
    "$dir" "$git_branch" "$MODEL_ID" "$token_color" "$used_k" "$max_k" "$pct" "$session_cost_display" "$daily_display" "$bar" "$daily_pct" "$hourly_display" "$msg_count" "$tokens_display" "$duration"
