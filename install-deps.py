#!/usr/bin/env python3
"""Install Flask for webhook server"""

import subprocess
import sys

try:
    print("Installing Flask and Gunicorn...")
    result = subprocess.run([
        sys.executable, '-m', 'pip', 'install',
        'flask==3.0.0', 'gunicorn==21.2.0'
    ], capture_output=True, text=True, timeout=300)
    
    if result.returncode == 0:
        print("✅ Installation successful")
        
        # Test import
        try:
            import flask
            print("✅ Flask import OK")
        except ImportError as e:
            print(f"❌ Flask import failed: {e}")
            sys.exit(1)
    else:
        print(f"❌ Installation failed:\n{result.stderr}")
        sys.exit(1)
        
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)