#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="HookOverlay"
APP_PATH="$HOME/Applications/$APP_NAME.app/Contents/MacOS/$APP_NAME"
HOOK_SCRIPT="$SCRIPT_DIR/hooks/permission-overlay.sh"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT="$LAUNCH_AGENT_DIR/com.claude.hook-overlay.plist"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

echo "==> Installing HookOverlay..."

# 1. Check that the app exists
if [ ! -f "$APP_PATH" ]; then
    echo "❌ App not found at $APP_PATH"
    echo "   Run ./build.sh first."
    exit 1
fi

# 2. Make hook script executable
chmod +x "$HOOK_SCRIPT"
echo "    ✓ Hook script: $HOOK_SCRIPT"

# 3. Install LaunchAgent for auto-start
mkdir -p "$LAUNCH_AGENT_DIR"

# Unload existing agent if present
if [ -f "$LAUNCH_AGENT" ]; then
    launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true
fi

# Generate plist with correct path
sed "s|__APP_PATH__|$APP_PATH|g" "$SCRIPT_DIR/com.claude.hook-overlay.plist" > "$LAUNCH_AGENT"
launchctl load "$LAUNCH_AGENT"
echo "    ✓ LaunchAgent installed and loaded"

# 4. Add hook to Claude Code settings
mkdir -p "$HOME/.claude"

# Create settings file if it doesn't exist
if [ ! -f "$CLAUDE_SETTINGS" ]; then
    echo '{}' > "$CLAUDE_SETTINGS"
fi

# Use python to safely merge the hook config into existing settings
python3 -c "
import json, sys

settings_path = '$CLAUDE_SETTINGS'
hook_command = '$HOOK_SCRIPT'

with open(settings_path) as f:
    settings = json.load(f)

# Ensure hooks.PermissionRequest exists
hooks = settings.setdefault('hooks', {})
perm_hooks = hooks.setdefault('PermissionRequest', [])

# Check if our hook is already there
already_installed = False
for group in perm_hooks:
    for h in group.get('hooks', []):
        if h.get('command', '') == hook_command:
            already_installed = True
            break

if not already_installed:
    perm_hooks.append({
        'hooks': [{
            'type': 'command',
            'command': hook_command
        }]
    })
    with open(settings_path, 'w') as f:
        json.dump(settings, f, indent=2)
    print('    ✓ Hook added to', settings_path)
else:
    print('    ✓ Hook already in', settings_path)
"

echo ""
echo "✅ Installation complete!"
echo ""
echo "The overlay app will:"
echo "  • Start automatically at login"
echo "  • Show a floating panel when any Claude Code session needs permission"
echo "  • Respond to ⌃1 (Allow), ⌃2 (Deny), ⌃3 (Always Allow) globally"
echo ""
echo "Make sure to grant Accessibility permission:"
echo "  System Settings → Privacy & Security → Accessibility → HookOverlay"
echo ""
echo "To uninstall:"
echo "  launchctl unload '$LAUNCH_AGENT'"
echo "  rm '$LAUNCH_AGENT'"
echo "  rm -rf '$HOME/Applications/$APP_NAME.app'"
echo "  # Remove the PermissionRequest hook from $CLAUDE_SETTINGS"
