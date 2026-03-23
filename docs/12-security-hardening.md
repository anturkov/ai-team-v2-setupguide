# Chapter 12 - Security Hardening

This chapter covers security best practices for the distributed AI team, including credential management, network security, access controls, and audit logging.

---

## 12.1 Security Principles

1. **Least Privilege**: Each agent only has the permissions it needs
2. **Defense in Depth**: Multiple layers of security controls
3. **Audit Everything**: All actions are logged for review
4. **No Secrets in Code**: Credentials are never stored in repositories
5. **Human Gate**: Critical operations require human approval

---

## 12.2 Credential Management

### 12.2.1 Where Credentials Are Stored

| Credential | Storage Location | Access |
|-----------|-----------------|--------|
| GitHub SSH Keys | `~/.ssh/` (per machine) | Local SSH agent only |
| GitHub PAT | OpenClaw secure config | Coordinator only |
| Telegram Bot Token | OpenClaw secure config | Coordinator only |
| Claude.ai API Key | OpenClaw secure config | Coordinator only |
| OpenClaw cluster key | OpenClaw config | All nodes |

### 12.2.2 Never Store Credentials In:

- Git repositories (use `.gitignore`)
- Environment variables visible to all processes
- Log files
- Shared directories
- Chat messages or task descriptions

### 12.2.3 Create a .gitignore Template

Apply this to all repositories the AI team works on:

```powershell
# Create global gitignore
$gitignore = @"
# Credentials and secrets
*.key
*.pem
*.env
.env
.env.*
credentials.json
secrets.yaml
secrets.yml
*.secret

# API keys and tokens
token.txt
api_key.txt

# OpenClaw config (contains tokens)
openclaw.yaml
telegram.yaml

# IDE and OS files
.vscode/settings.json
.idea/
*.swp
Thumbs.db
Desktop.ini
"@

Set-Content -Path "$env:USERPROFILE\.gitignore_global" -Value $gitignore
git config --global core.excludesfile "$env:USERPROFILE\.gitignore_global"
```

### 12.2.4 Rotate Credentials Regularly

| Credential | Rotation Frequency | How to Rotate |
|-----------|-------------------|---------------|
| GitHub PAT | Every 90 days | Generate new token on GitHub, update OpenClaw config |
| Telegram Bot Token | Every 6 months | Use `/revoke` in BotFather, create new bot |
| Claude.ai API Key | Every 90 days | Generate new key in Anthropic console |
| SSH Keys | Every 12 months | Generate new keys, add to GitHub, remove old ones |

---

## 12.3 Network Security

### 12.3.1 Firewall Configuration

Only open the ports that are absolutely necessary:

```powershell
# Run on each machine as Administrator

# Remove any overly permissive rules first
# (Only do this if you previously created broad rules)
# Remove-NetFirewallRule -DisplayName "OpenClaw" -ErrorAction SilentlyContinue

# Create specific rules for the AI team subnet only
$subnet = "192.168.1.0/24"

# OpenClaw - only from local subnet
New-NetFirewallRule -DisplayName "OpenClaw - Local Subnet" `
    -Direction Inbound -Protocol TCP -LocalPort 8080 `
    -RemoteAddress $subnet -Action Allow

# Ollama - only from local subnet
New-NetFirewallRule -DisplayName "Ollama - Local Subnet" `
    -Direction Inbound -Protocol TCP -LocalPort 11434 `
    -RemoteAddress $subnet -Action Allow

# Block these ports from all other sources
New-NetFirewallRule -DisplayName "OpenClaw - Block External" `
    -Direction Inbound -Protocol TCP -LocalPort 8080 `
    -RemoteAddress "0.0.0.0/0" -Action Block

New-NetFirewallRule -DisplayName "Ollama - Block External" `
    -Direction Inbound -Protocol TCP -LocalPort 11434 `
    -RemoteAddress "0.0.0.0/0" -Action Block
```

### 12.3.2 Outbound Traffic Control

Only allow necessary outbound connections:

| Destination | Port | Purpose | Machines |
|------------|------|---------|----------|
| api.telegram.org | 443 | Telegram Bot API | PC1 only |
| github.com | 22, 443 | Git operations | All |
| api.anthropic.com | 443 | Claude.ai API | PC1 only |
| ollama.com | 443 | Model downloads | All (during setup only) |

### 12.3.3 OpenClaw Cluster Authentication

Secure the communication between OpenClaw nodes:

```powershell
# Generate a cluster secret (run once on PC1)
openclaw cluster generate-secret

# This outputs a secret key like:
# Cluster secret: oc-secret-xxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Set the same secret on ALL machines
openclaw config set cluster.secret "oc-secret-xxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Restart OpenClaw on all machines for the change to take effect
openclaw service restart
```

---

## 12.4 Access Control

### 12.4.1 Agent Permissions Matrix

| Agent | GitHub | Files | Network | Telegram | Install SW |
|-------|--------|-------|---------|----------|-----------|
| Coordinator | Read/Write | Read/Write | Outbound | Send/Receive | No |
| Senior Eng #1 | Read/Write | Read/Write | None | No | No |
| Senior Eng #2 | Read/Write | Read/Write | None | No | No |
| Quality Agent | Read/Write | Read/Write | None | No | No |
| Security Agent | Read | Read | None | No | No |
| DevOps Agent | Read/Write | Read/Write | Limited | No | No |
| Monitoring Agent | Read | Read | None | No | No |
| External Consultant | None | None | N/A | No | No |

