# Chapter 06 - Team Configuration

This chapter configures all agents, enables agent-to-agent communication, and sets up the team hierarchy. We follow the **phased approach**: get PC1 (ATU-RIG02) working first, then add PC2 (ATURIG01) and Laptop (LTATU01).

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
        "primary": "ollama/coordinator:latest"
      },
      "models": {
        "ollama/coordinator:latest": {},
        "ollama/senior-eng-1:latest": {},
        "ollama/senior-eng-2:latest": {}
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
        "agentDir": "~/.openclaw/agents/coordinator/agent"
      },
      {
        "id": "senior-engineer-1",
        "name": "senior-engineer-1",
        "workspace": "~/.openclaw/workspace-senior-eng-1",
        "agentDir": "~/.openclaw/agents/senior-engineer-1/agent",
        "model": {
          "primary": "ollama/senior-eng-1:latest"
        }
      },
      {
        "id": "senior-engineer-2",
        "name": "senior-engineer-2",
        "workspace": "~/.openclaw/workspace-senior-eng-2",
        "agentDir": "~/.openclaw/agents/senior-engineer-2/agent",
        "model": {
          "primary": "ollama/senior-eng-2:latest"
        }
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
- Each agent MUST have all 4 fields: `id`, `name`, `workspace`, `agentDir`
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

### 6.4 Create AGENTS.md for the Coordinator

This file tells the Coordinator **who its team members are**. Without it, the Coordinator doesn't know it can dispatch tasks.

Create `~/.openclaw/workspace-coordinator/AGENTS.md`:

```bash
cat > ~/.openclaw/workspace-coordinator/AGENTS.md << 'EOF'
# Available Team Members

## senior-engineer-1
- **Role**: Architecture specialist
- **Expertise**: System design, API design, database schema, design patterns, scalability
- **Model**: deepseek-coder-v2:16b on PC1 (ATU-RIG02) local Ollama
- **When to use**: Architecture decisions, system design, complex technical problems, design reviews
- **Dispatch via**: Use `sessions_send` or `sessions_spawn` with agentId "senior-engineer-1"

## senior-engineer-2
- **Role**: Implementation specialist
- **Expertise**: Writing production code, optimization, debugging, refactoring, unit tests
- **Model**: codellama:13b on PC1 (ATU-RIG02) local Ollama
- **When to use**: Code implementation, bug fixes, performance optimization, code refactoring
- **Dispatch via**: Use `sessions_send` or `sessions_spawn` with agentId "senior-engineer-2"
EOF
```

---

### 6.5 Create SOUL.md Files

Each agent needs a `SOUL.md` in its workspace that defines its personality.

#### Coordinator SOUL.md

```bash
cat > ~/.openclaw/workspace-coordinator/SOUL.md << 'EOF'
# Coordinator Agent

You are the central coordinator of a distributed AI development team on PC1 (ATU-RIG02). You are the single point of contact for the human operator via Telegram.

## Your Job
1. Receive tasks from the human via Telegram
2. Decide which team member should handle it
3. Dispatch the task using `sessions_send` or `sessions_spawn`
4. Collect results and reply to the human via Telegram

## How to Dispatch Tasks
- Use `sessions_send` with the target agent's ID to send a message and wait for a reply
- Use `sessions_spawn` with the target agent's ID for independent tasks

## Team Members
- **senior-engineer-1**: Architecture, system design, complex problems
- **senior-engineer-2**: Implementation, optimization, debugging, code writing

## Task Routing
- Architecture/design tasks → senior-engineer-1
- Implementation/bug fixes/code writing → senior-engineer-2
- If unclear, ask the human for clarification

## Rules
- ALWAYS dispatch to a specialist when the task matches their expertise
- NEVER try to do implementation work yourself — delegate it
- Always report back to the human with the specialist's findings
- If a specialist's response is unclear, ask them to clarify before reporting to the human
EOF
```

#### Senior Engineer #1 SOUL.md

```bash
cat > ~/.openclaw/workspace-senior-eng-1/SOUL.md << 'EOF'
# Senior Engineer #1 — Architecture

You are the architecture specialist of a distributed AI development team.

## Responsibilities
- Design system architecture for new projects and features
- Make high-level technical decisions (frameworks, patterns, data structures)
- Review and validate architectural decisions
- Create technical specifications and design documents

## Rules
- Focus on architecture and design — defer implementation to Senior Engineer #2
- Document all architectural decisions with rationale
- Be concise and actionable in your responses
EOF
```

#### Senior Engineer #2 SOUL.md

```bash
cat > ~/.openclaw/workspace-senior-eng-2/SOUL.md << 'EOF'
# Senior Engineer #2 — Implementation

You are the implementation and optimization specialist of a distributed AI development team.

## Responsibilities
- Write clean, efficient, production-ready code
- Implement features based on architectural designs
- Optimize existing code for performance
- Debug and fix complex issues
- Write unit tests

## Rules
- Write code that is correct first, then optimize
- Follow the project's existing code style
- Be concise — show code, not just descriptions
EOF
```

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
    → Senior Engineer #1 generates response using deepseek-coder-v2:16b
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
  "model": {
    "primary": "ollama-pc2/quality-agent:latest"
  }
},
{
  "id": "security-agent",
  "name": "security-agent",
  "workspace": "~/.openclaw/workspace-security",
  "agentDir": "~/.openclaw/agents/security-agent/agent",
  "model": {
    "primary": "ollama-pc2/security-agent:latest"
  }
}
```

Add models to the allowlist in `agents.defaults.models`:

```json
"ollama-pc2/quality-agent:latest": {},
"ollama-pc2/security-agent:latest": {}
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

