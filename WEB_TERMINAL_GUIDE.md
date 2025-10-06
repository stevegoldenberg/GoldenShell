# GoldenShell Web Terminal Guide

## Overview

GoldenShell now provides web-based terminal access, enabling you to access your development environment from **any device with a browser** - including iPhones, iPads, and other mobile devices. This is powered by:

- **ttyd**: Web-based terminal server
- **Zellij**: Modern terminal multiplexer for managing multiple sessions and tabs
- **Claude Code CLI**: AI-powered coding assistant accessible from anywhere

## Quick Access

### Web Terminal URL
```
http://YOUR_INSTANCE_IP:7681
```

**Current Instance IP:** `23.20.136.32`
**Current Web Terminal URL:** http://23.20.136.32:7681

### Login Credentials
- **Username:** `ubuntu`
- **Password:** `GoldenShell2025!`

## Key Features

### 1. Browser-Based Access
- No SSH client required
- Works on mobile devices (iPhone, iPad, Android)
- Works on any desktop browser
- No software installation needed

### 2. Multiple Sessions with Zellij
- Run multiple Claude Code instances simultaneously
- Create multiple tabs for different projects
- Split panes within tabs for side-by-side work
- Sessions persist - disconnect and reconnect anytime

### 3. Session Persistence
- Your Zellij session stays alive when you disconnect
- Reconnect from a different device and continue where you left off
- All your tabs, panes, and running processes remain active

## Using Zellij Terminal Multiplexer

### Keyboard Shortcuts

#### Tab Management
- **Create new tab:** `Ctrl + t`
- **Close current tab:** `Ctrl + w`
- **Switch between tabs:**
  - `Alt + 1` - Switch to tab 1
  - `Alt + 2` - Switch to tab 2
  - `Alt + 3` - Switch to tab 3
  - `Alt + 4` - Switch to tab 4
  - `Alt + 5` - Switch to tab 5

#### Pane Management
- **Create new pane:** `Ctrl + n`
- **Navigate between panes:** `Ctrl + h/j/k/l` (vim-style) or arrow keys

#### Other Commands
- **Copy mode:** Select text with mouse (copy-on-select is enabled)
- **Detach from session:** Close browser tab (session continues running)
- **Reattach to session:** Open web terminal URL again

### Zellij CLI Commands
When you first connect, Zellij automatically attaches to a session named "default". You can also manage sessions manually:

```bash
# List all sessions
zellij list-sessions

# Attach to specific session
zellij attach session-name

# Create new named session
zellij --session my-project

# Kill a session
zellij kill-session session-name
```

## Running Multiple Claude Code Sessions

### Example Workflow

1. **Open Web Terminal** in your browser
2. **Create first tab** (Ctrl + t) for Project A:
   ```bash
   cd ~/project-a
   claude
   ```
3. **Create second tab** (Ctrl + t) for Project B:
   ```bash
   cd ~/project-b
   claude
   ```
4. **Create third tab** (Ctrl + t) for general terminal work:
   ```bash
   # Run git commands, file operations, etc.
   ```
5. **Switch between tabs** using `Alt + 1`, `Alt + 2`, `Alt + 3`

Each tab maintains its own independent Claude Code session!

## Mobile Device Tips

### iPhone/iPad Optimization

#### Browser Choice
- **Safari**: Works well, use in full-screen mode
- **Chrome**: Good alternative with sync across devices

#### Full Screen Mode
1. Open the web terminal URL in Safari
2. Tap the Share button
3. Select "Add to Home Screen"
4. Open from home screen for app-like experience

#### Keyboard Tips
- External keyboard highly recommended for extended use
- On-screen keyboard works but is less efficient
- Use a Bluetooth keyboard for best experience

#### Display Orientation
- Landscape mode provides more screen space
- Portrait mode works for quick checks

### Touch Screen Considerations
- Text selection works with touch
- Copy/paste works using native iOS/Android gestures
- Pinch-to-zoom if text is too small

## Advanced Features

### Running Background Processes

Since Zellij sessions persist, you can run long-running processes:

1. Start a process in a tab
2. Create a new tab for other work
3. Close browser - process continues running
4. Reopen browser - check on progress

Example:
```bash
# Tab 1: Run tests
npm test

# Switch to Tab 2 (Ctrl + t)
# Do other work...

# Return to Tab 1 (Alt + 1) to see test results
```

### Multiple Panes in One Tab

Split your view for side-by-side work:

```bash
# Create a pane (Ctrl + n)
# Now you have two shells side by side

# Left pane: Edit code
vim myfile.js

# Right pane: Watch file changes
watch -n 1 ls -l
```

