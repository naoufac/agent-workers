#!/usr/bin/env python3
"""
Simple HTTP Server for GitHub Webhooks
No external dependencies - uses Python 3 built-in http.server
"""

import json
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler
import hmac
import hashlib
import os

WEBHOOK_SECRET = os.getenv('GITHUB_WEBHOOK_SECRET', 'default-secret')
WEBHOOK_PORT = int(os.getenv('WEBHOOK_PORT', '8081'))

class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/webhook':
            # Verify signature
            signature = self.headers.get('X-Hub-Signature-256')
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            if signature:
                sig_hash = hmac.new(
                    WEBHOOK_SECRET.encode(),
                    post_data,
                    hashlib.sha256
                ).hexdigest()
                expected = f'sha256={sig_hash}'
                
                if not hmac.compare_digest(expected, signature):
                    self.send_response(403)
                    self.end_headers()
                    self.wfile.write(b'Invalid signature')
                    return
            
            # Parse event
            event = self.headers.get('X-GitHub-Event', '')
            
            if event == 'pull_request':
                try:
                    data = json.loads(post_data.decode('utf-8'))
                    self.handle_pr_event(data)
                except:
                    pass
            
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'Webhook received')
        
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Log to file"""
        with open('/root/agent-workers/logs/webhook.log', 'a') as f:
            f.write(f"[{format}] {' '.join(str(a) for a in args)}\n")
    
    def handle_pr_event(self, data):
        """Handle pull request events"""
        action = data.get('action', '')
        pr = data.get('pull_request', {})
        pr_number = pr.get('number', 0)
        
        if action in ['opened', 'synchronize']:
            self.log_message(
                f"PR #{pr_number} {action} - triggering review"
            )
            
            # Create task for review
            task_file = f"/root/agent-workers/tasks/review-pr-{pr_number}.json"
            timestamp = subprocess.run(['date', '-Iseconds'], capture_output=True, text=True).stdout.strip()
            
            task_data = {
                "id": f"review-pr-{pr_number}-{timestamp}",
                "type": "github-pr-review",
                "priority": "high",
                "status": "pending",
                "created_at": timestamp,
                "title": f"Review PR #{pr_number}",
                "description": f"Review PR #{pr_number} on GitHub webhook trigger",
                "repo": data.get('repository', {}).get('full_name', ''),
                "pr_number": pr_number,
                "context": {
                    "review_type": "comment",
                    "body": "Automated review triggered by webhook"
                }
            }
            
            with open(task_file, 'w') as f:
                json.dump(task_data, f, indent=2)
            
            self.log_message(f"Created task: {task_file}")

def run_server():
    """Run webhook server"""
    os.makedirs('/root/agent-workers/logs', exist_ok=True)
    
    # Bind to 127.0.0.1 explicitly
    server_address = ('127.0.0.1', WEBHOOK_PORT)
    httpd = HTTPServer(server_address, WebhookHandler)
    
    print(f"Webhook server running on port {WEBHOOK_PORT}")
    print("Log file: /root/agent-workers/logs/webhook.log")
    print("Press Ctrl+C to stop")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server...")
        httpd.server_close()

if __name__ == '__main__':
    run_server()