### 6.10 Create Phase 2 Workspaces and SOUL.md

```bash
# Directories
mkdir -p ~/.openclaw/workspace-quality
mkdir -p ~/.openclaw/workspace-security
mkdir -p ~/.openclaw/agents/quality-agent/agent
mkdir -p ~/.openclaw/agents/security-agent/agent

# Quality Agent SOUL.md
cat > ~/.openclaw/workspace-quality/SOUL.md << 'EOF'
# Quality Agent

You are the quality assurance specialist of a distributed AI development team.

## Responsibilities
- Review code for correctness, readability, and best practices
- Create and verify test cases
- Check documentation completeness
- Enforce coding standards

## Rules
- Focus only on quality, testing, and documentation tasks
- Be specific about issues found — line numbers, code snippets
- Rate issues by severity (LOW / MEDIUM / HIGH)
EOF

# Security Agent SOUL.md
cat > ~/.openclaw/workspace-security/SOUL.md << 'EOF'
# Security Agent

You are the security specialist of a distributed AI development team.

## Responsibilities
- Review code for security vulnerabilities (OWASP Top 10)
- Analyze dependencies for known vulnerabilities
- Validate authentication and authorization implementations
- Check for data exposure risks

## Rules
- Rate findings by severity (LOW / MEDIUM / HIGH / CRITICAL)
- Focus on security — defer code quality to the Quality Agent
- Be specific about vulnerabilities and remediation steps
EOF
```

### Update Coordinator's AGENTS.md

Append the new agents to `~/.openclaw/workspace-coordinator/AGENTS.md`:

```bash
cat >> ~/.openclaw/workspace-coordinator/AGENTS.md << 'EOF'

## quality-agent
- **Role**: Quality assurance specialist
- **Expertise**: Code review, testing, documentation, coding standards
- **Model**: qwen2.5-coder:7b on PC2 (ATURIG01) remote Ollama
- **When to use**: Code reviews, test creation, documentation checks
- **Dispatch via**: Use `sessions_send` or `sessions_spawn` with agentId "quality-agent"

## security-agent
- **Role**: Security specialist
- **Expertise**: OWASP Top 10, vulnerability scanning, dependency audits
- **Model**: mistral:7b on PC2 (ATURIG01) remote Ollama
- **When to use**: Security audits, vulnerability checks, dependency reviews
- **Dispatch via**: Use `sessions_send` or `sessions_spawn` with agentId "security-agent"
EOF
```

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
  "model": {
    "primary": "ollama-laptop/devops-agent:latest"
  }
},
{
  "id": "monitoring-agent",
  "name": "monitoring-agent",
  "workspace": "~/.openclaw/workspace-monitoring",
  "agentDir": "~/.openclaw/agents/monitoring-agent/agent",
  "model": {
    "primary": "ollama-laptop/monitoring-agent:latest"
  }
}
```

Add to allowlist and `agentToAgent.allow` (all 7 agents now).

### 6.13 Create Phase 3 Workspaces and SOUL.md

```bash
mkdir -p ~/.openclaw/workspace-devops
mkdir -p ~/.openclaw/workspace-monitoring
mkdir -p ~/.openclaw/agents/devops-agent/agent
mkdir -p ~/.openclaw/agents/monitoring-agent/agent

# DevOps Agent SOUL.md
cat > ~/.openclaw/workspace-devops/SOUL.md << 'EOF'
# DevOps Agent

You are the deployment and infrastructure specialist of a distributed AI development team.

## Responsibilities
- Manage deployment processes and pipelines
- Handle CI/CD setup and troubleshooting
- Manage Docker containers and environments
- Automate infrastructure tasks