## Security Considerations

### Current Setup
- **Basic Authentication**: Username/password required
- **HTTP Only**: Currently unencrypted (suitable for private networks)
- **Tailscale Access**: Additional secure access via Tailscale VPN

### Future Enhancements (Optional)
1. **HTTPS with Let's Encrypt**: For encrypted connections
2. **IP Allowlisting**: Restrict access to specific IPs
3. **2FA**: Add two-factor authentication
4. **VPN-Only**: Access only through Tailscale

## Troubleshooting

### Cannot Connect to Web Terminal

1. **Check instance is running:**
   ```bash
   aws ec2 describe-instances --instance-ids i-0c8b2866303f87033 --query 'Reservations[0].Instances[0].State.Name'
   ```

2. **Check security group allows port 7681:**
   ```bash
   aws ec2 describe-security-groups --group-ids sg-06357a53d31e7ed76
   ```

3. **SSH to instance and check ttyd service:**
   ```bash
   ssh -i ~/.ssh/goldenshell-key.pem ubuntu@ec2-23-20-136-32.compute-1.amazonaws.com
   sudo systemctl status ttyd.service
   ```

### Session Not Persisting

Zellij sessions should persist even after browser disconnect. If they don't:

1. **Check Zellij is running:**
   ```bash
   zellij list-sessions
   ```

2. **Manually attach to session:**
   ```bash
   zellij attach default
   ```

### Performance Issues on Mobile

1. **Use external keyboard** for better performance
2. **Close other browser tabs** to free up memory
3. **Use landscape orientation** for more screen space
4. **Consider a larger tablet** for extended work sessions

### Connection Dropped

If your connection drops frequently:

1. **Check your internet connection stability**
2. **Switch to a more stable network** (WiFi vs cellular)
3. **Increase device screen timeout** to prevent sleep

## Cost Implications

### Running Costs

**EC2 Instance (t3.medium):**
- **Hourly:** ~$0.0416/hour
- **Daily (24 hours):** ~$1.00/day
- **Monthly (730 hours):** ~$30.37/month

**Data Transfer:**
- **Terminal data:** Minimal (< 1 GB/month typical)
- **Web terminal traffic:** ~$0.09/GB outbound

**Total Estimated Cost:**
- **Active 8 hours/day:** ~$10-15/month
- **Active 24/7:** ~$30-35/month

### Cost Optimization

The instance has **auto-shutdown enabled** (default: 30 minutes of inactivity):
- Stops automatically when not in use
- Restart when needed: `aws ec2 start-instances --instance-ids i-0c8b2866303f87033`
- Only pay for compute time when instance is running

**Storage costs continue** even when instance is stopped (~$3/month for 30GB EBS volume).

## Alternative Access Methods

### 1. SSH (Desktop/Linux)
```bash
ssh -i ~/.ssh/goldenshell-key.pem ubuntu@ec2-23-20-136-32.compute-1.amazonaws.com
```

### 2. Tailscale (Secure VPN)
Once configured, access via Tailscale network:
```bash
tailscale status  # Find machine name
ssh ubuntu@goldenshell-machine-name
```

### 3. AWS Systems Manager Session Manager
```bash
aws ssm start-session --target i-0c8b2866303f87033
```

## Next Steps

### Recommended Setup
1. **Bookmark the web terminal URL** on all your devices
2. **Add to home screen** on mobile devices
3. **Test multiple tab workflow** with Zellij
4. **Run a Claude Code session** in each tab
5. **Practice disconnecting and reconnecting** to see persistence

### Optional Enhancements
1. **Configure HTTPS** with nginx reverse proxy and Let's Encrypt
2. **Set up custom domain** pointing to your instance
3. **Configure Tailscale** for secure access without public port
4. **Customize Zellij** theme and keybindings in `~/.config/zellij/config.kdl`

## Support Resources

- **Zellij Documentation**: https://zellij.dev/documentation/
- **ttyd GitHub**: https://github.com/tsl0922/ttyd
- **Claude Code CLI**: https://docs.anthropic.com/claude/docs/claude-code-cli

## Example: Complete Mobile Workflow

1. **Morning**: Open web terminal on iPhone while commuting
2. **Create tabs** for each project you're working on
3. **Start Claude sessions** in relevant tabs
4. **Arrive at office**: Open web terminal on desktop
5. **Same sessions** are still running, pick up where you left off
6. **Lunch break**: Check progress on iPad
7. **Evening**: Quick fixes on phone before bed
8. **All day**: Same persistent session across all devices

This is the power of browser-based terminal with session persistence!
