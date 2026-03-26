# Distributed AI Development Team - Setup Guide (v2)

## What This Guide Covers

This guide walks you through setting up a **distributed AI development team** across 3 Windows 11 machines. OpenClaw runs inside **WSL2 (Ubuntu)** on each machine for full Linux compatibility. **Ollama** runs on Windows native for GPU access. A **Telegram bot** provides human interaction.

**Design philosophy**: Simple. No fallbacks, no model switching, no security layers. One model per agent. If a machine goes down, the environment is down.

### What You'll Have When Done

- 7 specialized AI agents across 3 machines
- OpenClaw Gateway running in WSL2 on PC1 (ATU-RIG02)
- Ollama running on Windows native on all 3 machines
- Coordinator receives Telegram messages and dispatches to specialists
- Specialists respond back to Coordinator, who replies via Telegram

### Incremental Setup Approach

This guide follows a **phased approach**:

| Phase | Machines | What Works After This Phase |
|-------|----------|---------------------------|
| **Phase 1** | PC1 (ATU-RIG02) only | Telegram → Coordinator → Senior Engineers → Coordinator → Telegram |
| **Phase 2** | + PC2 (ATURIG01) | + Security Agent and Quality Agent on PC2's Ollama |
| **Phase 3** | + Laptop (LTATU01) | + DevOps Agent and Monitoring Agent on Laptop's Ollama |

**You verify each phase works before moving to the next.**

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        HUMAN OPERATOR                               │
│                     (Telegram App / Web)                             │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ Telegram Bot API
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PC1 / ATU-RIG02 (192.168.1.106)                                    │
│  RTX 4090 24GB / 64GB RAM / 32 cores                                │
│                                                                      │
│  ┌─ WSL2 (Ubuntu) ──────────────────────────────────────────────┐   │
│  │  OpenClaw GATEWAY (:18789)                                    │   │
│  │                                                               │   │
│  │  Agents:                                                      │   │
│  │  ├── Coordinator        → ollama/coordinator:latest           │   │
│  │  ├── Senior Engineer #1 → ollama/senior-eng-1:latest          │   │
│  │  ├── Senior Engineer #2 → ollama/senior-eng-2:latest          │   │
│  │  ├── Quality Agent      → ollama-pc2/quality-agent:latest     │   │
│  │  ├── Security Agent     → ollama-pc2/security-agent:latest    │   │
│  │  ├── DevOps Agent       → ollama-laptop/devops-agent:latest   │   │
│  │  └── Monitoring Agent   → ollama-laptop/monitoring-agent:latest│   │
│  │                                                               │   │
│  │  Channels: Telegram Bot                                       │   │
│  │  Agent-to-Agent: sessions_send / sessions_spawn               │   │
│  └──────────────────────────┬────────────────────────────────────┘   │
│                              │ HTTP (localhost:11434)                 │
│  ┌───────────────────────────▼──────────────────────────────────┐   │
│  │  Ollama (Windows native) :11434                               │   │
│  │  - coordinator:latest (qwen2.5-coder:32b)                     │   │
│  │  - senior-eng-1:latest (deepseek-coder-v2:16b)                │   │
│  │  - senior-eng-2:latest (codellama:13b)                        │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────┬──────────────────────────────┬───────────────────────────┘
           │ HTTP (:11434)                │ HTTP (:11434)
           ▼                              ▼
┌────────────────────────────┐  ┌──────────────────────────────────┐
│  PC2 / ATURIG01            │  │  Laptop / LTATU01                │
│  (192.168.1.112)           │  │  (192.168.1.113)                 │
│  RTX 2080 Ti 11GB          │  │  Quadro T2000 4GB                │
│                            │  │                                  │
│  Ollama (Windows native)   │  │  Ollama (Windows native)         │
│  :11434                    │  │  :11434                          │
│  - quality-agent:latest    │  │  - devops-agent:latest           │
│  - security-agent:latest   │  │  - monitoring-agent:latest       │
└────────────────────────────┘  └──────────────────────────────────┘
```

### Key Points

- **OpenClaw runs in WSL2** on PC1 (ATU-RIG02) only. PC2 and Laptop just run Ollama.
- **Ollama runs on Windows native** on all machines (simpler GPU access).
- **No Nodes needed.** PC2 and Laptop are just Ollama HTTP servers.
- **No fallbacks.** Each agent has exactly one model on one machine.
- **All agent logic lives on PC1.** Only inference requests go to remote machines.

---

## Machine Roles

| Machine | Hostname | IP | Role | Runs OpenClaw? | Runs Ollama? |
|---------|----------|-----|------|---------------|-------------|
| PC1 | ATU-RIG02 | 192.168.1.106 | Gateway + 3 agents + Telegram | Yes (WSL2) | Yes (Windows) |
| PC2 | ATURIG01 | 192.168.1.112 | Remote Ollama server | No | Yes (Windows) |
| Laptop | LTATU01 | 192.168.1.113 | Remote Ollama server | No | Yes (Windows) |

## Agent Roster

| Agent | Machine | Model | Base Model | Purpose |
|-------|---------|-------|------------|---------|
| coordinator | PC1 (ATU-RIG02) | coordinator:latest | qwen2.5-coder:32b | Central command, Telegram interface, task dispatch |
| senior-engineer-1 | PC1 (ATU-RIG02) | senior-eng-1:latest | deepseek-coder-v2:16b | Architecture, system design |
| senior-engineer-2 | PC1 (ATU-RIG02) | senior-eng-2:latest | codellama:13b | Implementation, optimization |
| quality-agent | PC2 (ATURIG01) | quality-agent:latest | qwen2.5-coder:7b | Code review, testing |
| security-agent | PC2 (ATURIG01) | security-agent:latest | mistral:7b | Security analysis |
| devops-agent | Laptop (LTATU01) | devops-agent:latest | qwen2.5:3b | Deployment, CI/CD |
| monitoring-agent | Laptop (LTATU01) | monitoring-agent:latest | phi3:3.8b | Resource tracking |

---

## Guide Structure

| Chapter | Title | Description |
|---------|-------|-------------|
| [01](01-prerequisites.md) | Prerequisites | Software and accounts needed |
| [02](02-hardware-architecture.md) | Hardware & Architecture | Machine specs and network layout |
| [03](03-openclaw-installation.md) | OpenClaw Installation (WSL2) | WSL2 setup + OpenClaw install on PC1 |
| [04](04-ollama-setup.md) | Ollama Setup | Installing Ollama on all machines |
| [05](05-model-deployment.md) | Model Deployment | Creating and deploying agent models |
| [06](06-team-configuration.md) | Team Configuration | Agent config, agent-to-agent, SOUL.md |
| [07](07-telegram-bot-setup.md) | Telegram Bot Setup | Bot creation and channel binding |
| [08](08-inter-machine-communication.md) | Inter-Machine Communication | Remote Ollama provider config |
| [09](09-github-integration.md) | GitHub Integration | SSH keys and repository automation |
| [10](10-task-coordination.md) | Task Coordination | Workflow from request to delivery |

---

## Before You Begin

Read [Chapter 01 - Prerequisites](01-prerequisites.md) first. The minimum you need:
- Windows 11 22H2+ on all machines (for WSL2 mirrored networking)
- Ollama installed on all machines
- A Telegram account and bot token from @BotFather
- All machines on the same LAN