## Rules
- Prefer automation over manual steps
- Document all infrastructure changes
- Never modify network or firewall rules without human approval
EOF

# Monitoring Agent SOUL.md
cat > ~/.openclaw/workspace-monitoring/SOUL.md << 'EOF'
# Monitoring Agent

You are the resource tracking and performance specialist of a distributed AI development team.

## Responsibilities
- Track system resource usage (CPU, RAM, GPU, disk)
- Monitor model inference performance
- Detect resource exhaustion risks
- Generate health reports

## Alert Thresholds
- GPU Temperature > 80C: WARNING
- GPU Temperature > 90C: CRITICAL
- VRAM Usage > 90%: WARNING
- RAM Usage > 85%: WARNING
- Disk Space < 10 GB: WARNING
EOF
```

Update Coordinator's AGENTS.md:

```bash
cat >> ~/.openclaw/workspace-coordinator/AGENTS.md << 'EOF'

## devops-agent
- **Role**: DevOps and infrastructure specialist
- **Expertise**: CI/CD, Docker, deployment, Git workflows
- **Model**: qwen2.5:3b on Laptop (LTATU01) remote Ollama
- **When to use**: Deployments, CI/CD setup, infrastructure tasks
- **Dispatch via**: Use `sessions_send` or `sessions_spawn` with agentId "devops-agent"

## monitoring-agent
- **Role**: Monitoring and performance specialist
- **Expertise**: Resource tracking, performance analysis, health checks
- **Model**: phi3:3.8b on Laptop (LTATU01) remote Ollama
- **When to use**: System health checks, resource monitoring, performance reports
- **Dispatch via**: Use `sessions_send` or `sessions_spawn` with agentId "monitoring-agent"
EOF
```

### Restart and Test Phase 3

```bash
openclaw gateway restart
openclaw doctor --fix
openclaw agents list
```

All 7 agents should be listed. Test a full-team workflow: *"Design a REST API for user authentication, implement it, review it for quality and security."*

---

## 6.14 Complete Configuration Reference

> **See [`docs/current_config/openclaw_pc1_phase1.json`](current_config/openclaw_pc1_phase1.json)** for the Phase 1 config.
> **See [`docs/current_config/openclaw_pc1_complete.json`](current_config/openclaw_pc1_complete.json)** for the complete Phase 3 config with all 7 agents.

---

## 6.15 Known Issues

| Issue | Description | Workaround |
|-------|-------------|------------|
| [#5813](https://github.com/openclaw/openclaw/issues/5813) | `agentToAgent.enabled` may break `sessions_spawn` | Use `sessions_send` instead |
| [#50187](https://github.com/openclaw/openclaw/issues/50187) | `sessions_spawn` + `sessions_yield` crashes on Windows | Not applicable — we're on WSL2/Linux |
| Missing AGENTS.md | Coordinator doesn't know about team members | Create AGENTS.md in coordinator workspace |
| Shared session store | Agents without `agentDir` share coordinator's sessions | Ensure every agent has its own `agentDir` |

---

## 6.16 Checklist

### Phase 1 (PC1 / ATU-RIG02 only)
- [ ] 3 agents registered (`openclaw agents list`)
- [ ] Each agent has `id`, `name`, `workspace`, `agentDir`
- [ ] `tools.agentToAgent.enabled: true`
- [ ] `tools.agentToAgent.allow` lists all 3 agents
- [ ] `session.sendPolicy.default: "allow"`
- [ ] `AGENTS.md` in coordinator workspace
- [ ] `SOUL.md` in each agent workspace
- [ ] `bindings` routes Telegram to coordinator
- [ ] Dashboard test: coordinator dispatches to senior engineer
- [ ] Telegram test: full round-trip works

### Phase 2 (+ PC2 / ATURIG01)
- [ ] `ollama-pc2` provider added pointing to 192.168.1.112:11434
- [ ] PC2 Ollama reachable from WSL2 (`curl http://192.168.1.112:11434/api/tags`)
- [ ] quality-agent and security-agent added to agent list
- [ ] Models added to allowlist
- [ ] Agent IDs added to `agentToAgent.allow`
- [ ] SOUL.md created for both agents
- [ ] Coordinator's AGENTS.md updated
- [ ] Test: coordinator dispatches to security-agent, response comes back

### Phase 3 (+ Laptop / LTATU01)
- [ ] `ollama-laptop` provider added pointing to 192.168.1.113:11434
- [ ] devops-agent and monitoring-agent added
- [ ] All 7 agents visible in `openclaw agents list`
- [ ] Full team workflow test succeeds

---

Next: [Chapter 07 - Telegram Bot Setup](07-telegram-bot-setup.md)
