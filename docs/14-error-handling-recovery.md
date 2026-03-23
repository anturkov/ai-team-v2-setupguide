# Chapter 14 - Error Handling & Recovery

This chapter covers how the system handles failures, retries, graceful degradation, and recovery from various error scenarios.

---

## 14.1 Error Categories

| Category | Severity | Example | Auto-Recovery? |
|----------|----------|---------|---------------|
| Model Timeout | Medium | Model takes too long to respond | Yes - retry |
| Model Crash | High | Ollama process crashes | Yes - restart |
| Node Offline | High | A machine loses network | Partial - reassign |
| Coordinator Down | Critical | PC1 goes offline | Manual - backup coordinator |
| VRAM Exhaustion | Medium | Out of GPU memory | Yes - offload to CPU |
| Disk Full | High | No space for model output | No - requires cleanup |
| API Rate Limit | Low | Claude.ai API limit hit | Yes - backoff |
| Network Partition | High | Machines can't communicate | Partial - local work continues |

---

## 14.2 Automatic Retry Mechanism

### 14.2.1 Retry Configuration

```yaml
# Add to OpenClaw config or team.yaml
error_handling:
  retry:
    max_attempts: 3
    backoff_strategy: "exponential"    # linear, exponential, or fixed
    initial_delay_seconds: 5
    max_delay_seconds: 60
    backoff_multiplier: 2              # For exponential: 5s, 10s, 20s

  # Per-error-type overrides
  overrides:
    model_timeout:
      max_attempts: 2
      initial_delay_seconds: 10
    api_rate_limit:
      max_attempts: 5
      initial_delay_seconds: 30
      backoff_multiplier: 3
    node_offline:
      max_attempts: 10
      initial_delay_seconds: 15
```

### 14.2.2 Retry Flow

```
Attempt 1: Send message to quality-agent
  Result: TIMEOUT (model busy)
  Action: Wait 5 seconds

Attempt 2: Retry message to quality-agent
  Result: TIMEOUT (still busy)
  Action: Wait 10 seconds (5 * 2)

Attempt 3: Retry message to quality-agent
  Result: SUCCESS
  Action: Continue with response

-- OR --

Attempt 3: Retry message to quality-agent
  Result: TIMEOUT (3rd failure)
  Action: Mark as FAILED, notify coordinator
  Coordinator: Reassign to backup-engineer on PC2 or escalate
```

---

## 14.3 Graceful Degradation

When components fail, the system continues operating with reduced capability.

### 14.3.1 Degradation Levels

```
Level 0: FULL CAPACITY
  All machines online, all models available
  ↓
Level 1: REDUCED CAPACITY
  One worker node offline (PC2 or Laptop)
  Impact: Fewer specialized agents, longer queue times
  ↓
Level 2: MINIMAL CAPACITY
  Only PC1 online
  Impact: Coordinator handles all tasks directly, no specialized review
  ↓
Level 3: OFFLINE
  All machines down
  Impact: System unavailable, Telegram bot unresponsive
```

### 14.3.2 Degradation Responses

**PC2 Goes Offline:**

```
Coordinator detects: PC2 unreachable
Actions:
  1. Log event: "PC2 offline at 2024-03-15T10:00:00Z"
  2. Reassign quality-agent tasks to coordinator (self-review)
  3. Reassign security-agent tasks to coordinator (basic security check)
  4. Notify human via Telegram:
     "PC2 (192.168.1.112) is offline. Quality and Security review
      will be handled by the coordinator with reduced capability.
      Tasks may take longer."
  5. Monitor PC2 for recovery (ping every 30 seconds)
  6. When PC2 comes back: restore normal routing, re-run any
     skipped quality/security reviews
```

**Laptop Goes Offline:**

```
Coordinator detects: Laptop unreachable
Actions:
  1. Log event: "Laptop offline at 2024-03-15T10:00:00Z"
  2. Disable monitoring alerts (monitoring agent is on laptop)
  3. DevOps tasks handled by coordinator directly
  4. Notify human via Telegram:
     "Laptop (192.168.1.113) is offline. Monitoring and DevOps
      agents unavailable. System monitoring is paused."
  5. Monitor laptop for recovery
```

