# Chapter 06 - Team Configuration

This chapter configures all agents, enables agent-to-agent communication, and sets up the team hierarchy. We follow the **phased approach**: get PC1 (ATU-RIG02) working first, then add PC2 (ATURIG01) and Laptop (LTATU01).

## Workspace Architecture: Separate Workspaces + Shared `cwd`

Each agent has its **own workspace directory** with personalized bootstrap files (SOUL.md, AGENTS.md, IDENTITY.md, etc.). All agents share the **same `cwd` (current working directory)** — the actual project they're building together.

```
~/.openclaw/
├── workspace-coordinator/       ← Coordinator's persona files (SOUL.md, AGENTS.md, etc.)
├── workspace-senior-eng-1/      ← Senior Engineer 1's persona files
├── workspace-senior-eng-2/      ← Senior Engineer 2's persona files
├── workspace-quality/           ← Quality Agent's persona files
├── workspace-security/          ← Security Agent's persona files
├── workspace-devops/            ← DevOps Agent's persona files
├── workspace-monitoring/        ← Monitoring Agent's persona files
└── agents/                      ← Agent session stores (agentDir — NEVER share)
    ├── coordinator/agent/
    ├── senior-engineer-1/agent/
    └── ...

/home/<user>/project/            ← Shared cwd — ALL agents work here
```

**Why this pattern?**
- Each agent loads its own personality and instructions from its workspace at session start
- All agents read/write the same project files via the shared `cwd`
- No bootstrap file conflicts (OpenClaw only loads MD files from workspace root)
- Fast context — agents see each other's code changes immediately
- `agentDir` stays separate per agent (session history, auth — must never be shared)

