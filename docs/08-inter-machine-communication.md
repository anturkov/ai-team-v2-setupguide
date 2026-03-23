# Chapter 08 - Inter-Machine Communication

This chapter covers how OpenClaw agents on different machines communicate via webhooks, how to verify communication is working, and how to troubleshoot connectivity issues.

---

## 8.1 How OpenClaw Cross-Machine Communication Works

Each machine runs its own independent OpenClaw Gateway. Agents on different machines communicate via **webhooks** — HTTP requests between Gateways that trigger agent actions.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    OpenClaw Cross-Machine Message Flow                    │
│                                                                          │
│  PC1 (192.168.1.106:18789)                                               │
│  ┌──────────────┐    ┌──────────────┐    ┌────────────────────────────┐  │
│  │ Coordinator  │───►│ OpenClaw     │───►│ Outbound webhook POST to  │  │
│  │ Agent        │    │ Gateway      │    │ PC2 or Laptop Gateway     │  │
│  └──────────────┘    └──────────────┘    └───────────┬────────────────┘  │
│                                                       │                  │
│                                          ┌────────────┼──────────┐       │
│                                          ▼                       ▼       │
│                              PC2 (192.168.1.112:18789)  Laptop (:18789) │
│                              ┌──────────────┐    ┌──────────────┐       │
│                              │ Gateway      │    │ Gateway      │       │
│                              │ /hooks/agent │    │ /hooks/agent │       │
│                              └──────┬───────┘    └──────┬───────┘       │
│                                     ▼                   ▼               │
│                              ┌──────────────┐    ┌──────────────┐       │
│                              │ Quality or   │    │ DevOps or    │       │
│                              │ Security     │    │ Monitoring   │       │
│                              │ Agent        │    │ Agent        │       │
│                              └──────────────┘    └──────────────┘       │
└──────────────────────────────────────────────────────────────────────────┘
```

Key concepts:

1. **Webhooks are HTTP POST requests** — The Coordinator agent on PC1 sends tasks to agents on other machines by POSTing to their Gateway's `/hooks/agent` endpoint
2. **Authentication via shared token** — All webhook requests include a Bearer token in the `Authorization` header (configured in `hooks.token`)
3. **Routing is agent-targeted** — The webhook payload specifies which agent should handle the request
4. **Responses can be async** — The webhook returns HTTP 200 immediately; the target agent processes the task and can respond via a webhook back to PC1
5. **All requests are logged** — For audit and debugging purposes

---

## 8.2 Webhook Message Format

When the Coordinator sends a task to a remote agent, it POSTs to the target Gateway's webhook endpoint:

**Endpoint**: `POST http://<target-ip>:18789/hooks/agent`

**Headers**:
```
Authorization: Bearer <hooks.token>
Content-Type: application/json
```

**Body**:
```json
{
  "prompt": "Review this code snippet and report any issues:\n\ndef add(a, b):\n    return a + b + 1  # Bug: adds extra 1\n\nRespond with your review findings.",
  "agentId": "quality-agent",
  "sessionKey": "task:2026-001",
  "replyTo": {
    "url": "http://192.168.1.106:18789/hooks/agent",
    "agentId": "coordinator",
    "sessionKey": "task:2026-001"
  }
}
```

| Field | Purpose |
|-------|---------|
| `prompt` | The task/message for the target agent |
| `agentId` | Which agent on the target machine should handle this |
| `sessionKey` | Session identifier for conversation continuity |
| `replyTo` | (Optional) Where the agent should send its response back |

You don't need to construct these manually — the Coordinator agent's skills handle webhook dispatch (see [Chapter 06](06-team-configuration.md) for skill setup).

---

## 8.3 Setting Up Cross-Machine Communication

If you followed [Chapter 03](03-openclaw-installation.md) correctly, the webhook endpoints should already be configured. This section verifies and tests them.

### 8.3.1 Verify Gateway Health on All Machines

On each machine:

```powershell
openclaw gateway status
openclaw gateway health
```

All three Gateways should be running and healthy.

### 8.3.2 Probe Cross-Machine Gateways

From PC1:

