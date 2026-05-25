#!/bin/bash
# GitHub worker - handles PR lifecycle, reviews, and CI monitoring

set -e

TASK_DIR="/root/agent-workers/tasks"
REPO_BASE="/root/repos"
LOG_DIR="/root/agent-workers/logs"

mkdir -p "$TASK_DIR" "$LOG_DIR"

# Ensure gh auth
ensure_gh_auth() {
    if ! gh auth status &>/dev/null; then
        echo "ERROR: gh CLI not authenticated"
        return 1
    fi
}

find_github_task() {
    find "$TASK_DIR" -name "*.json" -type f | while read -r task; do
        type=$(jq -r '.type // ""' "$task" 2>/dev/null)
        status=$(jq -r '.status // "pending"' "$task" 2>/dev/null)
        if [[ "$type" =~ ^github- ]] && [[ "$status" == "pending" ]]; then
            echo "$task"
            return
        fi
    done
}

execute_github_task() {
    local task_file="$1"
    local task_id=$(basename "$task_file" .json)
    local log_file="$LOG_DIR/${task_id}.log"

    echo "[$(date)] Starting GitHub task: $task_id" >> "$log_file"

    jq '.status = "assigned"' "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"

    local type=$(jq -r '.type' "$task_file")
    local repo=$(jq -r '.repo' "$task_file")
    local branch=$(jq -r '.branch // "main"' "$task_file")
    local title=$(jq -r '.title // "Untitled PR"' "$task_file")

    echo "[$(date)] Task type: $type, repo: $repo" >> "$log_file"

    case "$type" in
        github-pr-create)
            create_pr "$task_file" "$repo" "$branch" "$title" "$log_file"
            ;;
        github-pr-review)
            review_pr "$task_file" "$repo" "$log_file"
            ;;
        github-ci-monitor)
            monitor_ci "$task_file" "$repo" "$log_file"
            ;;
        github-pr-merge)
            merge_pr "$task_file" "$repo" "$log_file"
            ;;
        *)
            echo "[$(date)] Unknown task type: $type" >> "$log_file"
            jq '.status = "failed" | .error = "Unknown task type"' "$task_file" > "${task_file}.tmp"
            mv "${task_file}.tmp" "$task_file"
            return 1
            ;;
    esac
}

create_pr() {
    local task_file="$1"
    local repo="$2"
    local branch="$3"
    local title="$4"
    local log_file="$5"

    cd "$REPO_BASE/$repo" 2>/dev/null || cd "/root/repos/$repo" 2>/dev/null

    local body=$(jq -r '.context.body // ""' "$task_file")
    local draft=$(jq -r '.context.draft // "false"' "$task_file")

    echo "[$(date)] Creating PR: $title" >> "$log_file"

    local pr_cmd="gh pr create --title \"$title\" --body \"$body\""
    if [[ "$draft" == "true" ]]; then
        pr_cmd="$pr_cmd --draft"
    fi

    if $pr_cmd >> "$log_file" 2>&1; then
        local pr_num=$(gh pr list --head "$branch" --json number --jq '.[0].number')
        jq '.status = "completed" | .pr_number = '$pr_num' | .completed_at = "'$(date -Iseconds)'"' "$task_file" > "${task_file}.tmp"
        mv "${task_file}.tmp" "$task_file"
        echo "[$(date)] PR created: #$pr_num" >> "$log_file"
        return 0
    else
        jq '.status = "failed" | .error = "PR creation failed"' "$task_file" > "${task_file}.tmp"
        mv "${task_file}.tmp" "$task_file"
        return 1
    fi
}

review_pr() {
    local task_file="$1"
    local repo="$2"
    local log_file="$3"

    local pr_num=$(jq -r '.pr_number // empty' "$task_file")
    local review_type=$(jq -r '.context.review_type // "comment"' "$task_file")
    local body=$(jq -r '.context.body // ""' "$task_file")

    cd "$REPO_BASE/$repo" 2>/dev/null || cd "/root/repos/$repo" 2>/dev/null

    echo "[$(date)] Reviewing PR #$pr_num" >> "$log_file"

    local review_cmd="gh pr review $pr_num --$review_type --body \"$body\""

    if $review_cmd >> "$log_file" 2>&1; then
        jq '.status = "completed" | .completed_at = "'$(date -Iseconds)'"' "$task_file" > "${task_file}.tmp"
        mv "${task_file}.tmp" "$task_file"
        return 0
    else
        jq '.status = "failed" | .error = "Review failed"' "$task_file" > "${task_file}.tmp"
        mv "${task_file}.tmp" "$task_file"
        return 1
    fi
}

monitor_ci() {
    local task_file="$1"
    local repo="$2"
    local log_file="$3"

    local pr_num=$(jq -r '.pr_number // empty' "$task_file")
    local max_wait=$(jq -r '.context.max_wait_minutes // 30' "$task_file")
    local interval=30
    local attempts=$((max_wait * 60 / interval))

    cd "$REPO_BASE/$repo" 2>/dev/null || cd "/root/repos/$repo" 2>/dev/null

    echo "[$(date)] Monitoring CI for PR #$pr_num (max ${max_wait}m)" >> "$log_file"

    for i in $(seq 1 $attempts); do
        local status=$(gh pr checks $pr_num --json conclusion --jq '.[].conclusion' | grep -v null | head -1)

        if [[ "$status" == "success" ]]; then
            jq '.status = "completed" | .ci_status = "success" | .completed_at = "'$(date -Iseconds)'"' "$task_file" > "${task_file}.tmp"
            mv "${task_file}.tmp" "$task_file"
            echo "[$(date)] CI passed" >> "$log_file"
            return 0
        elif [[ "$status" == "failure" ]]; then
            jq '.status = "failed" | .ci_status = "failure" | .error = "CI checks failed"' "$task_file" > "${task_file}.tmp"
            mv "${task_file}.tmp" "$task_file"
            echo "[$(date)] CI failed" >> "$log_file"
            return 1
        fi

        sleep $interval
    done

    jq '.status = "failed" | .error = "CI timeout"' "$task_file" > "${task_file}.tmp"
    mv "${task_file}.tmp" "$task_file"
    return 1
}

merge_pr() {
    local task_file="$1"
    local repo="$2"
    local log_file="$3"

    local pr_num=$(jq -r '.pr_number // empty' "$task_file")
    local method=$(jq -r '.context.merge_method // "squash"' "$task_file")

    cd "$REPO_BASE/$repo" 2>/dev/null || cd "/root/repos/$repo" 2>/dev/null

    echo "[$(date)] Merging PR #$pr_num with $method" >> "$log_file"

    if gh pr merge $pr_num --$method --delete-branch >> "$log_file" 2>&1; then
        jq '.status = "completed" | .completed_at = "'$(date -Iseconds)'"' "$task_file" > "${task_file}.tmp"
        mv "${task_file}.tmp" "$task_file"
        echo "[$(date)] PR merged" >> "$log_file"
        return 0
    else
        jq '.status = "failed" | .error = "Merge failed"' "$task_file" > "${task_file}.tmp"
        mv "${task_file}.tmp" "$task_file"
        return 1
    fi
}

# Main loop
echo "GitHub Worker started" >> "$LOG_DIR/github-worker.log"

while true; do
    task=$(find_github_task)
    if [[ -n "$task" ]]; then
        ensure_gh_auth && execute_github_task "$task"
    else
        sleep 30
    fi
done
