# Distributed AI Development Team - Setup Guide

## What This Guide Covers

This guide walks you through setting up a **distributed AI development team** across multiple Windows 11 machines. The system uses **OpenClaw** to orchestrate communication between AI models running on **Ollama**, with a **Telegram bot** providing human oversight and interaction.

By the end of this guide, you will have:

- Multiple AI models running across 3 machines, each with a specialized role
- A single OpenClaw Gateway on PC1 orchestrating all agents
- PC2 and Laptop connected as Nodes to PC1's Gateway
- A Telegram bot for real-time human interaction and oversight
- GitHub integration for automated code management
- Monitoring dashboards to track system health and resource usage
- Security restrictions and escalation protocols

## System Overview Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        HUMAN OPERATOR                               │
│                     (Telegram App / Web)                             │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ Telegram Bot API
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PC1 (192.168.1.106) - RTX 4090 24GB / 64GB RAM / 32 cores        │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  OpenClaw GATEWAY (:18789) — Single control plane             │  │
│  │                                                               │  │
│  │  Agents (all registered here):                                │  │
│  │  ├── Coordinator (Telegram-bound, task dispatch)              │  │
│  │  ├── Senior Engineer #1 (Architecture)                        │  │
│  │  ├── Senior Engineer #2 (Implementation)                      │  │
│  │  ├── Quality Agent       → model on PC2 Ollama               │  │
│  │  ├── Security Agent      → model on PC2 Ollama               │  │
│  │  ├── DevOps Agent        → model on Laptop Ollama            │  │
│  │  ├── Monitoring Agent    → model on Laptop Ollama            │  │
│  │  └── External Consultant → Claude.ai API                     │  │
│  │                                                               │  │
│  │  Model Providers:                                             │  │
│  │  ├── ollama-local  (127.0.0.1:11434)     PC1 models          │  │
│  │  ├── ollama-pc2    (192.168.1.112:11434) PC2 models          │  │
│  │  ├── ollama-laptop (192.168.1.113:11434) Laptop models       │  │
│  │  └── anthropic     (api.anthropic.com)   Claude.ai           │  │
│  │                                                               │  │
│  │  Channels: Telegram Bot                                       │  │
│  └──────────┬────────────────────────────────┬───────────────────┘  │
│             │ WebSocket                      │ WebSocket            │
│  ┌──────────▼──────────┐    ┌────────────────▼───────────────┐     │
│  │  Local Ollama       │    │  Node connections               │     │
│  │  :11434             │    │  (PC2 + Laptop connect here)    │     │
│  │  - coordinator      │    └────────────────────────────────-┘     │
│  │  - senior-eng-1     │                                            │
│  │  - senior-eng-2     │                                            │
│  └─────────────────────┘                                            │
└──────────┬──────────────────────────────┬───────────────────────────┘
           │ Node (WebSocket)             │ Node (WebSocket)
           ▼                              ▼
┌────────────────────────────┐  ┌──────────────────────────────────┐
│  PC2 (192.168.1.112)       │  │  Laptop (192.168.1.113)          │
│  RTX 2080 Ti 11GB          │  │  Quadro T2000 4GB                │
│  64GB RAM / 24 cores       │  │  64GB RAM / 12 cores             │
│                            │  │                                  │
│  ┌──────────────────────┐  │  │  ┌────────────────────────────┐  │
│  │  OpenClaw NODE       │  │  │  │  OpenClaw NODE             │  │
│  │  (connects to PC1    │  │  │  │  (connects to PC1          │  │
│  │   Gateway via WS)    │  │  │  │   Gateway via WS)          │  │
│  └──────────────────────┘  │  │  └────────────────────────────┘  │
│                            │  │                                  │
│  ┌──────────────────────┐  │  │  ┌────────────────────────────┐  │
│  │  Ollama :11434       │  │  │  │  Ollama :11434             │  │
│  │  - quality-agent     │  │  │  │  - devops-agent            │  │
│  │  - security-agent    │  │  │  │  - monitoring-agent        │  │
│  │  - codellama:7b      │  │  │  └────────────────────────────┘  │
│  └──────────────────────┘  │  └──────────────────────────────────┘
└────────────────────────────┘
                                     ┌─────────────────────────┐
                                     │  External: Claude.ai    │
                                     │  (via Anthropic API)    │
                                     │  Role: Consultant       │
                                     └─────────────────────────┘
```

## Key Design Principles

1. **No Monolithic Controller** — There is no single Python script routing everything. Each AI model is an independent agent orchestrated by OpenClaw.
2. **Hub-and-Spoke Architecture** — PC1 runs the single OpenClaw Gateway (hub). PC2 and Laptop connect as Nodes (spokes) via WebSocket. All agents are registered on the Gateway.
3. **OpenClaw is the Infrastructure** — All agent orchestration, channel routing, file management, GitHub operations, and Telegram integration go through OpenClaw natively.
4. **Remote Ollama as Providers** — The Gateway on PC1 connects to Ollama instances on PC2 and Laptop via their HTTP API (port 11434). Models run on the hardware where they're deployed; the Gateway routes inference requests to the right provider.
5. **Human Oversight** — The Telegram bot ensures a human is always in the loop for critical decisions.
6. **Fault Tolerant** — If a node or remote Ollama goes down, the Gateway detects the failure and the coordinator reassigns work.

## Guide Structure

| Chapter | Title | Description |
|---------|-------|-------------|
| [01](01-prerequisites.md) | Prerequisites | Software and accounts you need before starting |
| [02](02-hardware-architecture.md) | Hardware & Architecture | Detailed hardware specs and network layout |
| [03](03-openclaw-installation.md) | OpenClaw Installation | Step-by-step OpenClaw setup on all machines |
| [04](04-ollama-setup.md) | Ollama Setup | Installing and configuring Ollama on each machine |
| [05](05-model-deployment.md) | Model Deployment | Which models to use and how to deploy them |
| [06](06-team-configuration.md) | Team Configuration | Configuring each AI agent's role and capabilities |
| [07](07-telegram-bot-setup.md) | Telegram Bot Setup | Creating and integrating the Telegram bot |
| [08](08-inter-machine-communication.md) | Inter-Machine Communication | Setting up OpenClaw networking across machines |
| [09](09-github-integration.md) | GitHub Integration | SSH keys, PATs, and repository automation |
| [10](10-task-coordination.md) | Task Coordination | Workflow from request to delivery |
| [11](11-monitoring-setup.md) | Monitoring Setup | Resource tracking and dashboards |
| [12](12-security-hardening.md) | Security Hardening | Locking down the system properly |
| [13](13-conflict-resolution.md) | Conflict Resolution | How models resolve disagreements |
| [14](14-error-handling-recovery.md) | Error Handling & Recovery | Retry mechanisms and graceful degradation |
| [15](15-performance-tuning.md) | Performance Tuning | Optimization tips for best results |
| [16](16-testing-validation.md) | Testing & Validation | Checklists to verify everything works |
| [17](17-troubleshooting.md) | Troubleshooting | Common issues and how to fix them |
| [18](18-security-restrictions.md) | Security Restrictions | Prohibited actions and escalation protocols |

## Estimated Setup Time

- **First-time setup**: 4-6 hours (reading carefully and verifying each step)
- **Experienced re-deployment**: 1-2 hours
- **Adding a new machine later**: 30-60 minutes

## Before You Begin

Read through [Chapter 01 - Prerequisites](01-prerequisites.md) to make sure you have everything you need.
