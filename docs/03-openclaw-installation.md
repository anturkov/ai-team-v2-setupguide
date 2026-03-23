# Chapter 03 - OpenClaw Installation

This chapter walks you through installing and configuring OpenClaw on all three machines. OpenClaw is the backbone of your distributed AI team — it handles all communication, file management, and orchestration.

---

## 3.1 What is OpenClaw?

OpenClaw is an open-source autonomous AI agent platform that runs locally on your machines. It bridges messaging platforms (Telegram, Discord, Slack, and others) to AI models via a **Gateway** process, and provides a rich set of capabilities:

- **Gateway**: The core process that bridges channels (Telegram, etc.) to AI agents — runs on each machine independently
- **Multi-Agent Routing**: Each Gateway can host multiple agents, each with its own workspace, model, and behavior
- **Skills**: Natural-language API integrations defined as `SKILL.md` files in agent workspaces
- **Webhooks**: HTTP endpoints for inter-machine agent communication
- **Memory**: Local SQLite-based RAG system for persistent agent knowledge
- **Model Discovery**: Auto-discovers Ollama models and supports multiple providers
- **Telegram Integration**: Native channel support for human interaction via BotFather bots
- **Health Monitoring**: Built-in diagnostics via `openclaw doctor`

> **Architecture**: Each machine runs its **own independent Gateway**. There is no central "cluster" or "node" model. Machines communicate via **webhooks** between their Gateways. PC1 hosts the Coordinator agent and the Telegram bot. PC2 and the Laptop each run their own Gateway with their specialized agents.

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│  PC1 (Gateway)      │     │  PC2 (Gateway)      │     │  Laptop (Gateway)   │
│  :18789             │◄───►│  :18789             │◄───►│  :18789             │
│                     │     │                     │     │                     │
│  Agents:            │     │  Agents:            │     │  Agents:            │
│  - Coordinator      │     │  - Quality Agent    │     │  - DevOps Agent     │
│  - Sr. Engineer #1  │     │  - Security Agent   │     │  - Monitoring Agent │
│  - Sr. Engineer #2  │     │  - (overflow)       │     │                     │
│                     │     │                     │     │                     │
│  Channels:          │     │  Webhooks:          │     │  Webhooks:          │
│  - Telegram Bot     │     │  - /hooks/agent     │     │  - /hooks/agent     │
│  Webhooks:          │     │                     │     │                     │
│  - /hooks/agent     │     │                     │     │                     │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
        ▲
        │ Telegram Bot API
        ▼
  ┌───────────┐
  │  Human    │
  │ (Telegram)│
  └───────────┘
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

### PowerShell Execution Policy

Allow script execution (needed for the installer):

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 3.3 Installation on PC1 (Primary Coordinator)

PC1 is your primary machine — it runs the Coordinator agent and the Telegram bot channel.

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

By default, the Gateway only listens on localhost. For cross-machine communication, set it to bind on LAN:

```powershell
openclaw config set gateway.bind "lan"
```

This makes the Gateway accessible at `http://192.168.1.106:18789` from other machines.

### Step 5: Set Gateway Authentication

Secure the Gateway so only your machines can access it:

```powershell
openclaw config set gateway.auth "token"
```

