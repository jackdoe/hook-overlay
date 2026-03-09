#!/bin/bash
set -euo pipefail

SOCKET="/tmp/claude-hook.sock"
INPUT=$(cat)

[ ! -S "$SOCKET" ] && exit 0

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
" <<< "$INPUT" 2>/dev/null)

[ -n "$RESPONSE" ] && echo "$RESPONSE"
exit 0