### 14.3.3 Degradation Configuration

```yaml
# Degradation rules in team.yaml
degradation:
  pc2_offline:
    reassign:
      quality-agent: "coordinator"      # Coordinator self-reviews
      security-agent: "coordinator"     # Basic security check
      backup-engineer: null             # Not available
    notify_human: true
    message: "PC2 offline - reduced review capability"

  laptop_offline:
    reassign:
      devops-agent: "coordinator"
      monitoring-agent: null            # Monitoring paused
    notify_human: true
    message: "Laptop offline - monitoring paused"

  pc1_offline:
    action: "activate_backup_coordinator"
    backup_node: "pc2-worker"
    backup_model: "backup-engineer"     # Runs as emergency coordinator
    notify_human: true
    message: "CRITICAL - PC1 offline. Backup coordinator activated on PC2."
```

---

## 14.4 Backup Coordinator

If PC1 goes down, the entire system loses its coordinator and Telegram bot. A backup coordinator on PC2 can partially restore functionality.

### 14.4.1 Pre-Configure Backup Coordinator on PC2

```powershell
# On PC2: Create a backup coordinator Modelfile
# File: C:\AI-Team\models\Modelfile-backup-coordinator

# Content:
# FROM codellama:7b-instruct-q4_K_M
# PARAMETER temperature 0.3
# SYSTEM "You are the BACKUP COORDINATOR. The primary coordinator (PC1) is offline.
#   You have limited capabilities but must keep the team operational.
#   Priority: inform human of the outage and maintain basic task handling."

ollama create backup-coordinator -f C:\AI-Team\models\Modelfile-backup-coordinator

# Register the backup coordinator with OpenClaw
openclaw model register --name "backup-coordinator" --ollama-model "backup-coordinator" --role "coordinator" --priority 10
```

### 14.4.2 Automatic Failover

```yaml
# Failover configuration
failover:
  coordinator:
    health_check_interval_seconds: 15
    failure_threshold: 3               # 3 consecutive failures = failover
    backup_node: "pc2-worker"
    backup_model: "backup-coordinator"
    restore_on_recovery: true          # Automatically switch back when PC1 returns
```

### 14.4.3 What the Backup Coordinator Can Do

| Capability | Available? | Notes |
|-----------|-----------|-------|
| Receive tasks via Telegram | Only if Telegram bot is configured on PC2 | Requires separate bot setup |
| Assign tasks to agents | Yes | Limited to available agents on PC2 and Laptop |
| Run quality reviews | Yes | Quality agent is on PC2 |
| Run security reviews | Yes | Security agent is on PC2 |
| Access GitHub | Yes | If PAT is configured on PC2 |
| Complex reasoning | Limited | 7B model vs 32B on PC1 |

---

## 14.5 Session Persistence

### 14.5.1 What Gets Persisted

- Active task list and their states
- Message history (last 100 messages per conversation)
- Model registration and configuration
- Pending queue items

### 14.5.2 Recovery After Restart

When OpenClaw restarts (after a crash or reboot):

```
1. Load persisted state from disk (C:\AI-Team\openclaw\data\)
2. Re-register with cluster (or wait for nodes to reconnect)
3. Check pending tasks:
   - Tasks in ASSIGNED state: check if agent has a response
   - Tasks in IN_PROGRESS: send status query to assigned agent
   - Tasks in REVIEW: check if review is complete
4. Resume normal operation
5. Notify human: "System restarted. X tasks recovered."
```

### 14.5.3 State File Locations

```
C:\AI-Team\openclaw\data\
  ├── cluster_state.json       # Node registration and health
  ├── task_state.json          # Active tasks and history
  ├── message_queue.json       # Pending messages
  ├── model_registry.json      # Registered models
  └── session_data.json        # Conversation contexts
```

---

## 14.6 Common Error Scenarios and Solutions

### 14.6.1 Model Out of Memory (OOM)