Pre-built workspace files for all 7 agents are provided in this repo under `workspace-files/`. See [Section 6.17](#617-deploy-workspace-files) for deployment instructions.

---

## Phase 1: PC1 (ATU-RIG02) — Coordinator + Senior Engineers

This phase gets the core team working: Coordinator receives Telegram messages, dispatches to Senior Engineers, gets results back, replies via Telegram.

---

### 6.1 Register Agents on PC1 (ATU-RIG02)

Run all commands **inside WSL2** on PC1:

```bash
# Register all 3 Phase 1 agents
openclaw agents add coordinator --workspace ~/.openclaw/workspace-coordinator --non-interactive
openclaw agents add senior-engineer-1 --workspace ~/.openclaw/workspace-senior-eng-1 --non-interactive
openclaw agents add senior-engineer-2 --workspace ~/.openclaw/workspace-senior-eng-2 --non-interactive

# Verify
openclaw agents list
```

You should see 3 agents listed.

---

### 6.2 Edit `openclaw.json` — Phase 1 Config

The `openclaw.json` file lives at `~/.openclaw/openclaw.json` inside WSL2. Open it:

```bash
nano ~/.openclaw/openclaw.json
```

Or from Windows, the file is at:
```
\\wsl$\Ubuntu-24.04\home\<username>\.openclaw\openclaw.json
```

Here is the **complete Phase 1 configuration**. Merge these sections into your existing `openclaw.json`:

```json
{
  "models": {
    "providers": {
      "ollama": {
        "baseUrl": "http://localhost:11434",
        "apiKey": "ollama",
        "api": "ollama"
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "ollama/qwen3-coder:30b-a3b"
      },
      "models": {
        "ollama/qwen3-coder:30b-a3b": {}
      },
      "workspace": "~/.openclaw/workspace",
      "timeoutSeconds": 600,
      "maxConcurrent": 3,
      "subagents": {
        "runTimeoutSeconds": 900,
        "archiveAfterMinutes": 60,
        "maxSpawnDepth": 1,
        "maxChildrenPerAgent": 5,
        "maxConcurrent": 3
      }
    },
    "list": [
      {
        "id": "coordinator",
        "name": "coordinator",
        "default": true,
        "workspace": "~/.openclaw/workspace-coordinator",
        "agentDir": "~/.openclaw/agents/coordinator/agent",
        "cwd": "/home/<username>/project"
      },
      {
        "id": "senior-engineer-1",
        "name": "senior-engineer-1",
        "workspace": "~/.openclaw/workspace-senior-eng-1",
        "agentDir": "~/.openclaw/agents/senior-engineer-1/agent",
        "cwd": "/home/<username>/project"
      },
      {
        "id": "senior-engineer-2",
        "name": "senior-engineer-2",
        "workspace": "~/.openclaw/workspace-senior-eng-2",
        "agentDir": "~/.openclaw/agents/senior-engineer-2/agent",
        "cwd": "/home/<username>/project"
      }
    ]
  },
  "tools": {
    "profile": "coding",
    "exec": {
      "security": "full",
      "ask": "off"
    },
    "agentToAgent": {
      "enabled": true,
      "allow": [
        "coordinator",
        "senior-engineer-1",
        "senior-engineer-2"
      ]
    }
  },
  "session": {
    "agentToAgent": {
      "maxPingPongTurns": 3
    },
    "sendPolicy": {
      "rules": [],
      "default": "allow"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "YOUR_BOT_TOKEN_HERE",
      "dmPolicy": "pairing",
      "groups": {
        "*": {
          "requireMention": true
        }
      }
    }
  },
  "bindings": [
    {
      "agentId": "coordinator",
      "match": {
        "channel": "telegram"
      }
    }
  ],
  "gateway": {
    "port": 18789,
    "bind": "lan",
    "auth": {
      "mode": "token"
    }
  }
}
```

**Important notes:**
- Replace `YOUR_BOT_TOKEN_HERE` with your actual Telegram bot token (see [Chapter 07](07-telegram-bot-setup.md))
- Replace `/home/<username>/project` with your actual shared project path inside WSL2
- Each agent MUST have all 5 fields: `id`, `name`, `workspace`, `agentDir`, `cwd`
- **`cwd`** points ALL agents to the same project directory — this is how they share code
- **`workspace`** holds each agent's persona files (SOUL.md, AGENTS.md, etc.) — unique per agent
- **`agentDir`** stores sessions and auth — NEVER share between agents
- The `bindings` section routes ALL Telegram messages to the coordinator
- `agentToAgent.enabled: true` is the master switch for inter-agent communication
- `agentToAgent.allow` lists which agents can participate — add all of them

> **See [`docs/current_config/openclaw_pc1_phase1.json`](current_config/openclaw_pc1_phase1.json)** for the complete ready-to-use config file.

---

### 6.3 Create Agent Directories

```bash
# Create workspace directories
mkdir -p ~/.openclaw/workspace-coordinator
mkdir -p ~/.openclaw/workspace-senior-eng-1
mkdir -p ~/.openclaw/workspace-senior-eng-2

# Create agentDir directories
mkdir -p ~/.openclaw/agents/coordinator/agent
mkdir -p ~/.openclaw/agents/senior-engineer-1/agent
mkdir -p ~/.openclaw/agents/senior-engineer-2/agent
```

---

### 6.4 Deploy Workspace Files (Phase 1)

Each agent needs 8 MD files in its workspace directory. Pre-built files for all agents are provided in this repo under `workspace-files/`. Deploy the Phase 1 agent files:

```bash
# Copy all 8 MD files for each Phase 1 agent
cp workspace-files/coordinator/*.md ~/.openclaw/workspace-coordinator/
cp workspace-files/senior-engineer-1/*.md ~/.openclaw/workspace-senior-eng-1/
cp workspace-files/senior-engineer-2/*.md ~/.openclaw/workspace-senior-eng-2/
```

> **What's in each workspace?** 8 files: `SOUL.md` (personality), `AGENTS.md` (team roster), `IDENTITY.md` (name/role/machine), `USER.md` (user preferences), `TOOLS.md` (available tools), `HEARTBEAT.md` (periodic tasks), `BOOTSTRAP.md` (first-run checklist), `MEMORY.md` (long-term memory placeholder). See [`workspace-files/`](../workspace-files/) for the complete set.

**Critical**: The Coordinator's `AGENTS.md` tells it **who its team members are** and how to dispatch. Without it, the Coordinator won't know it can delegate tasks. In Phase 1, it lists senior-engineer-1 and senior-engineer-2. After Phase 2/3, the full AGENTS.md lists all 6 specialists.

---

### 6.6 Restart and Test Phase 1

```bash
# Restart Gateway to pick up all config changes
openclaw gateway restart

# Run diagnostics
openclaw doctor --fix

# Verify agents
openclaw agents list
```

All 3 agents should appear. Each should have its own workspace and session store (NOT sharing the coordinator's).

### Test the Flow

1. **Dashboard test**: Open `http://192.168.1.106:18789` in a browser. Select the coordinator agent. Type: *"Ask senior-engineer-1 to explain the SOLID principles."*

2. **Telegram test** (after Chapter 07): Send the same message via Telegram. The coordinator should dispatch to senior-engineer-1, get a response, and reply in Telegram.

3. **Monitor sessions**: While testing, check active sessions:
   ```bash
   openclaw sessions --json
   ```

### What Success Looks Like

```
You (Telegram) → "Explain SOLID principles"
    → Coordinator receives message
    → Coordinator uses sessions_send to senior-engineer-1
    → Senior Engineer #1 generates response using qwen3-coder:30b-a3b (shared with coordinator)
    → Response returns to Coordinator
    → Coordinator replies in Telegram with the answer
```

> **If the Coordinator doesn't dispatch**: Check that `AGENTS.md` exists in the coordinator workspace and that `tools.agentToAgent.enabled` is `true` in `openclaw.json`. Run `openclaw doctor --fix`.

---

## Phase 2: Add PC2 (ATURIG01) — Quality + Security Agents

Once Phase 1 works, add the remote agents whose models run on PC2.

### Prerequisites
- Ollama running on PC2 (ATURIG01) at 192.168.1.112:11434
- Ollama bound to `0.0.0.0` (`OLLAMA_HOST=0.0.0.0`) so PC1 can reach it
- Models `quality-agent:latest` and `security-agent:latest` created on PC2 (see [Chapter 05](05-model-deployment.md))

### 6.7 Verify PC2 Ollama from PC1

From WSL2 on PC1 (ATU-RIG02):

```bash
# Should return model list from PC2
curl -s http://192.168.1.112:11434/api/tags
```

### 6.8 Add PC2 Ollama Provider to Config

Edit `~/.openclaw/openclaw.json` on PC1. Add the `ollama-pc2` provider:

```json
{
  "models": {
    "providers": {
      "ollama": {
        "baseUrl": "http://localhost:11434",
        "apiKey": "ollama",
        "api": "ollama"
      },
      "ollama-pc2": {
        "baseUrl": "http://192.168.1.112:11434",
        "apiKey": "ollama",
        "api": "ollama"
      }
    }
  }
}
```

### 6.9 Add Phase 2 Agents

Add these agents to `agents.list` in `openclaw.json`:

```json
{
  "id": "quality-agent",
  "name": "quality-agent",
  "workspace": "~/.openclaw/workspace-quality",
  "agentDir": "~/.openclaw/agents/quality-agent/agent",
  "cwd": "/home/<username>/project",
  "model": {
    "primary": "ollama-pc2/qwen3:14b"
  }
},
{
  "id": "security-agent",
  "name": "security-agent",
  "workspace": "~/.openclaw/workspace-security",
  "agentDir": "~/.openclaw/agents/security-agent/agent",
  "cwd": "/home/<username>/project",
  "model": {
    "primary": "ollama-pc2/qwen3:14b"
  }
}
```

Add model to the allowlist in `agents.defaults.models`:

```json
"ollama-pc2/qwen3:14b": {}
```

Add the agent IDs to `tools.agentToAgent.allow`:

```json
"allow": [
  "coordinator",
  "senior-engineer-1",
  "senior-engineer-2",
  "quality-agent",
  "security-agent"
]
```

### 6.10 Deploy Phase 2 Workspaces

```bash
# Create directories
mkdir -p ~/.openclaw/workspace-quality
mkdir -p ~/.openclaw/workspace-security
mkdir -p ~/.openclaw/agents/quality-agent/agent
mkdir -p ~/.openclaw/agents/security-agent/agent

# Deploy workspace files
cp workspace-files/quality-agent/*.md ~/.openclaw/workspace-quality/
cp workspace-files/security-agent/*.md ~/.openclaw/workspace-security/

# Update Coordinator's AGENTS.md to include the full roster (all 6 specialists)
cp workspace-files/coordinator/AGENTS.md ~/.openclaw/workspace-coordinator/AGENTS.md
```

> **Note**: The coordinator's `AGENTS.md` in `workspace-files/coordinator/` already contains all 6 specialists. Copying it overwrites the Phase 1 version. This is intentional — the coordinator now knows about all team members.

### Restart and Test Phase 2

```bash
openclaw gateway restart
openclaw doctor --fix
openclaw agents list
```

Test: *"Ask the security-agent to review this code for vulnerabilities: `eval(user_input)`"*

The coordinator should dispatch to security-agent, which runs inference on PC2's Ollama, and the response should come back through the coordinator.

---

## Phase 3: Add Laptop (LTATU01) — DevOps + Monitoring Agents

Same pattern as Phase 2.

### Prerequisites
- Ollama running on Laptop (LTATU01) at 192.168.1.113:11434
- Ollama bound to `0.0.0.0`
- Models `devops-agent:latest` and `monitoring-agent:latest` created on Laptop

### 6.11 Add Laptop Ollama Provider

Add to `models.providers` in `openclaw.json`:

```json
"ollama-laptop": {
  "baseUrl": "http://192.168.1.113:11434",
  "apiKey": "ollama",
  "api": "ollama"
}
```

### 6.12 Add Phase 3 Agents

Add to `agents.list`:

```json
{
  "id": "devops-agent",
  "name": "devops-agent",
  "workspace": "~/.openclaw/workspace-devops",
  "agentDir": "~/.openclaw/agents/devops-agent/agent",
  "cwd": "/home/<username>/project",
  "model": {
    "primary": "ollama-laptop/qwen3:4b"
  }
},
{
  "id": "monitoring-agent",
  "name": "monitoring-agent",
  "workspace": "~/.openclaw/workspace-monitoring",
  "agentDir": "~/.openclaw/agents/monitoring-agent/agent",
  "cwd": "/home/<username>/project",
  "model": {
    "primary": "ollama-laptop/qwen3:4b"
  }
}
```

Add model to allowlist: `"ollama-laptop/qwen3:4b": {}`. Add all agent IDs to `agentToAgent.allow` (all 7 now).

### 6.13 Deploy Phase 3 Workspaces

```bash
# Create directories
mkdir -p ~/.openclaw/workspace-devops
mkdir -p ~/.openclaw/workspace-monitoring
mkdir -p ~/.openclaw/agents/devops-agent/agent
mkdir -p ~/.openclaw/agents/monitoring-agent/agent

# Deploy workspace files
cp workspace-files/devops-agent/*.md ~/.openclaw/workspace-devops/
cp workspace-files/monitoring-agent/*.md ~/.openclaw/workspace-monitoring/
```

### Restart and Test Phase 3

```bash
openclaw gateway restart
openclaw doctor --fix
openclaw agents list
```

All 7 agents should be listed. Test a full-team workflow: *"Design a REST API for user authentication, implement it, review it for quality and security."*

---

## 6.14 Create the Shared Project Directory

All agents share a single `cwd` — the project directory. Create it inside WSL2:

```bash
# Create the shared project directory (replace with your actual project path)
mkdir -p /home/<username>/project

# Initialize git (optional — if this is a new project)
cd /home/<username>/project && git init
```

The `cwd` field in `openclaw.json` points every agent to this directory. When any agent reads or writes a file, it operates inside this shared folder. This means:

- Senior Engineer 1 designs a module → Senior Engineer 2 can immediately implement it
- Senior Engineer 2 writes code → Quality Agent can review it without file transfers
- All agents see the same git history, same files, same project state

---

## 6.15 Complete Configuration Reference

> **See [`docs/current_config/openclaw_pc1_phase1.json`](current_config/openclaw_pc1_phase1.json)** for the Phase 1 config.
> **See [`docs/current_config/openclaw_pc1_complete.json`](current_config/openclaw_pc1_complete.json)** for the complete Phase 3 config with all 7 agents.

---

## 6.16 Known Issues

| Issue | Description | Workaround |
|-------|-------------|------------|
| [#5813](https://github.com/openclaw/openclaw/issues/5813) | `agentToAgent.enabled` may break `sessions_spawn` | Use `sessions_send` instead |
| [#50187](https://github.com/openclaw/openclaw/issues/50187) | `sessions_spawn` + `sessions_yield` crashes on Windows | Not applicable — we're on WSL2/Linux |
| Missing AGENTS.md | Coordinator doesn't know about team members | Create AGENTS.md in coordinator workspace |
| Shared session store | Agents without `agentDir` share coordinator's sessions | Ensure every agent has its own `agentDir` |

---

## 6.17 Deploy Workspace Files

All 56 workspace files (8 files × 7 agents) are provided in this repo under `workspace-files/`. Here's the complete deployment for all phases at once:

```bash
# === One-shot deployment of ALL workspace files ===

# Create all workspace directories
mkdir -p ~/.openclaw/workspace-coordinator
mkdir -p ~/.openclaw/workspace-senior-eng-1
mkdir -p ~/.openclaw/workspace-senior-eng-2
mkdir -p ~/.openclaw/workspace-quality
mkdir -p ~/.openclaw/workspace-security
mkdir -p ~/.openclaw/workspace-devops
mkdir -p ~/.openclaw/workspace-monitoring

# Create all agentDir directories
mkdir -p ~/.openclaw/agents/coordinator/agent
mkdir -p ~/.openclaw/agents/senior-engineer-1/agent
mkdir -p ~/.openclaw/agents/senior-engineer-2/agent
mkdir -p ~/.openclaw/agents/quality-agent/agent
mkdir -p ~/.openclaw/agents/security-agent/agent
mkdir -p ~/.openclaw/agents/devops-agent/agent
mkdir -p ~/.openclaw/agents/monitoring-agent/agent

# Deploy workspace files (from the cloned repo directory)
cp workspace-files/coordinator/*.md ~/.openclaw/workspace-coordinator/
cp workspace-files/senior-engineer-1/*.md ~/.openclaw/workspace-senior-eng-1/
cp workspace-files/senior-engineer-2/*.md ~/.openclaw/workspace-senior-eng-2/
cp workspace-files/quality-agent/*.md ~/.openclaw/workspace-quality/
cp workspace-files/security-agent/*.md ~/.openclaw/workspace-security/
cp workspace-files/devops-agent/*.md ~/.openclaw/workspace-devops/
cp workspace-files/monitoring-agent/*.md ~/.openclaw/workspace-monitoring/

# Create the shared project directory
mkdir -p /home/<username>/project
```

### Workspace File Reference

| File | Purpose | Auto-loaded? |
|------|---------|:------------:|
| `SOUL.md` | Agent personality, behavior rules, responsibilities | Yes |
| `AGENTS.md` | Team roster (coordinator: dispatch list; specialists: team context) | Yes |
| `IDENTITY.md` | Agent name, role, ID, machine assignment, model | Yes |
| `USER.md` | User preferences and communication style | Yes |
| `TOOLS.md` | Available tools and environment description | Yes |
| `HEARTBEAT.md` | Periodic health check tasks | Yes |
| `BOOTSTRAP.md` | First-run setup checklist (delete after first successful run) | Yes |
| `MEMORY.md` | Long-term memory (agent-managed, grows over time) | Yes |

> **Important**: All 8 files must be UPPERCASE with `.md` extension. OpenClaw auto-loads them from the workspace root on every session start. Files in subdirectories are NOT loaded. Files in `agentDir` are silently ignored ([Issue #29387](https://github.com/openclaw/openclaw/issues/29387)).

---

## 6.18 Checklist

### Phase 1 (PC1 / ATU-RIG02 only)
- [ ] 3 agents registered (`openclaw agents list`)
- [ ] Each agent has `id`, `name`, `workspace`, `agentDir`, `cwd`
- [ ] `cwd` points to the shared project directory
- [ ] `tools.agentToAgent.enabled: true`
- [ ] `tools.agentToAgent.allow` lists all 3 agents
- [ ] `session.sendPolicy.default: "allow"`
- [ ] All 8 MD files deployed to each agent's workspace
- [ ] `AGENTS.md` in coordinator workspace lists senior engineers
- [ ] `bindings` routes Telegram to coordinator
- [ ] Dashboard test: coordinator dispatches to senior engineer
- [ ] Telegram test: full round-trip works

### Phase 2 (+ PC2 / ATURIG01)
- [ ] `ollama-pc2` provider added pointing to 192.168.1.112:11434
- [ ] PC2 Ollama reachable from WSL2 (`curl http://192.168.1.112:11434/api/tags`)
- [ ] quality-agent and security-agent added to agent list
- [ ] Models added to allowlist
- [ ] Agent IDs added to `agentToAgent.allow`
- [ ] All 8 MD files deployed to both agent workspaces
- [ ] Coordinator's AGENTS.md updated (full roster)
- [ ] Test: coordinator dispatches to security-agent, response comes back

### Phase 3 (+ Laptop / LTATU01)
- [ ] `ollama-laptop` provider added pointing to 192.168.1.113:11434
- [ ] devops-agent and monitoring-agent added
- [ ] All 7 agents visible in `openclaw agents list`
- [ ] Full team workflow test succeeds

---

Next: [Chapter 07 - Telegram Bot Setup](07-telegram-bot-setup.md)