Generate a token (save this — you'll need it for PC2 and Laptop):

```powershell
openclaw doctor --generate-gateway-token
```

Or set one explicitly via environment variable on all machines:

```powershell
# Add to your PowerShell profile or system environment variables
[Environment]::SetEnvironmentVariable("OPENCLAW_GATEWAY_TOKEN", "your-secure-token-here", "User")
```

### Step 6: Configure Ollama Provider

Tell OpenClaw where to find your local Ollama instance:

```powershell
# Set the Ollama API key (enables auto-discovery)
[Environment]::SetEnvironmentVariable("OLLAMA_API_KEY", "ollama-local", "User")
```

Or configure explicitly in `openclaw.json`:

```json5
{
  models: {
    providers: {
      ollama: {
        baseUrl: "http://127.0.0.1:11434",  // NO /v1 suffix!
        apiKey: "ollama-local",
        api: "ollama"  // Use native API for reliable tool calling
      }
    }
  }
}
```

> **Important**: Do NOT add `/v1` to the Ollama URL — this activates OpenAI-compatible mode where tool calling is unreliable with local models.

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

> **Tip**: Keep this terminal open for now. We'll set it up as a Windows service in Section 3.6.

### Step 9: Open the Control Dashboard

In a new terminal:

```powershell
openclaw dashboard
```

This opens the Control UI in your browser at `http://localhost:18789` where you can monitor agents and channels.

---

## 3.4 Installation on PC2 (Secondary Agents)

### Step 1: Install OpenClaw

Open PowerShell **as Administrator** on PC2:

```powershell
iwr -useb https://openclaw.ai/install.ps1 | iex
```

### Step 2: Verify Installation

```powershell
openclaw --version
```

### Step 3: Run First-Time Setup

```powershell
openclaw onboard --install-daemon
```

When prompted for channels, you can skip them — PC2 agents receive work via webhooks from PC1, not directly from Telegram.

### Step 4: Configure Gateway for LAN Access

```powershell
openclaw config set gateway.bind "lan"
```

### Step 5: Set the Same Gateway Token

Use the same token you generated for PC1:

```powershell
[Environment]::SetEnvironmentVariable("OPENCLAW_GATEWAY_TOKEN", "your-secure-token-here", "User")
```

### Step 6: Configure Ollama Provider

```powershell
[Environment]::SetEnvironmentVariable("OLLAMA_API_KEY", "ollama-local", "User")
```

### Step 7: Configure Webhooks for Cross-Machine Communication

Enable the webhook endpoint so PC1's Coordinator can send tasks to agents on PC2:

```powershell
openclaw config set hooks.enabled true
openclaw config set hooks.token "your-webhook-secret-here"
openclaw config set hooks.path "/hooks"
```

The webhook endpoint will be available at `http://192.168.1.112:18789/hooks/agent`.

### Step 8: Validate and Start

```powershell
openclaw doctor --fix
openclaw gateway run --bind lan
```

---

## 3.5 Installation on Laptop (Monitoring & Light Duties)

### Step 1: Install OpenClaw

Open PowerShell **as Administrator** on the Laptop:

```powershell
iwr -useb https://openclaw.ai/install.ps1 | iex
```

### Step 2: Verify Installation

```powershell
openclaw --version
```

### Step 3: Run First-Time Setup

```powershell
openclaw onboard --install-daemon
```

### Step 4: Configure Gateway for LAN Access

```powershell
openclaw config set gateway.bind "lan"
```

### Step 5: Set the Same Gateway Token

```powershell
[Environment]::SetEnvironmentVariable("OPENCLAW_GATEWAY_TOKEN", "your-secure-token-here", "User")
```

### Step 6: Configure Ollama Provider

```powershell
[Environment]::SetEnvironmentVariable("OLLAMA_API_KEY", "ollama-local", "User")
```

### Step 7: Configure Webhooks

```powershell
openclaw config set hooks.enabled true
openclaw config set hooks.token "your-webhook-secret-here"
openclaw config set hooks.path "/hooks"
```

### Step 8: Validate and Start

```powershell
openclaw doctor --fix
openclaw gateway run --bind lan
```

---

## 3.6 Verify Cross-Machine Connectivity

Once all three machines are running, verify they can reach each other.

### Test Gateway Connectivity

From PC1, probe the other Gateways:

```powershell
# Probe PC2's Gateway
openclaw gateway probe --url http://192.168.1.112:18789

# Probe Laptop's Gateway
openclaw gateway probe --url http://192.168.1.113:18789
```

From PC2 and Laptop, probe PC1:

```powershell
openclaw gateway probe --url http://192.168.1.106:18789
```

### Test Webhook Delivery

From PC1, send a test webhook to PC2:

```powershell
# Use curl or Invoke-WebRequest to hit the webhook endpoint
Invoke-RestMethod -Uri "http://192.168.1.112:18789/hooks/wake" `
  -Method POST `
  -Headers @{ "Authorization" = "Bearer your-webhook-secret-here" }
```

You should get an HTTP 200 response.

### Run Diagnostics on All Machines

```powershell
openclaw doctor
```

If any machine is unreachable, check:
1. Is the Gateway running? (`openclaw gateway status`)
2. Is it bound to LAN? (`openclaw config get gateway.bind` — should be `"lan"`)
3. Can you ping the machine? (`ping 192.168.1.112`)
4. Is the port open? (`Test-NetConnection -ComputerName 192.168.1.112 -Port 18789`)
5. See [Chapter 17 - Troubleshooting](17-troubleshooting.md) for more

---

## 3.7 Install as a Windows Service

So OpenClaw starts automatically on boot and runs in the background.

### On Each Machine — Install the Gateway as a Service

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
