# Chapter 08 - Inter-Machine Communication

This chapter covers how the single OpenClaw Gateway on PC1 communicates with remote Ollama instances and Nodes on PC2 and Laptop.

> **TL;DR — No webhooks needed.** OpenClaw does NOT use webhooks/hooks for inter-machine agent communication. There are only two channels: **Ollama HTTP API** (port 11434, for model inference) and **Node WebSocket** (port 18789, for remote shell execution). Both are direct connections managed by the Gateway.

---

## 8.1 How OpenClaw Cross-Machine Communication Works

OpenClaw uses a **hub-and-spoke** architecture, NOT independent gateways communicating via webhooks.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    OpenClaw Cross-Machine Architecture                    │
│                                                                          │
│  PC1 (192.168.1.106) — THE GATEWAY                                      │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │  Gateway (:18789)                                                │    │
│  │                                                                  │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │    │
│  │  │Coordinat.│  │Sr.Eng #1 │  │Quality   │  │DevOps    │       │    │
│  │  │(local)   │  │(local)   │  │(remote)  │  │(remote)  │ ...   │    │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘       │    │
│  │       │              │             │             │              │    │
│  │       ▼              ▼             ▼             ▼              │    │
│  │  ┌──────────────────────────────────────────────────────────┐  │    │
│  │  │              Model Provider Router                        │  │    │
│  │  │  ollama-local  → 127.0.0.1:11434  (PC1)                 │  │    │
│  │  │  ollama-pc2    → 192.168.1.112:11434  (PC2)              │  │    │
│  │  │  ollama-laptop → 192.168.1.113:11434  (Laptop)           │  │    │
│  │  │  anthropic     → api.anthropic.com  (Claude.ai)          │  │    │
│  │  └──────────────────────────────────────────────────────────┘  │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│       │                      │                     │                     │
│       │ Ollama HTTP API      │ Ollama HTTP API     │ Ollama HTTP API    │
│       ▼                      ▼                     ▼                     │
│  ┌──────────┐        ┌──────────────┐      ┌──────────────┐            │
│  │ Local    │        │ PC2          │      │ Laptop       │            │
│  │ Ollama   │        │ Ollama       │      │ Ollama       │            │
│  │ :11434   │        │ :11434       │      │ :11434       │            │
│  └──────────┘        └──────────────┘      └──────────────┘            │
│                             ▲                     ▲                     │
│                             │ Node (WebSocket)    │ Node (WebSocket)   │
│                       ┌─────┴──────┐        ┌─────┴──────┐            │
│                       │ PC2 Node   │        │ Laptop Node│            │
│                       │ (shell,    │        │ (shell,    │            │
│                       │  files)    │        │  files)    │            │
│                       └────────────┘        └────────────┘            │
└──────────────────────────────────────────────────────────────────────────┘
```

There are **two communication channels** between machines:

### Channel 1: Ollama HTTP API (Model Inference)

The Gateway on PC1 sends inference requests directly to remote Ollama instances via their HTTP API on port **11434**. This is how agents whose models run on PC2 or Laptop actually generate responses.

- **Protocol**: HTTP REST API
- **Port**: 11434
- **Direction**: PC1 Gateway → Remote Ollama (one-way; Gateway sends prompts, Ollama returns completions)
- **Configuration**: `models.providers` in `openclaw.json` on PC1

### Channel 2: Node WebSocket (Remote Shell Execution)

PC2 and Laptop run OpenClaw Nodes that connect to PC1's Gateway via WebSocket on port **18789**. This allows agents to execute shell commands on remote machines (e.g., run tests, check disk space, deploy code).

- **Protocol**: WebSocket
- **Port**: 18789 (PC1's Gateway port)
- **Direction**: Nodes connect TO the Gateway (outbound from PC2/Laptop)
- **Capabilities**: `system.run` (shell commands), `system.which` (binary lookup), file access

> **Important distinction**: Model inference goes via Ollama HTTP API (port 11434). Shell execution goes via Node WebSocket (port 18789). These are separate channels.

---

## 8.2 Verifying Ollama Connectivity

The Gateway needs to reach Ollama on all three machines. Test from PC1:

### Test Local Ollama (PC1)

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -Method GET
```

### Test PC2 Ollama

```powershell
Invoke-RestMethod -Uri "http://192.168.1.112:11434/api/tags" -Method GET
```

### Test Laptop Ollama

```powershell
Invoke-RestMethod -Uri "http://192.168.1.113:11434/api/tags" -Method GET
```