```
Error: "CUDA out of memory"

Cause: Model requires more VRAM than available

Auto-Recovery:
  1. Unload the model
  2. Attempt to load with more CPU offloading (fewer GPU layers)
  3. If still fails: notify coordinator to reassign to a smaller model

Prevention:
  - Don't run too many models simultaneously
  - Set OLLAMA_MAX_LOADED_MODELS appropriately
  - Monitor VRAM usage with the monitoring script
```

### 14.6.2 Ollama Process Crash

```
Error: Ollama process exited unexpectedly

Auto-Recovery:
  1. Detect via health check (every 15 seconds)
  2. Attempt to restart Ollama:
     Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
  3. Wait 10 seconds for startup
  4. Verify: Invoke-RestMethod http://127.0.0.1:11434/api/tags
  5. If recovered: re-warm critical models
  6. If not recovered after 3 attempts: alert human

Prevention:
  - Keep NVIDIA drivers updated
  - Monitor GPU temperature (overheating causes crashes)
  - Don't exceed VRAM limits
```

### 14.6.3 Network Timeout

```
Error: "Connection timed out" to remote node

Auto-Recovery:
  1. Retry with exponential backoff (5s, 10s, 20s)
  2. If node unreachable after 3 retries:
     - Mark node as OFFLINE
     - Activate degradation mode
     - Continue monitoring for recovery

Prevention:
  - Use static IPs (prevents DHCP changes)
  - Use Ethernet instead of Wi-Fi when possible
  - Monitor network latency
```

### 14.6.4 Claude.ai API Error

```
Error: "429 Too Many Requests" or "500 Internal Server Error"

Auto-Recovery:
  429 (Rate Limit):
    1. Wait for the retry-after header value
    2. Retry after the cooldown
    3. If persistent: reduce request frequency

  500 (Server Error):
    1. Retry after 30 seconds
    2. If persistent: skip external consultant for this task
    3. Use local models as fallback

Prevention:
  - Set max_requests_per_hour in config
  - Only route truly complex problems to Claude.ai
  - Cache frequent queries
```

---

## 14.7 Recovery Scripts

### Restart All Services Script

**File**: `C:\AI-Team\scripts\restart-all.ps1`

```powershell
<#
.SYNOPSIS
    Restart all AI Team services on the local machine
#>

Write-Host "=== Restarting AI Team Services ===" -ForegroundColor Cyan

# Stop services
Write-Host "Stopping OpenClaw..." -ForegroundColor Yellow
openclaw service stop 2>$null
Start-Sleep -Seconds 2

Write-Host "Stopping Ollama..." -ForegroundColor Yellow
taskkill /f /im ollama.exe 2>$null
taskkill /f /im ollama_runners.exe 2>$null
Start-Sleep -Seconds 3

# Start services
Write-Host "Starting Ollama..." -ForegroundColor Yellow
Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
Start-Sleep -Seconds 5

# Verify Ollama is up
try {
    Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 10 | Out-Null
    Write-Host "Ollama: RUNNING" -ForegroundColor Green
} catch {
    Write-Host "Ollama: FAILED TO START" -ForegroundColor Red
    exit 1
}

Write-Host "Starting OpenClaw..." -ForegroundColor Yellow
openclaw service start
Start-Sleep -Seconds 5

# Verify OpenClaw
try {
    openclaw cluster status 2>$null | Out-Null
    Write-Host "OpenClaw: RUNNING" -ForegroundColor Green
} catch {
    Write-Host "OpenClaw: FAILED TO START" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== All services restarted ===" -ForegroundColor Green
```

---

## 14.8 Checklist

- [ ] Retry mechanism configured with exponential backoff
- [ ] Graceful degradation rules defined for each machine going offline
- [ ] Backup coordinator pre-configured on PC2
- [ ] Automatic failover tested (stop OpenClaw on PC1, verify PC2 takes over)
- [ ] Session persistence verified (restart OpenClaw, check tasks are recovered)
- [ ] OOM recovery tested (try loading a too-large model)
- [ ] Network timeout handling verified
- [ ] Restart-all script tested on each machine
- [ ] Recovery notifications reach Telegram

---

Next: [Chapter 15 - Performance Tuning](15-performance-tuning.md)
