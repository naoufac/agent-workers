## Agent Workers - Production Infrastructure

Autonomous task processing system for GitHub PR workflows and social media production automation.

## What It Does

**GitHub PR System**
- Webhook server (port 8081) receives GitHub pull request events
- Automatically creates review tasks when PRs opened/updated
- GitHub worker processes tasks using `gh` CLI
- Creates PRs, posts review comments, monitors CI

**Social Media Production**
- Daily task queue creates content for Telegram, Discord, X
- GitHub worker publishes content to each platform
- Centralized content directory: `/root/social-content/`

## Components

### Webhook Server
- `simple-webhook.py` — Python3 HTTP server (no Flask dependency)
- Receives GitHub webhook events
- Validates HMAC signatures
- Creates review tasks in `/root/agent-workers/tasks/`

### GitHub Worker
- `github-worker-simple.sh` — Processes GitHub tasks
- Creates PRs using `gh pr create`
- Posts review comments using `gh pr review`
- Monitors CI status using `gh pr checks`

### Task Queue
- JSON task files in `/root/agent-workers/tasks/`
- Status: pending → assigned → completed/failed
- Types: github-pr-create, github-pr-review, github-pr-merge, social-content-create

### Social Production
- `social-production.sh` — Creates daily content tasks
- Platforms: Telegram, Discord, X, Instagram
- Content directory: `/root/social-content/`

## Startup

Automatically runs on Hermes startup via `/root/.hermes/profiles/default/startup.sh`

- Webhook server: `http://135.181.44.161:8081/webhook`
- GitHub worker: Monitors `/root/agent-workers/tasks/`
- Cron job: `*/5 * * * *` — Every 5 minutes

## GitHub Repo

https://github.com/naoufac/agent-workers

## Usage

```bash
# Start infrastructure
bash /root/.hermes/profiles/default/startup.sh

# Create social media content
bash /root/agent-workers/social-production.sh

# Create PR task
/root/agent-workers/scripts/dispatch.sh pr "Fix bug" "Description" "naoufac/repo"

# List tasks
/root/agent-workers/scripts/dispatch.sh list
```

## Logs

- `/root/agent-workers/logs/webhook.log` — Webhook server
- `/root/agent-workers/logs/github-worker-simple.log` — GitHub worker
- `/root/agent-workers/logs/webhook-startup.log` — Startup script