```powershell
# Probe PC2
openclaw gateway probe --url http://192.168.1.112:18789

# Probe Laptop
openclaw gateway probe --url http://192.168.1.113:18789
```

Both should return a successful probe result.

### 8.3.3 Test Webhook Delivery

From PC1, send a test webhook to PC2's quality-agent:

```powershell
# Wake test (lightweight, just confirms the endpoint is reachable)
Invoke-RestMethod -Uri "http://192.168.1.112:18789/hooks/wake" `
  -Method POST `
  -Headers @{ "Authorization" = "Bearer YOUR_WEBHOOK_SECRET_HERE" }
```

Then test an actual agent prompt:

```powershell
# Send a task to quality-agent on PC2
$body = @{
    prompt = "Ping test. Please respond with your name, role, and current machine."
    agentId = "quality-agent"
    sessionKey = "hook:test-001"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://192.168.1.112:18789/hooks/agent" `
  -Method POST `
  -Headers @{
    "Authorization" = "Bearer YOUR_WEBHOOK_SECRET_HERE"
    "Content-Type" = "application/json"
  } `
  -Body $body
```

**Test all routes:**

```powershell
# PC1 → PC2 (quality-agent)
# PC1 → PC2 (security-agent)
# PC1 → Laptop (devops-agent)
# PC1 → Laptop (monitoring-agent)
```

Repeat the above with each `agentId` and target IP.

### 8.3.4 Test Round-Trip Communication

A full round-trip: Coordinator sends a task via webhook, the remote agent processes it, and responds back via webhook to the Coordinator.

This requires the Coordinator agent's dispatch skill to be configured (see [Chapter 06](06-team-configuration.md)). Once configured, the Coordinator can send tasks and receive responses automatically.

---

## 8.4 Network Configuration

### 8.4.1 Windows Firewall Rules

If machines can't communicate, you may need to add firewall rules. Run these on **each machine** (as Administrator):

```powershell
# Allow OpenClaw Gateway inbound traffic (port 18789)
New-NetFirewallRule -DisplayName "OpenClaw Gateway" -Direction Inbound -Protocol TCP -LocalPort 18789 -Action Allow

# Allow Ollama inbound traffic (port 11434) - for direct cross-machine model access
New-NetFirewallRule -DisplayName "Ollama" -Direction Inbound -Protocol TCP -LocalPort 11434 -Action Allow
```

**Verify the rules were created:**

```powershell
Get-NetFirewallRule -DisplayName "OpenClaw*" | Format-Table -Property DisplayName, Enabled, Direction, Action
Get-NetFirewallRule -DisplayName "Ollama" | Format-Table -Property DisplayName, Enabled, Direction, Action
```

### 8.4.2 Test Port Connectivity

From PC1, test that you can reach the Gateway port on other machines:

```powershell
# Test OpenClaw Gateway on PC2
Test-NetConnection -ComputerName 192.168.1.112 -Port 18789

# Test OpenClaw Gateway on Laptop
Test-NetConnection -ComputerName 192.168.1.113 -Port 18789

# Test Ollama on PC2 (if direct model access is needed)
Test-NetConnection -ComputerName 192.168.1.112 -Port 11434
```

Each should show `TcpTestSucceeded : True`.

### 8.4.3 Static IP Configuration (Recommended)

To prevent IP addresses from changing (which breaks webhook URLs), set static IPs on each machine.

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

### 8.5.1 Request-Response via Webhooks

The Coordinator sends a task to a remote agent and receives the result back via a webhook callback:

```
PC1 Coordinator ──POST /hooks/agent──► PC2 Quality Agent
     (includes replyTo URL)
                                           │
PC1 Coordinator ◄──POST /hooks/agent───────┘
     (receives result via callback)
