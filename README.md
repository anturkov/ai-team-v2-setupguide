# AI Team v2 - Setup Guide

A comprehensive guide for setting up a **distributed AI development team** across multiple Windows 11 machines using **OpenClaw** for orchestration, **Ollama** for local model inference, and a **Telegram bot** for human oversight.

## Quick Start

1. Read the [Overview](docs/00-overview.md) to understand the system architecture
2. Complete the [Prerequisites](docs/01-prerequisites.md) checklist
3. Follow each chapter in order (01 through 18)

## Guide Chapters

| # | Chapter | Description |
|---|---------|-------------|
| 00 | [Overview](docs/00-overview.md) | System architecture, design principles, guide structure |
| 01 | [Prerequisites](docs/01-prerequisites.md) | Software, accounts, network, and hardware requirements |
| 02 | [Hardware & Architecture](docs/02-hardware-architecture.md) | Machine specs, network topology, VRAM planning |
| 03 | [OpenClaw Installation](docs/03-openclaw-installation.md) | Installing and configuring OpenClaw on all machines |
| 04 | [Ollama Setup](docs/04-ollama-setup.md) | Installing Ollama, downloading models, environment config |
| 05 | [Model Deployment](docs/05-model-deployment.md) | Model recommendations, Modelfiles, OpenClaw registration |
| 06 | [Team Configuration](docs/06-team-configuration.md) | Roles, communication rules, permissions, warm-up |
| 07 | [Telegram Bot Setup](docs/07-telegram-bot-setup.md) | Creating the bot, Chat ID, OpenClaw integration |
| 08 | [Inter-Machine Communication](docs/08-inter-machine-communication.md) | Cross-machine messaging, firewall, network config |
| 09 | [GitHub Integration](docs/09-github-integration.md) | SSH keys, PATs, repository automation |
| 10 | [Task Coordination](docs/10-task-coordination.md) | Task lifecycle, decomposition, quality gates |
| 11 | [Monitoring Setup](docs/11-monitoring-setup.md) | Resource monitoring, dashboards, alerts |
| 12 | [Security Hardening](docs/12-security-hardening.md) | Credentials, network security, audit logging |
| 13 | [Conflict Resolution](docs/13-conflict-resolution.md) | Disagreement handling, escalation, audit trails |
| 14 | [Error Handling & Recovery](docs/14-error-handling-recovery.md) | Retries, failover, backup coordinator |
| 15 | [Performance Tuning](docs/15-performance-tuning.md) | GPU optimization, caching, benchmarking |
| 16 | [Testing & Validation](docs/16-testing-validation.md) | Test procedures and validation checklists |
| 17 | [Troubleshooting](docs/17-troubleshooting.md) | Common issues and solutions |
| 18 | [Security Restrictions](docs/18-security-restrictions.md) | Prohibited actions and escalation protocols |

## Configuration Files

Located in [`docs/configs/`](docs/configs/):

| File | Description |
|------|-------------|
| [openclaw-pc1.yaml](docs/configs/openclaw-pc1.yaml) | OpenClaw config for PC1 (Coordinator) |
| [openclaw-pc2.yaml](docs/configs/openclaw-pc2.yaml) | OpenClaw config for PC2 (Worker) |
| [openclaw-laptop.yaml](docs/configs/openclaw-laptop.yaml) | OpenClaw config for Laptop (Monitor) |
| [team.yaml](docs/configs/team.yaml) | Full team structure and routing rules |
| [telegram-bot-config.yaml](docs/configs/telegram-bot-config.yaml) | Telegram bot integration settings |

## PowerShell Scripts

Located in [`docs/scripts/`](docs/scripts/):

| Script | Description |
|--------|-------------|
| [setup-directories.ps1](docs/scripts/setup-directories.ps1) | Create directory structure on each machine |
| [setup-ollama-env.ps1](docs/scripts/setup-ollama-env.ps1) | Configure Ollama environment variables |
| [deploy-models.ps1](docs/scripts/deploy-models.ps1) | Download and deploy models per machine |
| [warmup.ps1](docs/scripts/warmup.ps1) | Pre-load priority models after boot |
| [health-check.ps1](docs/scripts/health-check.ps1) | Quick system health verification |
| [monitor-resources.ps1](docs/scripts/monitor-resources.ps1) | Continuous resource monitoring |
| [benchmark.ps1](docs/scripts/benchmark.ps1) | Model performance benchmarking |
| [restart-all.ps1](docs/scripts/restart-all.ps1) | Restart all services |
| [rotate-logs.ps1](docs/scripts/rotate-logs.ps1) | Log compression and cleanup |

## Hardware

| Machine | GPU | VRAM | RAM | Role |
|---------|-----|------|-----|------|
| PC1 (192.168.1.106) | RTX 4090 | 24 GB | 64 GB | Coordinator + Senior Engineers |
| PC2 (192.168.1.112) | RTX 2080 Ti | 11 GB | 64 GB | Quality + Security + Backup |
| Laptop (192.168.1.113) | Quadro T2000 | 4 GB | 64 GB | Monitoring + DevOps |
