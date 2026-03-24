# Chapter 03 - OpenClaw Installation

This chapter walks you through installing and configuring OpenClaw on all three machines. OpenClaw is the backbone of your distributed AI team — it handles all communication, file management, and orchestration.

---

## 3.1 What is OpenClaw?

OpenClaw is an open-source autonomous AI agent platform that runs locally on your machines. It bridges messaging platforms (Telegram, Discord, Slack, and others) to AI models via a **Gateway** process, and provides a rich set of capabilities:

- **Gateway**: The single control-plane process that manages all agents, channels, and model routing — runs on **one machine** (PC1)
- **Nodes**: Companion processes on secondary machines that connect TO the Gateway via WebSocket — they provide a command surface (shell execution, file access) on remote hardware
- **Multi-Agent Routing**: The Gateway hosts multiple agents, each with its own workspace, model provider, and behavior
- **Skills**: Natural-language API integrations defined as `SKILL.md` files in agent workspaces
- **Remote Ollama Providers**: The Gateway connects to Ollama instances on remote machines via their HTTP API (port 11434) to run inference on distributed hardware
- **Memory**: Local SQLite-based RAG system for persistent agent knowledge
- **Telegram Integration**: Native channel support for human interaction via BotFather bots
- **Health Monitoring**: Built-in diagnostics via `openclaw doctor`

> **Architecture — Hub and Spoke**: OpenClaw uses a **single Gateway** model. PC1 runs the Gateway — it is the sole control plane. **All agents are registered on PC1's Gateway**, even those whose models run on remote Ollama instances. PC2 and the Laptop run as **Nodes** that connect to PC1's Gateway via WebSocket, providing remote shell execution. The Gateway accesses models on PC2/Laptop by connecting directly to their Ollama HTTP API (port 11434). **There is no "gateway per machine" — only one Gateway exists.**

```
                    ┌───────────┐
                    │  Human    │
                    │ (Telegram)│
                    └─────┬─────┘
                          │ Telegram Bot API
                          ▼
┌──────────────────────────────────────────────────────────┐
│  PC1 (192.168.1.106) — THE GATEWAY (:18789)              │
│                                                          │
│  All Agents (registered here):                           │
│  ├── Coordinator         → ollama-local (PC1)            │
│  ├── Senior Engineer #1  → ollama-local (PC1)            │
│  ├── Senior Engineer #2  → ollama-local (PC1)            │
│  ├── Quality Agent       → ollama-pc2 (PC2:11434)        │
│  ├── Security Agent      → ollama-pc2 (PC2:11434)        │
│  ├── DevOps Agent        → ollama-laptop (Laptop:11434)  │
│  ├── Monitoring Agent    → ollama-laptop (Laptop:11434)  │
│  └── External Consultant → Anthropic API                 │
│                                                          │
│  Channels: Telegram Bot                                  │
└─────────┬────────────────────────────┬───────────────────┘
          │ Node (WebSocket)           │ Node (WebSocket)
          │ + Ollama API (:11434)      │ + Ollama API (:11434)
          ▼                            ▼
┌───────────────────────┐   ┌───────────────────────────┐
│  PC2 (192.168.1.112)  │   │  Laptop (192.168.1.113)   │
│  OpenClaw Node        │   │  OpenClaw Node            │
│  Ollama :11434        │   │  Ollama :11434            │
│  - quality-agent      │   │  - devops-agent           │
│  - security-agent     │   │  - monitoring-agent       │
│  - codellama:7b       │   │                           │
└───────────────────────┘   └───────────────────────────┘
```

---

## 3.2 Prerequisites

Before installing OpenClaw, ensure the following on **each machine**:

### Node.js 22+