```

The `replyTo` field in the webhook payload tells the remote agent where to send its response.

### 8.5.2 Fire-and-Forget

Send a task without expecting a response (useful for notifications and monitoring triggers):

```powershell
$body = @{
    prompt = "New deployment started. Begin monitoring resource usage for the next 30 minutes."
    agentId = "monitoring-agent"
    sessionKey = "hook:monitor-deploy-001"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://192.168.1.113:18789/hooks/agent" `
  -Method POST `
  -Headers @{
    "Authorization" = "Bearer YOUR_WEBHOOK_SECRET_HERE"
    "Content-Type" = "application/json"
  } `
  -Body $body
```

### 8.5.3 Broadcast (via Coordinator Skill)

The Coordinator agent can broadcast to all agents by dispatching webhooks to each machine. This is implemented as a Coordinator skill, not a built-in command. See [Chapter 06](06-team-configuration.md) for the broadcast skill setup.

### 8.5.4 Peer-to-Peer

Agents on different machines can communicate directly via webhooks without going through the Coordinator, as long as both Gateways have webhooks enabled and the agent IDs are in `allowedAgentIds`:

```
PC2 Quality Agent ──POST /hooks/agent──► PC2 Security Agent (same machine, local)
PC2 Quality Agent ──POST /hooks/agent──► Laptop DevOps Agent (cross-machine)
```

---

## 8.6 Webhook Security

### 8.6.1 Token Authentication

Every webhook request **must** include the hook token in the `Authorization` header:

```
Authorization: Bearer <hooks.token>
```

> **Important**: Query-string tokens are rejected (return HTTP 400). Always use the header.

### 8.6.2 Allowed Agent IDs

Each Gateway only accepts webhooks for agents listed in `hooks.allowedAgentIds`:

```json5
hooks: {
  allowedAgentIds: ["quality-agent", "security-agent"]  // Only these agents
  // or: ["*"]  // Any agent (less secure)
}
```

### 8.6.3 Session Key Prefixes

Limit which session keys webhooks can create:

```json5
hooks: {
  allowedSessionKeyPrefixes: ["hook:", "task:"]  // Only sessions starting with these
}
```

---

## 8.7 Latency Expectations

| Route | Expected Latency | Notes |
|-------|------------------|-------|
| PC1 → PC1 (same Gateway) | < 1 ms | Internal agent routing |
| PC1 → PC2 (webhook) | 5-50 ms | Network hop + HTTP overhead |
| PC1 → Laptop (webhook) | 5-100 ms | Depends on Wi-Fi vs Ethernet |
| Model response time (GPU) | 5-60 seconds | Depends on model size and prompt |
| Model response time (CPU) | 30-180 seconds | Much slower, avoid if possible |

> **The bottleneck is always model inference, not network latency.** A 32B model takes ~15-30 seconds to generate a response, making 50ms of webhook overhead negligible.

---

## 8.8 Troubleshooting Cross-Machine Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Connection refused | Gateway not running or wrong port | `openclaw gateway status` on target machine |
| HTTP 401 Unauthorized | Wrong webhook token | Check `hooks.token` matches on both machines |
| HTTP 400 Bad Request | Token in query string, not header | Use `Authorization: Bearer <token>` header |
| HTTP 404 Not Found | Wrong webhook path | Check `hooks.path` config (default: `/hooks`) |
| Agent not found | `agentId` not in `allowedAgentIds` | Add the agent to `hooks.allowedAgentIds` |
| Timeout | Firewall blocking port 18789 | Add firewall rule (Section 8.4.1) |
| Gateway not reachable | Bound to loopback only | Set `gateway.bind` to `"lan"` |

Check Gateway logs for detailed error messages:

```powershell
openclaw logs
```

---

## 8.9 Checklist

- [ ] All Gateways running and healthy (`openclaw gateway health` on each machine)
- [ ] Gateway probe succeeds from PC1 to PC2 and Laptop
- [ ] Windows Firewall rules added for OpenClaw (port 18789) and Ollama (port 11434)
- [ ] Port connectivity verified with `Test-NetConnection`
- [ ] Static IPs configured (recommended)
- [ ] Webhook wake test succeeds (PC1 → PC2, PC1 → Laptop)
- [ ] Webhook agent test succeeds (task delivered to correct agent)
- [ ] Webhook tokens match across all machines
- [ ] `allowedAgentIds` configured correctly on PC2 and Laptop

---

Next: [Chapter 09 - GitHub Integration](09-github-integration.md)