### 12.4.2 File System Restrictions

Limit which directories the AI agents can access:

```powershell
# Configure OpenClaw file access restrictions
openclaw config set files.allowed_paths "C:\\AI-Team\\repos,C:\\AI-Team\\temp,C:\\AI-Team\\logs"
openclaw config set files.denied_paths "C:\\Windows,C:\\Users\\*\\AppData,C:\\Program Files"
openclaw config set files.max_file_size_mb 100
```

---

## 12.5 Audit Logging

### 12.5.1 What Gets Logged

| Event | Log Location | Retention |
|-------|-------------|-----------|
| All inter-model messages | `C:\AI-Team\logs\communication.log` | 30 days |
| GitHub operations | `C:\AI-Team\logs\github.log` | 30 days |
| Telegram messages | `C:\AI-Team\logs\telegram.log` | 30 days |
| Task lifecycle events | `C:\AI-Team\logs\tasks.log` | 30 days |
| Security alerts | `C:\AI-Team\logs\security.log` | 90 days |
| Resource metrics | `C:\AI-Team\logs\monitoring.log` | 7 days |
| OpenClaw system events | `C:\AI-Team\openclaw\logs\openclaw.log` | 14 days |

### 12.5.2 Enable Comprehensive Logging

```powershell
# Enable audit logging for all operations
openclaw config set logging.audit.enabled "true"
openclaw config set logging.audit.path "C:\\AI-Team\\logs"
openclaw config set logging.audit.include_message_content "true"
openclaw config set logging.audit.retention_days 30
```

### 12.5.3 Log Rotation

Set up automatic log rotation to prevent disk filling up:

**File**: `C:\AI-Team\scripts\rotate-logs.ps1`

```powershell
<#
.SYNOPSIS
    Rotate and compress old log files
#>

$logDir = "C:\AI-Team\logs"
$maxAgeDays = 30
$compressAfterDays = 7

# Compress logs older than 7 days
Get-ChildItem -Path $logDir -Filter "*.log" | Where-Object {
    $_.LastWriteTime -lt (Get-Date).AddDays(-$compressAfterDays) -and
    $_.Extension -ne ".zip"
} | ForEach-Object {
    $zipPath = "$($_.FullName).zip"
    Compress-Archive -Path $_.FullName -DestinationPath $zipPath -Force
    Remove-Item $_.FullName
    Write-Host "Compressed: $($_.Name)"
}

# Delete logs older than 30 days
Get-ChildItem -Path $logDir -Filter "*.zip" | Where-Object {
    $_.LastWriteTime -lt (Get-Date).AddDays(-$maxAgeDays)
} | ForEach-Object {
    Remove-Item $_.FullName
    Write-Host "Deleted: $($_.Name)"
}

Write-Host "Log rotation complete."
```

Schedule this to run daily:

```powershell
$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-ExecutionPolicy Bypass -File C:\AI-Team\scripts\rotate-logs.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At "03:00"
Register-ScheduledTask -TaskName "AI-Team-LogRotation" -Action $action -Trigger $trigger -Description "Rotate AI Team logs"
```

---

## 12.6 Security Monitoring

The Security Agent actively watches for policy violations:

```yaml
# Security monitoring rules
security_monitoring:
  scan_interval_minutes: 5

  rules:
    - name: "secrets_in_code"
      description: "Detect hardcoded secrets in committed code"
      pattern: "(password|secret|token|api_key)\\s*=\\s*['\"][^'\"]+['\"]"
      severity: "HIGH"
      action: "alert_coordinator"

    - name: "unauthorized_network"
      description: "Detect unexpected outbound connections"
      check: "new_connections_outside_allowlist"
      severity: "CRITICAL"
      action: "alert_coordinator_and_telegram"

    - name: "file_access_violation"
      description: "Detect access to restricted directories"
      check: "file_access_outside_allowed_paths"
      severity: "HIGH"
      action: "block_and_alert"

    - name: "privilege_escalation"
      description: "Detect attempts to run as admin"
      check: "elevation_attempt"
      severity: "CRITICAL"
      action: "block_and_alert"
```

---

## 12.7 Security Checklist

- [ ] All credentials stored in OpenClaw secure config (not in files or env vars)
- [ ] `.gitignore` configured to exclude credential files
- [ ] Firewall rules restrict OpenClaw and Ollama to local subnet
- [ ] OpenClaw cluster authentication configured with shared secret
- [ ] Agent permissions set according to the permissions matrix
- [ ] File system access restricted to AI-Team directories
- [ ] Audit logging enabled for all operations
- [ ] Log rotation scheduled
- [ ] Security monitoring rules configured
- [ ] Credential rotation schedule documented
- [ ] No secrets in any git repository
- [ ] Telegram bot token stored securely
- [ ] SSH keys have no passphrase OR passphrase is stored securely

---

Next: [Chapter 13 - Conflict Resolution](13-conflict-resolution.md)
