#!/bin/bash
set -euo pipefail

SOCKET="/tmp/claude-hook.sock"
EVENT_TYPE="${1:-PermissionRequest}"
INPUT=$(cat)

[ ! -S "$SOCKET" ] && exit 0

# Inject event type into JSON
ENRICHED=$(python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
data['hook_event_type'] = '$EVENT_TYPE'
print(json.dumps(data))
" <<< "$INPUT" 2>/dev/null) || exit 0

if [ "$EVENT_TYPE" = "PermissionRequest" ]; then
    # Send and wait for response
    RESPONSE=$(python3 -c "
import socket, sys

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
try:
    sock.connect('$SOCKET')
    sock.settimeout(300)
except (ConnectionRefusedError, FileNotFoundError):
    sys.exit(0)

sock.sendall(sys.stdin.buffer.read())
sock.shutdown(socket.SHUT_WR)

response = b''
while True:
    chunk = sock.recv(4096)
    if not chunk:
        break
    response += chunk

sock.close()
sys.stdout.buffer.write(response)
" <<< "$ENRICHED" 2>/dev/null)

    [ -n "$RESPONSE" ] && echo "$RESPONSE"
else
    # Fire and forget for Notification/Stop
    python3 -c "
import socket, sys

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
try:
    sock.connect('$SOCKET')
except (ConnectionRefusedError, FileNotFoundError):
    sys.exit(0)

sock.sendall(sys.stdin.buffer.read())
sock.shutdown(socket.SHUT_WR)
sock.close()
" <<< "$ENRICHED" 2>/dev/null
fi

exit 0