OpenClaw requires Node.js 22 or later. Download from [nodejs.org](https://nodejs.org) or install via winget:

```powershell
winget install OpenJS.NodeJS.LTS
```

Verify:

```powershell
node --version   # Should show v22.x.x or higher
npm --version
```

### Git

```powershell
winget install Git.Git
```

Verify:

```powershell
git --version
```

### OpenSSH Client

OpenClaw's `gateway probe` command uses SSH internally. Windows 11 ships with OpenSSH, but it must be on your PATH. Verify:

```powershell
where.exe ssh
# Expected: C:\Windows\System32\OpenSSH\ssh.exe
```

If `where.exe ssh` returns nothing, enable the OpenSSH Client feature:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

> **Known Issue (OpenClaw 2026.3.x):** OpenClaw hardcodes the SSH path as `/usr/bin/ssh` (Unix). Even if SSH is installed, `gateway probe` will fail with `spawn /usr/bin/ssh ENOENT`. See [Section 3.6](#36-verify-cross-machine-connectivity) for the required workaround.

### PowerShell Execution Policy

Allow script execution (needed for the installer):

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 3.3 Installation on PC1 (The Gateway — Control Plane)

PC1 is the **only machine that runs the Gateway**. It hosts all agents, the Telegram channel, and connects to remote Ollama instances on PC2 and Laptop. This is the brain of the operation.

### Step 1: Install OpenClaw

Open PowerShell **as Administrator**:

```powershell
iwr -useb https://openclaw.ai/install.ps1 | iex
```

Alternatively, install via npm:

```powershell
npm install -g openclaw@latest
```

### Step 2: Verify Installation

Close and reopen PowerShell, then run:

```powershell
openclaw --version
```

You should see `OpenClaw 2026.x.x`. If you get "command not found", close and reopen PowerShell — the installer updates your PATH.

### Step 3: Run First-Time Setup

Run the guided onboarding wizard:

```powershell
openclaw onboard --install-daemon
```

This walks you through:
- Setting your AI provider (select Ollama for local models)
- Configuring your first channel (Telegram — you can skip this for now and set it up in [Chapter 07](07-telegram-bot-setup.md))
- Creating the default agent workspace at `~/.openclaw/workspace`
- Installing the Gateway as a background service (via `--install-daemon`)

The wizard creates `~/.openclaw/openclaw.json` — this is the **single configuration file** for your entire OpenClaw instance (JSON5 format, comments allowed).

### Step 4: Configure Gateway for LAN Access

By default, the Gateway only listens on localhost. Bind it to LAN so Nodes on PC2 and Laptop can connect:

```powershell
openclaw config set gateway.bind "lan"
```

This makes the Gateway accessible at `http://192.168.1.106:18789` from other machines.

### Step 5: Set Gateway Authentication

Secure the Gateway so only your machines can access it:

```powershell
openclaw config set gateway.auth "token"
```

Generate a token (save this — you'll need it for PC2 and Laptop Nodes):

```powershell
openclaw doctor --generate-gateway-token
```

Or set one explicitly via environment variable:

```powershell
# Add to your PowerShell profile or system environment variables
[Environment]::SetEnvironmentVariable("OPENCLAW_GATEWAY_TOKEN", "your-secure-token-here", "User")
```

### Step 6: Configure Model Providers (Local + Remote Ollama)

This is the key step for distributed inference. The Gateway on PC1 needs to know about Ollama instances on **all three machines**. Edit `~/.openclaw/openclaw.json`:

```json5
{
  models: {
    providers: {
      // PC1's local Ollama (coordinator, senior engineers)
      "ollama-local": {
        baseUrl: "http://127.0.0.1:11434",  // NO /v1 suffix!
        apiKey: "ollama-local",
        api: "ollama"
      },
      // PC2's remote Ollama (quality agent, security agent)
      "ollama-pc2": {
        baseUrl: "http://192.168.1.112:11434",  // NO /v1 suffix!
        apiKey: "ollama-pc2",
        api: "ollama"
      },
      // Laptop's remote Ollama (devops agent, monitoring agent)
      "ollama-laptop": {
        baseUrl: "http://192.168.1.113:11434",  // NO /v1 suffix!
        apiKey: "ollama-laptop",
        api: "ollama"
      },
      // Claude.ai for External Consultant
      anthropic: {
        // API key set via: openclaw models auth paste-token --provider anthropic
      }
    }
  }
}
```

> **Important**: Do NOT add `/v1` to any Ollama URL — this activates OpenAI-compatible mode where tool calling is unreliable with local models.

> **Prerequisite**: Ollama must be configured to listen on `0.0.0.0:11434` on PC2 and Laptop (see [Chapter 04, Section 4.3](04-ollama-setup.md#43-configure-ollama-for-network-access)).

### Step 7: Validate Configuration

Run the diagnostic tool:

```powershell
openclaw doctor
```

This runs 12+ health checks and reports OK, WARN, or FAIL for each. Fix any issues it flags — use `--fix` for auto-repair:

```powershell
openclaw doctor --fix
```

### Step 8: Start the Gateway

```powershell
# Start in foreground for initial testing
openclaw gateway run --bind lan

# You should see output like:
# [INFO] OpenClaw Gateway 2026.x.x starting...
# [INFO] Listening on http://0.0.0.0:18789
# [INFO] Ready.
```

> **Tip**: Keep this terminal open for now. We'll set it up as a Windows service in Section 3.7.

### Step 9: Open the Control Dashboard

In a new terminal:

```powershell
openclaw dashboard
```

This opens the Control UI in your browser at `http://localhost:18789` where you can monitor agents and channels.

---

## 3.4 Installation on PC2 (Node + Ollama Host)

PC2 does **NOT** run its own Gateway. It runs two things:
1. **Ollama** — serving the quality-agent and security-agent models (the Gateway on PC1 connects to this directly via `http://192.168.1.112:11434`)
2. **OpenClaw Node** — a lightweight process that connects to PC1's Gateway via WebSocket, providing remote shell execution capabilities

### Step 1: Install OpenClaw

Open PowerShell **as Administrator** on PC2:

```powershell
iwr -useb https://openclaw.ai/install.ps1 | iex
```

### Step 2: Verify Installation

```powershell
openclaw --version
```

### Step 3: Connect as a Node to PC1's Gateway

Instead of running `openclaw onboard` (which sets up a local Gateway), connect to PC1's Gateway as a Node:

```powershell
# Set the Gateway token (must match PC1's token)
[Environment]::SetEnvironmentVariable("OPENCLAW_GATEWAY_TOKEN", "your-secure-token-here", "User")
```

> **Node pairing**: When PC2's node first connects, PC1's Gateway creates a **device pairing request**. You must approve the pairing on PC1 via the dashboard or CLI. See Step 5 below.

### Step 4: Start the Node

```powershell
# Connect to PC1's Gateway as a node
openclaw node connect --gateway ws://192.168.1.106:18789 --token "your-secure-token-here"
```

You should see output confirming the WebSocket connection to PC1's Gateway.

> **Alternative**: Use the [OpenClaw Windows Node companion app](https://github.com/openclaw/openclaw-windows-node) for a GUI-based node that runs in the system tray.

### Step 5: Approve the Node on PC1

On PC1, approve the new node pairing:

```powershell
# List pending device pairing requests
openclaw devices list --pending

# Approve PC2's node
openclaw devices approve <device-id>
```

Or approve via the dashboard at `http://localhost:18789`.

### Step 6: Verify Ollama is Accessible from PC1

From PC1, test that you can reach PC2's Ollama:

```powershell
Invoke-RestMethod -Uri "http://192.168.1.112:11434/api/tags" -Method GET
```

If this returns a JSON response with the model list, the connection works.

### Step 7: Validate

On PC2, verify the node is connected:

```powershell
openclaw node status
```

On PC1, verify PC2 appears as a node:

```powershell
openclaw devices list
```

---

## 3.5 Installation on Laptop (Node + Ollama Host)

The Laptop setup is identical to PC2 — it runs Ollama locally and connects as a Node to PC1's Gateway.

### Step 1: Install OpenClaw

Open PowerShell **as Administrator** on the Laptop:

```powershell
iwr -useb https://openclaw.ai/install.ps1 | iex
```

### Step 2: Verify Installation

```powershell
openclaw --version
```

### Step 3: Set Gateway Token

```powershell
[Environment]::SetEnvironmentVariable("OPENCLAW_GATEWAY_TOKEN", "your-secure-token-here", "User")
```

### Step 4: Start the Node

```powershell
openclaw node connect --gateway ws://192.168.1.106:18789 --token "your-secure-token-here"
```

### Step 5: Approve the Node on PC1

On PC1:

```powershell
openclaw devices list --pending
openclaw devices approve <device-id>
```

### Step 6: Verify Ollama is Accessible from PC1

From PC1:

```powershell
Invoke-RestMethod -Uri "http://192.168.1.113:11434/api/tags" -Method GET
```

### Step 7: Validate

On Laptop:

```powershell
openclaw node status
```

On PC1:

```powershell
openclaw devices list
# Should show both PC2 and Laptop as connected nodes
```

---

## 3.6 Verify Cross-Machine Connectivity

Once PC1's Gateway is running and PC2/Laptop are connected as Nodes with Ollama running, verify everything works.

### Step 1: Fix the SSH Path (Required on Windows)

> **Critical:** OpenClaw 2026.3.x hardcodes the SSH binary path as `/usr/bin/ssh` (a Unix path). On Windows this causes certain commands to fail with:
> ```
> [openclaw] Uncaught exception: Error: spawn /usr/bin/ssh ENOENT
> ```
> Apply this fix on **PC1** (the Gateway machine):

```powershell
openclaw config set agents.defaults.sandbox.ssh.command "ssh"
```

Verify:

```powershell
openclaw config get agents.defaults.sandbox.ssh.command
# Should return: ssh
```

### Step 2: Verify Network Connectivity

From PC1, confirm you can reach the Ollama instances on PC2 and Laptop:

```powershell
# Test Ollama on PC2
Test-NetConnection -ComputerName 192.168.1.112 -Port 11434

# Test Ollama on Laptop
Test-NetConnection -ComputerName 192.168.1.113 -Port 11434
```

From PC2 and Laptop, confirm you can reach PC1's Gateway:

```powershell
# Test Gateway on PC1
Test-NetConnection -ComputerName 192.168.1.106 -Port 18789
```

All should return `TcpTestSucceeded : True`.

### Step 3: Verify Remote Ollama Access

From PC1, test that the Gateway can reach remote Ollama instances:

```powershell
# Test PC2's Ollama API
Invoke-RestMethod -Uri "http://192.168.1.112:11434/api/tags" -Method GET

# Test Laptop's Ollama API
Invoke-RestMethod -Uri "http://192.168.1.113:11434/api/tags" -Method GET
```

Both should return a JSON response with the models on that machine.

### Step 4: Verify Node Connections

On PC1, check that both Nodes are connected:

```powershell
openclaw devices list
```

You should see PC2 and Laptop listed as connected devices.

### Step 5: Verify Model Providers

On PC1, check that all Ollama providers are accessible:

```powershell
openclaw models status
```

This should show models from `ollama-local`, `ollama-pc2`, and `ollama-laptop` providers.

### Step 6: Run Diagnostics

```powershell
openclaw doctor
```

### Troubleshooting Connectivity Issues

| Check | Command (run on PC1) | Expected |
|-------|---------------------|----------|
| Gateway running? | `openclaw gateway status` | Shows "running" with PID |
| Bound to LAN? | `openclaw config get gateway.bind` | `"lan"` |
| Ping PC2? | `ping 192.168.1.112` | Reply received |
| Ping Laptop? | `ping 192.168.1.113` | Reply received |
| PC2 Ollama reachable? | `Test-NetConnection -ComputerName 192.168.1.112 -Port 11434` | `TcpTestSucceeded: True` |
| Laptop Ollama reachable? | `Test-NetConnection -ComputerName 192.168.1.113 -Port 11434` | `TcpTestSucceeded: True` |
| Nodes connected? | `openclaw devices list` | PC2 and Laptop listed |
| SSH path fixed? | `openclaw config get agents.defaults.sandbox.ssh.command` | `"ssh"` |

**If Ollama is not reachable on port 11434**, check:
1. Ollama is running on the remote machine (`ollama list`)
2. `OLLAMA_HOST` is set to `0.0.0.0:11434` (see [Chapter 04](04-ollama-setup.md#43-configure-ollama-for-network-access))
3. Firewall allows inbound on port 11434:

```powershell
# Run on PC2 and Laptop
New-NetFirewallRule -DisplayName "Ollama Remote Access" `
  -Direction Inbound -Protocol TCP -LocalPort 11434 `
  -Action Allow -Profile Private
```

**If the Gateway is not reachable on port 18789** (Nodes can't connect):

```powershell
# Run on PC1
New-NetFirewallRule -DisplayName "OpenClaw Gateway" `
  -Direction Inbound -Protocol TCP -LocalPort 18789 `
  -Action Allow -Profile Private
```

See [Chapter 17 - Troubleshooting](17-troubleshooting.md) for more

---

## 3.7 Install as a Windows Service

So OpenClaw starts automatically on boot and runs in the background.

### On PC1 — Install the Gateway as a Service

If you used `--install-daemon` during onboarding, this is already done. Otherwise:

```powershell
# Install the Gateway as a Windows scheduled task
openclaw gateway install --port 18789

# Start the service
openclaw gateway start

# Verify it's running
openclaw gateway status
```

**To manage the Gateway service later:**

```powershell
openclaw gateway stop
openclaw gateway restart
openclaw gateway uninstall
```

> **Note**: On Windows, the service uses `schtasks` (Scheduled Tasks). If admin access is denied, it falls back to a Startup-folder login item. You can verify in Task Scheduler that the "OpenClaw Gateway" task exists.

### On PC2 and Laptop — Auto-Start Node + Ollama

PC2 and Laptop don't run a Gateway — they need Ollama and the Node to start automatically.

**Ollama** already auto-starts as a Windows service after installation.

**For the Node**, create a scheduled task to auto-connect on login:

```powershell
# Create a startup script
$script = @'
openclaw node connect --gateway ws://192.168.1.106:18789 --token "your-secure-token-here"
'@
$script | Set-Content -Path "$env:USERPROFILE\openclaw-node-start.ps1"

# Register as a login startup task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -File $env:USERPROFILE\openclaw-node-start.ps1"
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "OpenClaw Node" -Action $action -Trigger $trigger -Description "Connect to OpenClaw Gateway on PC1"
```

> **After this step**, you can close the terminal running the Gateway in the foreground. The service keeps it running in the background.

---

## 3.8 Updating OpenClaw

When a new version is released, run on each machine:

```powershell
npm update -g openclaw
```

Or reinstall:

```powershell
npm install -g openclaw@latest
```

After updating, restart the Gateway service:

```powershell
openclaw gateway restart
```

Run diagnostics to check for any config migrations:

```powershell
openclaw doctor --fix
```

---

## 3.9 Configuration File Reference

OpenClaw uses a single JSON5 configuration file at `~/.openclaw/openclaw.json`. Key sections:

| Section | Purpose |
|---------|---------|
| `gateway` | Port, bind mode (`loopback`/`lan`/`tailnet`), auth settings |
| `agents` | Agent definitions, defaults, workspace paths |
| `channels` | Channel providers (Telegram, Discord, etc.) |
| `models` | Model providers (Ollama, Anthropic, OpenAI, custom) |
| `hooks` | Webhook configuration for inter-machine communication |
| `bindings` | Multi-agent routing rules (which channel traffic goes to which agent) |
| `session` | Conversation continuity and isolation settings |
| `cron` | Scheduled job automation |
| `identity` | Bot name, emoji, avatar |
| `env` | Environment variables and secrets |

### Directory Structure

After installation, your OpenClaw home looks like this:

```
~/.openclaw/
├── openclaw.json              # Main configuration file (JSON5)
├── workspace/                 # Default agent workspace
│   ├── SOUL.md               # Agent personality/instructions
│   ├── AGENTS.md             # Agent skill references
│   ├── USER.md               # User-specific context
│   ├── skills/               # Agent skills (SKILL.md files)
│   └── memory/               # Agent memory (daily notes, MEMORY.md)
├── agents/                    # Per-agent directories
│   └── <agentId>/
│       ├── agent/            # Auth profiles, credentials
│       └── sessions/         # Conversation sessions
├── credentials/               # Credential storage (chmod 600)
├── skills/                    # Shared skills across all agents
└── gateway.pid                # PID file for the running Gateway
```

---

## 3.10 Useful Commands Reference

| Command | Description |
|---------|-------------|
| `openclaw onboard` | Guided first-time setup wizard |
| `openclaw config get <path>` | Read a config value |
| `openclaw config set <path> <value>` | Set a config value |
| `openclaw config validate` | Validate config against schema |
| `openclaw config file` | Print the active config file path |
| `openclaw gateway run` | Start Gateway in foreground |
| `openclaw gateway install` | Install Gateway as Windows service |
| `openclaw gateway start` | Start the installed service |
| `openclaw gateway stop` | Stop the running service |
| `openclaw gateway restart` | Restart the service |
| `openclaw gateway status` | Show service state and config |
| `openclaw gateway probe` | Debug connectivity to a Gateway |
| `openclaw gateway health` | Probe wellness via WebSocket RPC |
| `openclaw gateway discover` | Scan for Gateways via mDNS |
| `openclaw gateway uninstall` | Remove the service |
| `openclaw doctor` | Run 12+ health checks with auto-fix |
| `openclaw doctor --fix` | Auto-repair common issues |
| `openclaw agents list` | Display all configured agents |
| `openclaw agents add <id>` | Create a new agent |
| `openclaw agents delete <id>` | Remove an agent |
| `openclaw agents bind` | Route channel traffic to an agent |
| `openclaw agents unbind` | Remove channel routing |
| `openclaw models status` | Check model availability |
| `openclaw channels list` | View configured channels |
| `openclaw dashboard` | Open Control UI in browser |
| `openclaw logs` | Tail Gateway logs |
| `openclaw reset` | Reset local config/state (keeps CLI) |

---

## 3.11 Key Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `OPENCLAW_HOME` | Override home directory for all paths | System home |
| `OPENCLAW_STATE_DIR` | Override state directory | `~/.openclaw` |
| `OPENCLAW_CONFIG_PATH` | Point to a specific config file | `~/.openclaw/openclaw.json` |
| `OPENCLAW_GATEWAY_PORT` | Override Gateway port | `18789` |
| `OPENCLAW_GATEWAY_TOKEN` | Token-based auth via env | — |
| `OPENCLAW_HOST` | Bind address override | — |
| `OPENCLAW_LOG_LEVEL` | Logging level (`debug`, `info`, etc.) | `info` |
| `OLLAMA_API_KEY` | Enables Ollama auto-discovery | — |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token fallback | — |

---

## 3.12 Checklist

- [ ] Node.js 22+ installed on PC1, PC2, and Laptop
- [ ] OpenClaw installed on all machines (`openclaw --version` works)
- [ ] `openclaw onboard` completed on all machines
- [ ] Gateway bound to LAN on all machines (`gateway.bind` = `"lan"`)
- [ ] Gateway token set consistently across all machines
- [ ] Webhook endpoints enabled on PC2 and Laptop (`hooks.enabled` = `true`)
- [ ] Ollama provider configured on all machines
- [ ] `openclaw doctor` passes on all machines
- [ ] Gateway running on all machines (`openclaw gateway status`)
- [ ] Cross-machine Gateway probes succeed from PC1
- [ ] Webhook delivery test succeeds (PC1 → PC2, PC1 → Laptop)
- [ ] Gateway installed as Windows service on all machines

---

Next: [Chapter 04 - Ollama Setup](04-ollama-setup.md)
