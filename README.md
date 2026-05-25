# Agent Workers - Task Management System

Repository: `/root/agent-workers`

## Overview
Autonomous task execution system combining Claude Code CLI and GitHub workers.

## Quick Start

```bash
# Start both workers (backgrounded)
cd /root/agent-workers
./scripts/start-workers.sh

# Quick assign - run a task immediately
./scripts/quick-assign.sh /path/to/repo "Add error handling to API calls"

# Dispatch - create managed tasks
./scripts/dispatch.sh code "Fix login bug" "Fix the redirect after login" "example/webapp"
./scripts/dispatch.sh list
```

## Workers

### Claude Worker (`scripts/claude-worker.sh`)
- Polls `tasks/` directory for pending `claude-code` tasks
- Executes with: `claude -p "task" --max-turns 15`
- Auto-updates task status: pending → assigned → completed/failed
- Logs to `logs/<task-id>.log`

### GitHub Worker (`scripts/github-worker.sh`)
- Handles `github-pr-*` and `github-*` tasks
- Operations: create PR, review PR, monitor CI, merge PR
- Uses `gh` CLI (requires auth)
- Logs to `logs/<task-id>.log`

## Task Types

### Claude Code Task
```json
{
  "type": "claude-code",
  "title": "Refactor auth module",
  "description": "Detailed task for Claude",
  "repo": "owner/repo",
  "context": {
    "allowedTools": "Read,Edit,Write,Bash"
  }
}
```

### GitHub PR Create Task
```json
{
  "type": "github-pr-create",
  "title": "Create feature PR",
  "repo": "owner/repo",
  "branch": "feature-branch",
  "context": {
    "body": "PR description",
    "draft": false
  }
}
```

### GitHub Review Task
```json
{
  "type": "github-pr-review",
  "repo": "owner/repo",
  "pr_number": 123,
  "context": {
    "review_type": "approve|request-changes|comment",
    "body": "Review comments"
  }
}
```

## Claude CLI Config (`.claude/settings.json`)
- Auto-format on write: ruff for Python, eslint for TypeScript
- Allowed tools: Read, Edit, Write, npm/make/git/python/pip commands
- Ask before git push/commit
- Deny: rm -rf *, reading .env or secrets/*

## Dispatcher Commands

```bash
# Create code task
./scripts/dispatch.sh code "Title" "Description" "repo"

# Create PR task
./scripts/dispatch.sh pr "Title" "Body" "repo" "branch"

# Create review task
./scripts/dispatch.sh review 123 "repo" "approve" "LGTM"

# List all tasks
./scripts/dispatch.sh list
```

## Workflow Examples

### Single Task (Immediate)
```bash
./scripts/quick-assign.sh /root/repos/myapp "Add unit tests for auth.py"
```

### Multi-Step (Managed)
```bash
# 1. Create code task
TASK_ID=$(./scripts/dispatch.sh code "Add feature" "Implement X" "myapp")

# 2. Wait for completion, then create PR
# (Monitor logs: tail -f logs/$TASK_ID.log)

# 3. Create PR task
./scripts/dispatch.sh pr "Feature X" "Description" "myapp" "feature-x"
```

### CI-Driven Merge
```bash
# Create review task
./scripts/dispatch.sh review 45 "myapp" "approve" "Ready to merge"

# Create CI monitor task (wait up to 30m)
# Then auto-merge when green
```

## Logs

- Claude worker: `logs/worker.log`
- GitHub worker: `logs/github-worker.log`
- Task execution: `logs/<task-id>.log`

## Claude CLI Project Context

The `CLAUDE.md` file provides project-specific context to Claude:
- Architecture notes
- Key commands
- Code standards

Claude auto-loads this file when working in this directory.

## Cron Integration

For automated task dispatch:
```bash
# Every 2 minutes, check for new tasks in external queue
*/2 * * * * /root/agent-workers/scripts/dispatch.sh sync-external
```
