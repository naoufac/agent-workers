#!/usr/bin/env python3
"""
GitHub Webhook Receiver Server
Receives PR push events and dispatches to Hermes agents for code review
"""

import hmac
import hashlib
import json
from flask import Flask, request, jsonify

app = Flask(__name__)

# GitHub webhook secret (should be in environment)
WEBHOOK_SECRET = 'your-webhook-secret-here'

def verify_signature(payload, signature):
    """Verify GitHub webhook signature"""
    if not signature:
        return False
    
    sig_hash = hmac.new(
        WEBHOOK_SECRET.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    
    expected = f'sha256={sig_hash}'
    return hmac.compare_digest(expected, signature)

@app.route('/webhook', methods=['POST'])
def handle_webhook():
    """Handle GitHub webhook events"""
    
    # Verify signature
    signature = request.headers.get('X-Hub-Signature-256')
    payload = request.data
    
    if not verify_signature(payload, signature):
        return jsonify({'error': 'Invalid signature'}), 403
    
    # Parse event
    event = request.headers.get('X-GitHub-Event')
    data = json.loads(payload)
    
    if event == 'pull_request':
        handle_pr_event(data)
    
    return jsonify({'status': 'received'}), 200

def handle_pr_event(data):
    """Handle pull request events"""
    action = data['action']
    pr = data['pull_request']
    
    if action in ['opened', 'synchronize']:
        # Trigger code review
        print(f"PR #{pr['number']} {action} - triggering review")
        
        # TODO: Dispatch to Hermes agent
        # Create review task in agent-workers/tasks/

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)