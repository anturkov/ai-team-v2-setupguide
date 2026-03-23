# Chapter 08 - Inter-Machine Communication

This chapter covers how OpenClaw routes messages between AI models running on different machines, how to verify communication is working, and how to troubleshoot connectivity issues.

---

## 8.1 How OpenClaw Communication Works

OpenClaw uses a **message broker** architecture:

```
┌──────────────────────────────────────────────────────────────────┐
│                    OpenClaw Message Flow                         │
│                                                                  │
│  PC1 (Coordinator)                                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │ Model A      │───►│ OpenClaw     │───►│ Message      │       │
│  │ (sender)     │    │ Local Agent  │    │ Broker       │       │
│  └──────────────┘    └──────────────┘    └──────┬───────┘       │
│                                                  │               │
│                                   ┌──────────────┼───────────┐   │
│                                   │              │           │   │
│                                   ▼              ▼           ▼   │
│  PC1 (local)                   PC2 (remote)   Laptop       │   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │   │
│  │ OpenClaw     │    │ OpenClaw     │    │ OpenClaw     │  │   │
│  │ Local Agent  │    │ Remote Agent │    │ Remote Agent │  │   │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘  │   │
│         ▼                   ▼                   ▼          │   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │   │
│  │ Model B      │    │ Model C      │    │ Model D      │  │   │
│  │ (recipient)  │    │ (recipient)  │    │ (recipient)  │  │   │
│  └──────────────┘    └──────────────┘    └──────────────┘  │   │
└──────────────────────────────────────────────────────────────────┘
```

Key concepts:

1. **Messages are JSON-formatted** - Each message has a sender, recipient, content, and metadata
2. **Routing is automatic** - OpenClaw knows which model is on which machine (from model registration)
3. **Delivery is guaranteed** - Messages are queued and retried if the recipient is temporarily unavailable
4. **All messages are logged** - For audit and debugging purposes

---

## 8.2 Message Format

Every message in the system follows this structure:

```json
{
  "id": "msg-20240315-001",
  "timestamp": "2024-03-15T10:30:00Z",
  "from": "coordinator",
  "to": "senior-engineer-2",
  "task_id": "task-2024-001",
  "type": "task_assignment",
  "priority": "high",
  "content": "Implement the user authentication endpoint with JWT tokens.",
  "context": {
    "repository": "github.com/team/project",
    "branch": "feature/auth",
    "related_files": ["src/auth/routes.py"]
  },
  "expect_response": true,
  "timeout_seconds": 300
}
```

You don't need to construct these manually — OpenClaw builds them from simpler commands.

---

## 8.3 Setting Up Cross-Machine Communication

If you followed [Chapter 03](03-openclaw-installation.md) correctly, basic communication should already work. This section verifies and optimizes it.

### 8.3.1 Verify Cluster Health

On PC1:

```powershell
openclaw cluster status
```

All three nodes should show as ONLINE.

### 8.3.2 Test Cross-Machine Messaging

From PC1, send a message to a model on PC2:

```powershell
# Send to quality-agent on PC2
openclaw message send --to quality-agent --content "Ping test. Please respond with your name, role, and current node." --wait
```

The `--wait` flag makes the command wait for a response. You should see the quality-agent's reply within 10-30 seconds.

**Test all cross-machine routes:**

```powershell
# PC1 → PC2 (quality-agent)
openclaw message send --to quality-agent --content "Cross-machine test. Respond with OK." --wait

# PC1 → PC2 (security-agent)
openclaw message send --to security-agent --content "Cross-machine test. Respond with OK." --wait

# PC1 → Laptop (devops-agent)
openclaw message send --to devops-agent --content "Cross-machine test. Respond with OK." --wait

# PC1 → Laptop (monitoring-agent)
openclaw message send --to monitoring-agent --content "Cross-machine test. Respond with OK." --wait
```

### 8.3.3 Test Round-Trip Communication

A full round-trip: coordinator assigns a task, agent responds, coordinator processes the response.

```powershell
# Send a task that requires the agent to do work and report back
openclaw message send --to quality-agent --content "Review this code snippet and report any issues:

def add(a, b):
    return a + b + 1  # Bug: adds extra 1

Respond with your review findings." --wait --timeout 60
```

---

## 8.4 Network Configuration

### 8.4.1 Windows Firewall Rules

If machines can't communicate, you may need to add firewall rules. Run these on **each machine** (as Administrator):

```powershell
# Allow OpenClaw inbound traffic (port 8080)
New-NetFirewallRule -DisplayName "OpenClaw" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow

# Allow Ollama inbound traffic (port 11434) - for direct cross-machine access
New-NetFirewallRule -DisplayName "Ollama" -Direction Inbound -Protocol TCP -LocalPort 11434 -Action Allow

# Allow monitoring dashboard (port 3000) - laptop only
# Run this only on the laptop:
New-NetFirewallRule -DisplayName "Monitoring Dashboard" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow
```

**Verify the rules were created:**