All should return a JSON response listing the models on that machine. If any fail, see [Section 8.5 - Troubleshooting](#85-troubleshooting-cross-machine-issues).

### Test Inference on Remote Ollama

```powershell
# Test a remote model on PC2
$body = @{
    model = "quality-agent"
    prompt = "Say hello in one sentence."
    stream = $false
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://192.168.1.112:11434/api/generate" `
  -Method POST `
  -Body $body `
  -ContentType "application/json"
```

---

## 8.3 Verifying Node Connectivity

### Check Connected Nodes on PC1

```powershell
# List all nodes (paired and pending)
openclaw nodes list

# Show only currently connected nodes
openclaw nodes list --connected
```

You should see PC2 and Laptop listed as connected nodes. Nodes are identified by **ID, display name, or IP address**.

> **Tip**: If PC2 and Laptop don't appear, check that their Node processes are running and can reach PC1:18789. See [Section 8.5 - Troubleshooting](#85-troubleshooting-cross-machine-issues).

### Test Shell Execution on Remote Nodes

From PC1, use `openclaw nodes run` to execute shell commands on remote machines:

```powershell
# Run a command on PC2's node (use node name, ID, or IP)
openclaw nodes run --node pc2 -- hostname

# Run a command on Laptop's node
openclaw nodes run --node laptop -- hostname
```

Each should return the hostname of the remote machine.

### Using `nodes invoke` for Structured Commands

For more structured interactions, use `openclaw nodes invoke` which calls specific command namespaces:

```powershell
# Run a shell command on PC2
openclaw nodes invoke --node pc2 --command system.run --params '{"command": "ollama list"}'

# Check device status on Laptop
openclaw nodes invoke --node laptop --command device.status

# Check what binaries are available on a node
openclaw nodes invoke --node pc2 --command system.which --params '{"binary": "ollama"}'
```

**Available command namespaces** (depends on what the node advertises):

| Namespace | Commands | Purpose |
|-----------|----------|---------|
| `system.*` | `system.run`, `system.which` | Shell execution, binary lookup |
| `device.*` | `device.status`, `device.info`, `device.health` | Node health and info |
| `notifications.*` | `notifications.list` | List notifications (mobile nodes) |

> The simplest approach: use `openclaw nodes run --node <name> -- <command>` for quick shell commands, and `openclaw nodes invoke` for structured commands.

### Per-Agent Exec Node Binding

To make an agent's shell commands automatically execute on a specific remote node (instead of on PC1), add `tools.exec.node` to the agent config:

```json
{
  "id": "quality-agent",
  "tools": {
    "exec": {
      "node": "pc2"
    }
  }
}
```

This means when the quality-agent runs a shell command (e.g., to check disk space or run tests), it executes on PC2 — not on PC1. See [`claude_openclaw_pc1.json`](current_config/claude_openclaw_pc1.json) for the complete config with all node bindings.

**Our agent → node mapping:**

| Agent | Model Inference (Ollama HTTP) | Shell Execution (Node WebSocket) |
|-------|-------------------------------|----------------------------------|
| coordinator | PC1 local (127.0.0.1:11434) | PC1 local (no node needed) |
| senior-engineer-1 | PC1 local | PC1 local |
| senior-engineer-2 | PC1 local | PC1 local |
| quality-agent | PC2 (192.168.1.112:11434) | PC2 node (`tools.exec.node: "pc2"`) |
| security-agent | PC2 (192.168.1.112:11434) | PC2 node (`tools.exec.node: "pc2"`) |
| devops-agent | Laptop (192.168.1.113:11434) | Laptop node (`tools.exec.node: "laptop"`) |
| monitoring-agent | Laptop (192.168.1.113:11434) | Laptop node (`tools.exec.node: "laptop"`) |

> **Known Issue ([#20669](https://github.com/openclaw/openclaw/issues/20669))**: The agent runtime's exec tool may not always honor the `tools.exec.node` binding — it can route to the gateway host instead. The CLI `openclaw nodes run --node ...` command always works correctly. If agent exec doesn't route to the node, use the Coordinator's dispatch skill to call `openclaw nodes run` directly as a workaround.

---

## 8.4 Network Configuration

### 8.4.1 Required Ports

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| **18789** | TCP | Inbound on PC1 only | Gateway — Nodes connect TO this |
| **11434** | TCP | Inbound on PC2 + Laptop | Ollama — Gateway connects TO this |

> **Note**: PC2 and Laptop do NOT need port 18789 open for inbound traffic. Their Nodes connect outbound to PC1. Only Ollama (11434) needs inbound access on PC2/Laptop.

### 8.4.2 Windows Firewall Rules

**On PC1** (Gateway — accepts Node connections):

```powershell
New-NetFirewallRule -DisplayName "OpenClaw Gateway" `
  -Direction Inbound -Protocol TCP -LocalPort 18789 `
  -Action Allow -Profile Private
```

**On PC2 and Laptop** (Ollama — accepts inference requests from PC1):

```powershell
New-NetFirewallRule -DisplayName "Ollama Remote Access" `
  -Direction Inbound -Protocol TCP -LocalPort 11434 `
  -Action Allow -Profile Private
```

**Verify the rules:**

```powershell
Get-NetFirewallRule -DisplayName "OpenClaw*","Ollama*" |
  Format-Table -Property DisplayName, Enabled, Direction, Action
```

### 8.4.3 Test Port Connectivity

From PC1:

```powershell
# Test Ollama on PC2
Test-NetConnection -ComputerName 192.168.1.112 -Port 11434

# Test Ollama on Laptop
Test-NetConnection -ComputerName 192.168.1.113 -Port 11434
```

From PC2 and Laptop:

```powershell
# Test Gateway on PC1
Test-NetConnection -ComputerName 192.168.1.106 -Port 18789
```

All should show `TcpTestSucceeded : True`.

### 8.4.4 Static IP Configuration (Recommended)

To prevent IP addresses from changing, set static IPs on each machine.

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

> **Note**: Adjust the gateway and DNS to match your router's address.

---

## 8.5 Troubleshooting Cross-Machine Issues

### Ollama Not Reachable from PC1

| Symptom | Cause | Fix |
|---------|-------|-----|
| Connection refused on :11434 | Ollama only listening on localhost | Set `OLLAMA_HOST=0.0.0.0:11434` and restart Ollama ([Chapter 04](04-ollama-setup.md#43-configure-ollama-for-network-access)) |
| Timeout on :11434 | Firewall blocking | Add inbound rule for port 11434 (Section 8.4.2) |
| Empty model list | Models not downloaded on remote | Run `ollama list` on the remote machine to check |
| Wrong models showing | Provider URL misconfigured | Check `models.providers` in `openclaw.json` — verify IP addresses |

### Node Not Connecting to Gateway

| Symptom | Cause | Fix |
|---------|-------|-----|
| Connection refused on :18789 | Gateway not running or bound to loopback | Start Gateway and set `gateway.bind` to `"lan"` |
| Auth rejected | Token mismatch | Ensure `OPENCLAW_GATEWAY_TOKEN` matches on all machines |
| Device not approved | Pairing not accepted | Run `openclaw devices list --pending` on PC1 and approve |
| `spawn /usr/bin/ssh ENOENT` | SSH path bug on Windows | Set `agents.defaults.sandbox.ssh.command` to `"ssh"` ([Chapter 03](03-openclaw-installation.md#36-verify-cross-machine-connectivity)) |

### Agent Can't Use Remote Model

| Symptom | Cause | Fix |
|---------|-------|-----|
| Model not found | Model name mismatch | Verify model name in `ollama list` on remote matches agent config |
| Model not in allowlist | `agents.defaults.models` missing entry | Add the model name to the allowlist in `openclaw.json` |
| Provider not configured | Missing provider in `models.providers` | Add the remote Ollama provider (see [Chapter 05](05-model-deployment.md#55-configure-model-providers-on-pc1s-gateway)) |
| Tool calling fails | Using `/v1` suffix | Remove `/v1` from the Ollama provider URL |

Check Gateway logs for detailed error messages:

```powershell
openclaw logs --follow
```

---

## 8.6 Latency Expectations

| Route | Expected Latency | Notes |
|-------|------------------|-------|
| PC1 agent → PC1 Ollama (local) | < 1 ms network | Localhost connection |
| PC1 agent → PC2 Ollama (remote) | 1-5 ms network | LAN HTTP request |
| PC1 agent → Laptop Ollama (remote) | 1-10 ms network | Depends on Wi-Fi vs Ethernet |
| Model inference (GPU, 7B) | 3-15 seconds | Depends on prompt length |
| Model inference (GPU, 32B) | 15-60 seconds | Large model, longer generation |
| Model inference (CPU fallback) | 30-180 seconds | Much slower, avoid if possible |
| Node shell command dispatch | 50-200 ms overhead | WebSocket + command execution |

> **The bottleneck is always model inference, not network latency.** A 32B model takes ~15-30 seconds to generate a response, making a few milliseconds of network overhead negligible.

---

## 8.7 Webhooks — For External Services Only

> **Clarification**: OpenClaw webhooks are designed for **external service integrations** (GitHub, Stripe, CI/CD systems, etc.), NOT for inter-machine agent communication. In our architecture, agents communicate via the Gateway's native multi-agent routing, and remote inference goes via Ollama HTTP API.

Webhooks are covered in [Chapter 09 - GitHub Integration](09-github-integration.md) where they're used to trigger agents from GitHub events (push, PR, etc.).

---

## 8.8 Checklist

- [ ] PC1 Gateway running and bound to LAN (`openclaw gateway status`)
- [ ] PC2 and Laptop Ollama bound to `0.0.0.0:11434` (not just localhost)
- [ ] Remote Ollama providers configured in `openclaw.json` on PC1
- [ ] `Invoke-RestMethod` to PC2:11434 and Laptop:11434 returns model list from PC1
- [ ] `openclaw models list` on PC1 shows models from all three providers
- [ ] PC2 and Laptop Nodes connected (`openclaw nodes list --connected` on PC1)
- [ ] Node shell execution works (`openclaw nodes run --node pc2 -- hostname`)
- [ ] `openclaw nodes invoke --node pc2 --command device.status` returns OK
- [ ] Per-agent `tools.exec.node` bindings set for remote agents (quality, security → pc2; devops, monitoring → laptop)
- [ ] Windows Firewall: port 18789 open on PC1, port 11434 open on PC2 + Laptop
- [ ] Static IPs configured (recommended)

---

Next: [Chapter 09 - GitHub Integration](09-github-integration.md)
