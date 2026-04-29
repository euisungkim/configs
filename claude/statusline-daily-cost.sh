#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# ── Extract fields ──────────────────────────────────────────────────
MODEL_ID=$(echo "$input" | jq -r '.model.id // "unknown"')
CWD=$(echo "$input" | jq -r '.workspace.current_dir // ""')
SESSION_COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
CTX_USED_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
INPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
OUTPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

# ── Shorten model name ─────────────────────────────────────────────
# claude-opus-4-6 → opus-4  |  claude-sonnet-4-5-20250929 → sonnet-4.5
model_short="$MODEL_ID"
case "$MODEL_ID" in
    *opus-4*)    model_short="opus-4" ;;
    *sonnet-4-5*) model_short="sonnet-4.5" ;;
    *sonnet-4*)  model_short="sonnet-4" ;;
    *haiku-3-5*) model_short="haiku-3.5" ;;
    *haiku*)     model_short="haiku" ;;
esac

# ── Directory ───────────────────────────────────────────────────────
cd "$CWD" 2>/dev/null || cd "$HOME"
dir="${CWD/#$HOME/~}"
[ ${#dir} -gt 30 ] && dir="…/$(basename "$(dirname "$dir")")/$(basename "$dir")"

# ── Git branch + dirty count (cached to avoid lag) ──────────────────
git_info=""
if git rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        # Cache git status (expensive) — refresh every 5s
        cache_file="/tmp/claude-git-dirty-$$"
        now=$(date +%s)
        if [ -f "$cache_file" ]; then
            cache_age=$(( now - $(stat -f%m "$cache_file" 2>/dev/null || echo 0) ))
        else
            cache_age=999
        fi
        if [ "$cache_age" -ge 5 ]; then
            git status --porcelain 2>/dev/null | wc -l | tr -d ' ' > "$cache_file"
        fi
        dirty_count=$(cat "$cache_file" 2>/dev/null || echo 0)

        if [ "$dirty_count" -gt 0 ]; then
            git_info=" \033[35m${branch}\033[33m ~${dirty_count}\033[0m"
        else
            git_info=" \033[35m${branch}\033[32m ✓\033[0m"
        fi
    fi
fi

# ── Context window bar ──────────────────────────────────────────────
# Use the precomputed used_percentage (more stable)
ctx_pct=$(printf "%.0f" "$CTX_USED_PCT" 2>/dev/null || echo "0")

# Color: green < 50, yellow < 80, red >= 80
if [ "$ctx_pct" -lt 50 ]; then
    ctx_color='\033[32m'
elif [ "$ctx_pct" -lt 80 ]; then
    ctx_color='\033[33m'
else
    ctx_color='\033[31m'
fi

# Mini bar (8 chars)
bar_width=8
filled=$((ctx_pct * bar_width / 100))
[ $filled -gt $bar_width ] && filled=$bar_width
empty=$((bar_width - filled))
bar=""
i=0; while [ $i -lt $filled ]; do bar="${bar}━"; i=$((i+1)); done
i=0; while [ $i -lt $empty ];  do bar="${bar}╌"; i=$((i+1)); done

# Context size in K
ctx_k=$(echo "scale=0; $CTX_SIZE / 1000" | bc 2>/dev/null || echo "200")

# ── Session cost ────────────────────────────────────────────────────
cost_display=$(printf "\$%.2f" "$SESSION_COST" 2>/dev/null || echo "\$0.00")

# ── Lines changed ──────────────────────────────────────────────────
lines_display=""
if [ "$LINES_ADDED" -gt 0 ] || [ "$LINES_REMOVED" -gt 0 ]; then
    lines_display="\033[32m+${LINES_ADDED}\033[0m \033[31m-${LINES_REMOVED}\033[0m"
else
    lines_display="\033[2mno changes\033[0m"
fi

# ── Duration ────────────────────────────────────────────────────────
duration='0s'
ds=$((DURATION_MS / 1000))
if [ $ds -ge 3600 ]; then
    duration="$((ds/3600))h$((ds%3600/60))m"
elif [ $ds -ge 60 ]; then
    duration="$((ds/60))m$((ds%60))s"
elif [ $ds -gt 0 ]; then
    duration="${ds}s"
fi

# ── Token throughput (output tokens / API seconds) ──────────────────
API_DURATION_MS=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')
tps=""
api_s=$((API_DURATION_MS / 1000))
if [ "$api_s" -gt 0 ] && [ "$OUTPUT_TOKENS" -gt 0 ]; then
    tok_per_sec=$(echo "scale=1; $OUTPUT_TOKENS / $api_s" | bc 2>/dev/null || echo "0")
    tps="${tok_per_sec} t/s"
fi

# ── Print ───────────────────────────────────────────────────────────
# 📂 dir branch | 🧠 model | 🪟 context bar | 💰 cost | ✏️ lines | ⚡ tok/s | ⏱️ time
printf "📂 %s%b \033[2m│\033[0m 🧠 \033[36m%s\033[0m \033[2m│\033[0m 🪟 %b%s %d%%\033[0m \033[2m(%dK)\033[0m \033[2m│\033[0m 💰 %s \033[2m│\033[0m ✏️  %b \033[2m│\033[0m ⚡ %s \033[2m│\033[0m ⏱️  %s" \
    "$dir" "$git_info" "$model_short" "$ctx_color" "$bar" "$ctx_pct" "$ctx_k" "$cost_display" "$lines_display" "$tps" "$duration"