```powershell
Get-NetFirewallRule -DisplayName "OpenClaw" | Format-Table -Property DisplayName, Enabled, Direction, Action
Get-NetFirewallRule -DisplayName "Ollama" | Format-Table -Property DisplayName, Enabled, Direction, Action
```

### 8.4.2 Test Port Connectivity

From PC1, test that you can reach the ports on other machines:

```powershell
# Test OpenClaw port on PC2
Test-NetConnection -ComputerName 192.168.1.112 -Port 8080

# Test Ollama port on PC2
Test-NetConnection -ComputerName 192.168.1.112 -Port 11434

# Test OpenClaw port on Laptop
Test-NetConnection -ComputerName 192.168.1.113 -Port 8080
```

Each should show `TcpTestSucceeded : True`.

### 8.4.3 Static IP Configuration (Recommended)

To prevent IP addresses from changing (which would break the cluster), set static IPs on each machine.

**On each machine:**

1. Open **Settings** > **Network & Internet** > **Ethernet** (or Wi-Fi)
2. Click on your connection
3. Under **IP assignment**, click **Edit**
4. Select **Manual**
5. Enable **IPv4**
6. Enter the settings:

| Machine | IP Address | Subnet Mask | Gateway | DNS |
|---------|-----------|-------------|---------|-----|
| PC1 | 192.168.1.106 | 255.255.255.0 | 192.168.1.1 | 192.168.1.1 |
| PC2 | 192.168.1.112 | 255.255.255.0 | 192.168.1.1 | 192.168.1.1 |
| Laptop | 192.168.1.113 | 255.255.255.0 | 192.168.1.1 | 192.168.1.1 |

> **Note**: Adjust the gateway and DNS to match your router's address. Common values are `192.168.1.1` or `192.168.0.1`.

---

## 8.5 Communication Patterns

### 8.5.1 Request-Response (Most Common)

The coordinator sends a task and waits for a response:

```powershell
# Coordinator → Agent → Coordinator
openclaw message send --to senior-engineer-1 --content "Design the database schema for a user management system." --wait --timeout 120
```

### 8.5.2 Fire-and-Forget

Send a message without waiting for a response (useful for notifications):

```powershell
# Coordinator notifies monitoring agent (no response needed)
openclaw message send --to monitoring-agent --content "New task started. Track resource usage for the next 30 minutes."
```

### 8.5.3 Broadcast

Send a message to all agents:

```powershell
# Coordinator announces to all
openclaw message broadcast --content "System maintenance in 10 minutes. Save your work."
```

### 8.5.4 Peer-to-Peer

Agents can communicate directly (without going through the coordinator):

```powershell
# Quality agent asks security agent for input
openclaw message send --from quality-agent --to security-agent --content "Found a SQL query in the code. Can you review it for injection vulnerabilities?"
```

---

## 8.6 Message Queue and Retry

### 8.6.1 How the Queue Works

If a model is busy or temporarily unavailable, messages are queued:

1. Message arrives at the target node
2. If the model is busy → message enters a FIFO queue
3. When the model finishes its current task → next message is dequeued
4. If the model is unavailable → message is retried with exponential backoff

### 8.6.2 Queue Configuration

```powershell
# Set maximum queue size per model (default: 100)
openclaw config set queue.max_size 100

# Set retry attempts for failed deliveries (default: 3)
openclaw config set queue.max_retries 3

# Set retry backoff (seconds between retries)
openclaw config set queue.retry_backoff "5,15,60"  # 5s, 15s, 60s

# Set message expiry (how long undelivered messages are kept)
openclaw config set queue.message_ttl_minutes 30
```

### 8.6.3 Monitor the Queue

```powershell
# View current queue status
openclaw queue status

# View pending messages
openclaw queue list --pending

# Clear stuck messages (use with caution)
openclaw queue flush --model quality-agent
```

---

## 8.7 Latency Expectations

| Route | Expected Latency | Notes |
|-------|------------------|-------|
| PC1 → PC1 (same machine) | < 1 ms | Message routing only |
| PC1 → PC2 (cross-machine) | 1-5 ms | Network hop |
| PC1 → Laptop (cross-machine) | 1-10 ms | Depends on Wi-Fi vs Ethernet |
| Model response time (GPU) | 5-60 seconds | Depends on model size and prompt length |
| Model response time (CPU) | 30-180 seconds | Much slower, avoid if possible |

> **The bottleneck is always model inference, not network latency.** A 32B model takes ~15-30 seconds to generate a response, making 5ms of network latency negligible.

---

## 8.8 Checklist

- [ ] All nodes show ONLINE in `openclaw cluster status`
- [ ] Cross-machine messaging works (PC1→PC2, PC1→Laptop)
- [ ] Windows Firewall rules added for OpenClaw and Ollama ports
- [ ] Port connectivity verified with `Test-NetConnection`
- [ ] Static IPs configured (recommended)
- [ ] Round-trip communication tested (send task, receive result)
- [ ] Broadcast messaging works
- [ ] Message queue is functional (test with busy model)

---

Next: [Chapter 09 - GitHub Integration](09-github-integration.md)
